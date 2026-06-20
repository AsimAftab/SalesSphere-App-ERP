import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/parties/data/dto/party_image_ref.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/presentation/controllers/parties_controller.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';
import 'package:sales_sphere_erp/features/parties/presentation/widgets/party_type_picker.dart';
import 'package:sales_sphere_erp/shared/utils/image_validation.dart';
import 'package:sales_sphere_erp/shared/utils/maps_launcher.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/location_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

class EditPartyDetailPage extends ConsumerStatefulWidget {
  const EditPartyDetailPage({required this.id, this.initial, super.key});

  final String id;

  /// Optional starting party passed via `extra` when navigating from the
  /// list — saves a re-fetch on first paint.
  final Party? initial;

  @override
  ConsumerState<EditPartyDetailPage> createState() =>
      _EditPartyDetailPageState();
}

class _EditPartyDetailPageState extends ConsumerState<EditPartyDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _panVatController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();
  final _dateController = TextEditingController();

  static const _maxImages = 2;

  // Default camera target — Kathmandu. Used until the saved record's
  // coords (or a fresh user pick) replace it.
  static const _defaultLat = 27.7172;
  static const _defaultLng = 85.3240;

  String? _partyType;
  DateTime? _dateJoined;
  double _latitude = _defaultLat;
  double _longitude = _defaultLng;
  final List<String> _imagePaths = <String>[];

  /// Server-side images at the moment we render. Mutated as the user
  /// removes thumbnails; `_originalExistingImages` is the snapshot
  /// used by cancel to restore.
  List<PartyImageRef> _existingImages = const <PartyImageRef>[];
  List<PartyImageRef> _originalExistingImages = const <PartyImageRef>[];

  /// Slot numbers (1-indexed) the user asked to delete in this edit
  /// session. Drained in `_save` before uploading new locals so the
  /// freed slots become available targets.
  final Set<int> _slotsToDelete = <int>{};

  bool _editing = false;
  bool _saving = false;
  bool _loading = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _populate(widget.initial!);
      // Fields are populated synchronously, but the gallery still needs
      // a fetch — kick it off after first frame so the picker fills in.
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateImages());
    } else {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }
  }

  /// Loads the party by awaiting the byId provider's future, which
  /// derives from the list AsyncValue. Falls through to the
  /// not-found branch if the list errors.
  Future<void> _hydrate() async {
    Party? party;
    try {
      party = await ref.read(partyByIdProvider(widget.id).future);
    } on Object catch (_) {
      // List failed to load; surface as the not-found state below.
    }
    if (!mounted) return;
    if (party != null) {
      _populate(party);
      setState(() => _loading = false);
      await _hydrateImages();
    } else {
      setState(() {
        _loading = false;
        _notFound = true;
      });
    }
  }

  /// Fetch the gallery so the picker shows server-side images. Failures
  /// are swallowed — an empty picker is graceful degradation.
  Future<void> _hydrateImages() async {
    try {
      final images =
          await ref.read(partiesRepositoryProvider).listImages(widget.id);
      if (!mounted) return;
      setState(() {
        _existingImages = images;
        _originalExistingImages = List<PartyImageRef>.unmodifiable(images);
      });
    } on Object catch (_) {
      // Not fatal — picker stays empty on the network image side and the
      // user can still pick new locals.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _panVatController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _populate(Party p) {
    _nameController.text = p.name;
    _ownerController.text = p.ownerName;
    _panVatController.text = p.panVat;
    _phoneController.text = p.phone;
    _emailController.text = p.email ?? '';
    _notesController.text = p.notes ?? '';
    _addressController.text = p.address;
    _partyType = p.partyType;
    _dateJoined = p.dateJoined;
    _dateController.text = p.dateJoined != null
        ? DateFormat('dd MMM yyyy').format(p.dateJoined!)
        : '';
    _latitude = p.latitude ?? _defaultLat;
    _longitude = p.longitude ?? _defaultLng;
    _imagePaths
      ..clear()
      ..addAll(p.imagePaths);
  }

  void _toggleEdit() {
    setState(() => _editing = !_editing);
  }

  void _cancelEdit() {
    // Reset every field back to the saved party and exit edit mode.
    final saved =
        ref.read(partyByIdProvider(widget.id)).value ?? widget.initial;
    if (saved != null) _populate(saved);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _editing = false;
      // Roll back image edits: restore server-side gallery, drop any
      // queued deletions and any local picks.
      _existingImages = List<PartyImageRef>.from(_originalExistingImages);
      _slotsToDelete.clear();
      _imagePaths.clear();
    });
  }

  int get _totalAttachedImages =>
      _imagePaths.length + _existingImages.length;

  Future<void> _pickImage() async {
    if (!_editing || _totalAttachedImages >= _maxImages) return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        // Cap the longest side so a 12MP phone photo doesn't land
        // above the backend's 5MB ceiling. Native resize on device.
        maxWidth: kPickerMaxDimension,
        maxHeight: kPickerMaxDimension,
      );
      if (file == null) return;
      if (!isAllowedImageFile(file.path)) {
        if (!mounted) return;
        SnackbarUtils.showError(context, kUnsupportedImageMessage);
        return;
      }
      final bytes = await imageFileBytes(file.path);
      if (bytes != null && bytes > kMaxImageBytes) {
        if (!mounted) return;
        SnackbarUtils.showError(context, imageTooLargeMessage(bytes));
        return;
      }
      setState(() => _imagePaths.add(file.path));
    } on Exception catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Could not load image.');
    }
  }

  void _removeImageAt(int index) {
    if (!_editing) return;
    setState(() => _imagePaths.removeAt(index));
  }

  /// Queue the existing image at [index] (in the current
  /// `_existingImages` list) for deletion. Removed from the picker
  /// immediately; the actual DELETE fires on save.
  void _removeExistingImageAt(int index) {
    if (!_editing) return;
    setState(() {
      final removed = _existingImages[index];
      _existingImages = List<PartyImageRef>.from(_existingImages)
        ..removeAt(index);
      _slotsToDelete.add(removed.slot);
    });
  }

  void _onLocationChanged(double lat, double lng) {
    setState(() {
      _latitude = lat;
      _longitude = lng;
    });
  }

  Future<void> _openInMaps() async {
    final launched = await openInMaps(lat: _latitude, lng: _longitude);
    if (!mounted || launched) return;
    SnackbarUtils.showError(context, "Couldn't open Google Maps.");
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final updated = Party(
        id: widget.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        ownerName: _ownerController.text.trim(),
        panVat: _panVatController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().nullIfEmpty(),
        dateJoined: _dateJoined,
        partyType: _partyType,
        notes: _notesController.text.trim().nullIfEmpty(),
        latitude: _latitude,
        longitude: _longitude,
        imagePaths: List<String>.unmodifiable(_imagePaths),
      );
      await ref.read(partiesControllerProvider.notifier).updateParty(updated);
      final imageResult = await _syncImageChanges();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
        // Local picks have been uploaded into slots; the next gallery
        // hydrate will reflect them. Clear locals + deletion queue so
        // a follow-up edit starts clean.
        _imagePaths.clear();
        _slotsToDelete.clear();
      });
      // Re-fetch the now-current gallery to refresh the picker's
      // network thumbnails (new slot URLs + the original snapshot).
      await _hydrateImages();
      if (!mounted) return;
      if (imageResult.uploadFailures > 0 ||
          imageResult.deleteFailures > 0) {
        SnackbarUtils.showError(
          context,
          _formatImageSyncWarning(imageResult),
        );
      } else {
        SnackbarUtils.showSuccess(
          context,
          'Party details updated successfully.',
        );
      }
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    }
  }

  /// Drains [_slotsToDelete] first (frees up slots), then uploads each
  /// new local file into the next free slot. Returns the per-bucket
  /// failure counts + the first backend error message we ran into, so
  /// [_save] can show a snackbar that says *why* something failed
  /// (not just how many). The customer PATCH already succeeded by the
  /// time this runs, so failures are non-fatal — the user can retry
  /// the missing slot on a subsequent edit.
  Future<
      ({
        int uploadFailures,
        int deleteFailures,
        String? firstError,
      })> _syncImageChanges() async {
    if (_slotsToDelete.isEmpty && _imagePaths.isEmpty) {
      return (uploadFailures: 0, deleteFailures: 0, firstError: null);
    }
    final repo = ref.read(partiesRepositoryProvider);
    var deleteFailures = 0;
    String? firstError;
    for (final slot in _slotsToDelete) {
      try {
        await repo.removeImage(customerId: widget.id, slot: slot);
      } on Object catch (e) {
        deleteFailures++;
        firstError ??= extractBackendErrorMessage(e) ?? 'Delete failed';
      }
    }
    final keptSlots = _existingImages.map((e) => e.slot).toSet();
    final freeSlots = <int>[
      for (var s = 1; s <= _maxImages; s++)
        if (!keptSlots.contains(s)) s,
    ];
    var uploadFailures = 0;
    for (var i = 0; i < _imagePaths.length && i < freeSlots.length; i++) {
      try {
        await repo.uploadImage(
          customerId: widget.id,
          filePath: _imagePaths[i],
          slot: freeSlots[i],
        );
      } on Object catch (e) {
        uploadFailures++;
        firstError ??= extractBackendErrorMessage(e) ?? 'Upload failed';
      }
    }
    return (
      uploadFailures: uploadFailures,
      deleteFailures: deleteFailures,
      firstError: firstError,
    );
  }

  String _formatImageSyncWarning(
    ({int uploadFailures, int deleteFailures, String? firstError}) r,
  ) {
    final parts = <String>[];
    if (r.uploadFailures > 0) {
      parts.add(
        "${r.uploadFailures} image${r.uploadFailures == 1 ? '' : 's'} "
        "didn't upload",
      );
    }
    if (r.deleteFailures > 0) {
      parts.add(
        "${r.deleteFailures} image${r.deleteFailures == 1 ? '' : 's'} "
        "couldn't be removed",
      );
    }
    final summary = 'Saved with issues: ${parts.join(', ')}';
    return r.firstError == null ? '$summary.' : '$summary — ${r.firstError}.';
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _DetailSkeleton(onBack: _back);
    if (_notFound) return const _NotFoundScaffold();
    // Watch the party so external updates (e.g. another tab) reflect here.
    ref.watch(partyByIdProvider(widget.id));

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: _SubmitBar(
          editing: _editing,
          isLoading: _saving,
          onPressed: _editing ? _save : _toggleEdit,
        ),
        body: Stack(
          children: <Widget>[
            const _CurvedHeader(),
            SafeArea(
              child: Column(
                children: <Widget>[
                  _DetailAppBar(
                    onBack: _back,
                    editing: _editing,
                    onCancel: _cancelEdit,
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            AnimatedBuilder(
                              animation: Listenable.merge(<Listenable>[
                                _nameController,
                                _addressController,
                              ]),
                              builder: (_, __) => _NameAddressCard(
                                name: _nameController.text,
                                address: _addressController.text,
                                onOpenMaps: _openInMaps,
                              ),
                            ),
                            SizedBox(height: 20.h),
                            Text(
                              'Party Details',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            SectionCard(
                              children: <Widget>[
                                PrimaryTextField(
                                  controller: _nameController,
                                  label: 'Party Name',
                                  hintText: 'Enter party name',
                                  prefixIcon: Icons.business_outlined,
                                  enabled: _editing,
                                  validator: (v) =>
                                      Validators.requiredField(v, 'Party name'),
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _ownerController,
                                  label: 'Owner Name',
                                  hintText: 'Enter owner name',
                                  prefixIcon: Icons.person_outline,
                                  enabled: _editing,
                                  validator: (v) =>
                                      Validators.requiredField(v, 'Owner name'),
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _panVatController,
                                  label: 'PAN/VAT Number',
                                  hintText: 'Enter PAN or VAT number',
                                  prefixIcon: Icons.receipt_long_outlined,
                                  keyboardType: TextInputType.number,
                                  enabled: _editing,
                                  maxLength: 9,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: Validators.panVat,
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _phoneController,
                                  label: 'Phone Number',
                                  hintText: 'Enter phone number',
                                  prefixIcon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  enabled: _editing,
                                  maxLength: 10,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: Validators.phone10,
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _emailController,
                                  label: 'Email Address',
                                  hintText: 'Enter email address',
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: _editing,
                                  validator: Validators.emailOptional,
                                ),
                                if (_editing || _partyType != null) ...<Widget>[
                                  SizedBox(height: 12.h),
                                  PartyTypePicker(
                                    value: _partyType,
                                    enabled: _editing,
                                    onChanged: (v) =>
                                        setState(() => _partyType = v),
                                  ),
                                ],
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _notesController,
                                  label: 'Notes',
                                  hintText: 'Add notes',
                                  prefixIcon: Icons.note_outlined,
                                  minLines: 1,
                                  maxLines: 4,
                                  enabled: _editing,
                                ),
                                SizedBox(height: 16.h),
                                LocationPicker(
                                  addressController: _addressController,
                                  latitude: _latitude,
                                  longitude: _longitude,
                                  editing: _editing,
                                  onLocationChanged: _onLocationChanged,
                                  addressValidator: (v) =>
                                      Validators.requiredField(v, 'Address'),
                                  showFullAddressCard: false,
                                ),
                                SizedBox(height: 12.h),
                                CustomDatePicker(
                                  controller: _dateController,
                                  label: 'Date Joined',
                                  hintText: 'Select date',
                                  prefixIcon: Icons.calendar_today_outlined,
                                  enabled: false,
                                  initialDate: _dateJoined,
                                  firstDate: DateTime(DateTime.now().year - 50),
                                  lastDate: DateTime(DateTime.now().year + 5),
                                  onDateSelected: (date) =>
                                      setState(() => _dateJoined = date),
                                ),
                                SizedBox(height: 18.h),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      'Party Image (Optional)',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '$_totalAttachedImages/$_maxImages',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10.h),
                                PrimaryImagePicker(
                                  imagePaths: _imagePaths,
                                  networkImageUrls: _existingImages
                                      .map((e) => e.url)
                                      .toList(growable: false),
                                  onRemoveNetwork: _removeExistingImageAt,
                                  maxImages: _maxImages,
                                  enabled: _editing,
                                  showLabel: false,
                                  onPick: _pickImage,
                                  onRemove: _removeImageAt,
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _CurvedHeader extends StatelessWidget {
  const _CurvedHeader();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SvgPicture.asset(
        'assets/images/corner_bubble.svg',
        fit: BoxFit.cover,
        height: 180.h,
      ),
    );
  }
}

class _DetailAppBar extends StatelessWidget {
  const _DetailAppBar({
    required this.onBack,
    required this.editing,
    required this.onCancel,
  });

  final VoidCallback onBack;
  final bool editing;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 4.h),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textdark,
              size: 20.sp,
            ),
            tooltip: 'Back',
            onPressed: onBack,
          ),
          SizedBox(width: 4.w),
          Text(
            'Details',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (editing)
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Cards / blocks ──────────────────────────────────────────────────────────

class _NameAddressCard extends StatelessWidget {
  const _NameAddressCard({
    required this.name,
    required this.address,
    required this.onOpenMaps,
  });

  final String name;
  final String address;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final addressStyle = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14.sp,
      fontWeight: FontWeight.w400,
      height: 1.45,
    );
    final displayAddress = address.isEmpty ? '—' : address;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 18.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            name.isEmpty ? '—' : name,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(top: 2.h, right: 8.w),
                child: Icon(
                  Icons.place_outlined,
                  color: AppColors.textSecondary,
                  size: 18.sp,
                ),
              ),
              Expanded(child: Text(displayAddress, style: addressStyle)),
            ],
          ),
          SizedBox(height: 14.h),
          _OpenInMapsButton(onTap: onOpenMaps),
        ],
      ),
    );
  }
}

