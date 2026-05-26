import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/data/dto/miscellaneous_work_image_ref.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/presentation/controllers/miscellaneous_work_controller.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/presentation/providers/miscellaneous_work_providers.dart';
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

class EditMiscellaneousWorkDetailPage extends ConsumerStatefulWidget {
  const EditMiscellaneousWorkDetailPage({
    required this.id,
    this.initial,
    super.key,
  });

  final String id;

  /// Optional starting record passed via `extra` when navigating from
  /// the list — saves a re-fetch on first paint.
  final MiscellaneousWork? initial;

  @override
  ConsumerState<EditMiscellaneousWorkDetailPage> createState() =>
      _EditMiscellaneousWorkDetailPageState();
}

class _EditMiscellaneousWorkDetailPageState
    extends ConsumerState<EditMiscellaneousWorkDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final _natureController = TextEditingController();
  final _assignedByController = TextEditingController();
  final _workDateController = TextEditingController();
  final _addressController = TextEditingController();
  final _createdAtController = TextEditingController();

  static const _maxImages = 2;

  // Kathmandu default — matches add_party_page. Only used when the
  // record is still loading or the user opens an item that somehow
  // landed without coords; `_populate()` overwrites with the real
  // record's lat/lng on hydrate.
  static const _defaultLat = 27.7172;
  static const _defaultLng = 85.3240;

  DateTime _workDate = DateTime.now();
  double _latitude = _defaultLat;
  double _longitude = _defaultLng;
  DateTime? _createdAt;

  /// Local file paths picked in this edit session — uploaded to free
  /// slots in `_save`.
  final List<String> _imagePaths = <String>[];

  /// Server-side images at the moment we render. Mutated as the user
  /// removes thumbnails; `_originalExistingImages` is the snapshot
  /// used by cancel to restore.
  List<MiscellaneousWorkImageRef> _existingImages =
      const <MiscellaneousWorkImageRef>[];
  List<MiscellaneousWorkImageRef> _originalExistingImages =
      const <MiscellaneousWorkImageRef>[];

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
      // Fields populate synchronously, but the gallery still needs a
      // fetch — kick it off after first frame so the picker fills in.
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateImages());
    } else {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }
  }

  /// Loads the record by awaiting the byId provider's future.
  Future<void> _hydrate() async {
    MiscellaneousWork? work;
    try {
      work = await ref.read(miscellaneousWorkByIdProvider(widget.id).future);
    } on Object catch (_) {
      // List failed; fall through to the not-found state below.
    }
    if (!mounted) return;
    if (work != null) {
      _populate(work);
      setState(() => _loading = false);
      await _hydrateImages();
    } else {
      setState(() {
        _loading = false;
        _notFound = true;
      });
    }
  }

  /// Fetch the gallery so the picker shows server-side images.
  /// Failures are swallowed — an empty picker is graceful degradation.
  Future<void> _hydrateImages() async {
    try {
      final images = await ref
          .read(miscellaneousWorkRepositoryProvider)
          .listImages(widget.id);
      if (!mounted) return;
      setState(() {
        _existingImages = images;
        _originalExistingImages =
            List<MiscellaneousWorkImageRef>.unmodifiable(images);
      });
    } on Object catch (_) {
      // Not fatal — picker stays empty on the network image side and
      // the user can still pick new locals.
    }
  }

  @override
  void dispose() {
    _natureController.dispose();
    _assignedByController.dispose();
    _workDateController.dispose();
    _addressController.dispose();
    _createdAtController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    final months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  void _populate(MiscellaneousWork w) {
    _natureController.text = w.natureOfWork;
    _assignedByController.text = w.assignedBy;
    _workDate = w.workDate;
    _workDateController.text = _formatDate(w.workDate);
    _addressController.text = w.address;
    _latitude = w.latitude;
    _longitude = w.longitude;
    _createdAt = w.createdAt;
    _createdAtController.text =
        DateFormat('dd MMM yyyy, hh:mm a').format(w.createdAt.toLocal());
    _imagePaths.clear();
  }

  void _toggleEdit() => setState(() => _editing = !_editing);

  void _cancelEdit() {
    final saved =
        ref.read(miscellaneousWorkByIdProvider(widget.id)).value ??
            widget.initial;
    if (saved != null) _populate(saved);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _editing = false;
      // Roll back image edits: restore server-side gallery, drop any
      // queued deletions and any local picks.
      _existingImages =
          List<MiscellaneousWorkImageRef>.from(_originalExistingImages);
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
      );
      if (file == null) return;
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
      _existingImages =
          List<MiscellaneousWorkImageRef>.from(_existingImages)
            ..removeAt(index);
      _slotsToDelete.add(removed.slot);
    });
  }

  void _onLocationChanged(double lat, double lng) {
    if (!_editing) return;
    setState(() {
      _latitude = lat;
      _longitude = lng;
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final updated = MiscellaneousWork(
        id: widget.id,
        natureOfWork: _natureController.text.trim(),
        assignedBy: _assignedByController.text.trim(),
        workDate: _workDate,
        address: _addressController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        createdAt: _createdAt ?? DateTime.now(),
        // imagePaths is left at its default (empty) — local picks are
        // uploaded separately via _syncImageChanges, the PATCH body
        // doesn't carry filesystem paths.
      );
      await ref
          .read(miscellaneousWorkControllerProvider.notifier)
          .updateWork(updated);
      final imageResult = await _syncImageChanges();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
        _imagePaths.clear();
        _slotsToDelete.clear();
      });
      // Re-fetch the now-current gallery to refresh the picker's
      // network thumbnails (new slot URLs + the original snapshot).
      await _hydrateImages();
      if (!mounted) return;
      if (imageResult.uploadFailures > 0 || imageResult.deleteFailures > 0) {
        SnackbarUtils.showError(
          context,
          _formatImageSyncWarning(imageResult),
        );
      } else {
        SnackbarUtils.showSuccess(context, 'Work updated successfully.');
      }
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    }
  }

  /// Drains [_slotsToDelete] first (frees up slots), then uploads each
  /// new local file into the next free slot. Returns per-bucket
  /// failure counts + the first backend error message we ran into,
  /// so [_save] can show a snackbar that says *why* something failed
  /// (not just how many). The PATCH already succeeded by the time
  /// this runs, so failures are non-fatal — the user can retry the
  /// missing slot on a subsequent edit.
  Future<({int uploadFailures, int deleteFailures, String? firstError})>
      _syncImageChanges() async {
    if (_slotsToDelete.isEmpty && _imagePaths.isEmpty) {
      return (uploadFailures: 0, deleteFailures: 0, firstError: null);
    }
    final repo = ref.read(miscellaneousWorkRepositoryProvider);
    var deleteFailures = 0;
    String? firstError;
    for (final slot in _slotsToDelete) {
      try {
        await repo.removeImage(id: widget.id, slot: slot);
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
          id: widget.id,
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
    // Keep the provider warm so cancelEdit can read the saved snapshot.
    ref.watch(miscellaneousWorkByIdProvider(widget.id));

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
                            SectionCard(
                              children: <Widget>[
                                PrimaryTextField(
                                  controller: _natureController,
                                  label: 'Nature of Work',
                                  hintText: 'Enter nature of work',
                                  prefixIcon: Icons.work_outline_rounded,
                                  minLines: 1,
                                  maxLines: 2,
                                  enabled: _editing,
                                  validator: (v) => Validators.requiredField(
                                    v,
                                    'Nature of Work',
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _assignedByController,
                                  label: 'Assigned By',
                                  hintText: 'Who assigned this task?',
                                  prefixIcon: Icons.person_outline_rounded,
                                  enabled: _editing,
                                  validator: (v) => Validators.requiredField(
                                    v,
                                    'Assigned By',
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                CustomDatePicker(
                                  controller: _workDateController,
                                  label: 'Work Date',
                                  hintText: 'When was this work done?',
                                  prefixIcon: Icons.calendar_today_outlined,
                                  enabled: _editing,
                                  initialDate: _workDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                  onDateSelected: (picked) =>
                                      setState(() => _workDate = picked),
                                  validator: (v) =>
                                      Validators.requiredField(v, 'Work Date'),
                                ),
                                SizedBox(height: 12.h),
                                LocationPicker(
                                  addressController: _addressController,
                                  latitude: _latitude,
                                  longitude: _longitude,
                                  editing: _editing,
                                  showFullAddressCard: false,
                                  onLocationChanged: _onLocationChanged,
                                  addressValidator: (v) =>
                                      Validators.requiredField(v, 'Address'),
                                ),
                                SizedBox(height: 12.h),
                                // Read-only metadata. The submission
                                // timestamp is server-assigned and not
                                // user-editable, so the field stays
                                // disabled regardless of edit mode.
                                PrimaryTextField(
                                  controller: _createdAtController,
                                  label: 'Created On',
                                  hintText: '—',
                                  prefixIcon: Icons.access_time_rounded,
                                  enabled: false,
                                  readOnly: true,
                                ),
                                SizedBox(height: 18.h),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      'Work Image (Optional)',
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

// ── Header ─────────────────────────────────────────────────────────

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
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
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
                        child: SectionCard(
                          children: <Widget>[
                            for (var i = 0; i < 4; i++) ...<Widget>[
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
                              height: 220.h,
                              borderRadius: BorderRadius.circular(12.r),
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
              "Couldn't load this work item — it may have been removed.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
            ),
          ),
        ),
      ),
    );
  }
}