class _OpenInMapsButton extends StatelessWidget {
  const _OpenInMapsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 1.2),
            borderRadius: BorderRadius.circular(12.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.map_outlined,
                color: AppColors.primary,
                size: 16.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'Open in Maps',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.editing,
    required this.isLoading,
    required this.onPressed,
  });

  final bool editing;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
          child: PrimaryButton(
            label: editing ? 'Save Changes' : 'Edit Detail',
            leadingIcon: editing ? Icons.check : Icons.edit,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

/// Skeleton scaffold rendered while the party is hydrating. Mirrors the
/// real layout (header, name/address card, section card, submit bar) so
/// the swap to real data doesn't shift the page around.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: DarkStatusBar(
        child: Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
                child: Bone(
                  width: double.infinity,
                  height: 60.h,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
          body: Stack(
            children: <Widget>[
              const _CurvedHeader(),
              SafeArea(
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 4.h),
                      child: Row(
                        children: <Widget>[
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: AppColors.textdark,
                              size: 20.sp,
                            ),
                            tooltip: 'Back',
                            onPressed: onBack,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Details',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // Name + address + maps-button card placeholder.
                            Container(
                              padding: EdgeInsets.fromLTRB(
                                20.w,
                                20.h,
                                20.w,
                                16.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(20.r),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    blurRadius: 20.r,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Bone.text(words: 2, fontSize: 22.sp),
                                  SizedBox(height: 12.h),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: 2.h,
                                          right: 8.w,
                                        ),
                                        child: Bone.icon(size: 18.sp),
                                      ),
                                      Expanded(
                                        child: Bone.multiText(
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 14.h),
                                  Bone(
                                    width: 150.w,
                                    height: 36.h,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20.h),
                            Bone(
                              width: 90.w,
                              height: 12.h,
                              uniRadius: 12.h / 2,
                            ),
                            SizedBox(height: 12.h),
                            // Form-fields card placeholder.
                            SectionCard(
                              children: <Widget>[
                                for (var i = 0; i < 6; i++) ...<Widget>[
                                  if (i > 0) SizedBox(height: 12.h),
                                  Bone(
                                    width: double.infinity,
                                    height: 56.h,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ],
                                SizedBox(height: 16.h),
                                Bone(
                                  width: double.infinity,
                                  height: 200.h,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                SizedBox(height: 14.h),
                                Bone(
                                  width: double.infinity,
                                  height: 56.h,
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFoundScaffold extends StatelessWidget {
  const _NotFoundScaffold();

  @override
  Widget build(BuildContext context) {
    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.primary,
          title: const Text('Details'),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              "Couldn't load this party — it may have been removed.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
            ),
          ),
        ),
      ),
    );
  }
}

extension on String {
  String? nullIfEmpty() => isEmpty ? null : this;
}
