import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/parties/data/parties_repository.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/presentation/widgets/party_type_picker.dart';
import 'package:sales_sphere_erp/shared/utils/app_date_picker.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/string_extensions.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/coord_field.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/full_screen_image.dart';
import 'package:sales_sphere_erp/shared/widgets/info_banner.dart';
import 'package:sales_sphere_erp/shared/widgets/no_glow_scroll_behavior.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/skeleton.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

// Mirrors the flag in [add_party_page.dart] — flip to `true` once a Google
// Maps API key is configured in `AndroidManifest.xml` to enable the live map.
const bool _googleMapsEnabled = false;

class PartyDetailPage extends ConsumerStatefulWidget {
  const PartyDetailPage({required this.id, this.initial, super.key});

  final String id;

  /// Optional starting party passed via `extra` when navigating from the
  /// list — saves a re-fetch on first paint.
  final Party? initial;

  @override
  ConsumerState<PartyDetailPage> createState() => _PartyDetailPageState();
}

class _PartyDetailPageState extends ConsumerState<PartyDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _panVatController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();
  final _dateController = TextEditingController();

  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();

  static const _maxImages = 2;

  String? _partyType;
  DateTime? _dateJoined;
  LatLng _pinned = const LatLng(0, 0);
  final List<String> _imagePaths = <String>[];

  bool _editing = false;
  bool _saving = false;
  bool _locating = false;
  bool _loading = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _populate(widget.initial!);
    } else {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }
  }

  /// Loads the party from the repository. Today the lookup is in-memory;
  /// when the real API lands, replace the delay + lookup with
  /// `await ref.read(partyByIdProvider(widget.id).future)`.
  Future<void> _hydrate() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final party = ref.read(partyByIdProvider(widget.id));
    if (party != null) {
      _populate(party);
      setState(() => _loading = false);
    } else {
      setState(() {
        _loading = false;
        _notFound = true;
      });
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
    _ownerController.text = p.ownerName ?? '';
    _panVatController.text = p.panVat ?? '';
    _phoneController.text = p.phone ?? '';
    _emailController.text = p.email ?? '';
    _notesController.text = p.notes ?? '';
    _addressController.text = p.address;
    _partyType = p.partyType;
    _dateJoined = p.dateJoined;
    _dateController.text =
        p.dateJoined != null ? DateFormat.yMMMd().format(p.dateJoined!) : '';
    _pinned = LatLng(p.latitude ?? 0, p.longitude ?? 0);
    _imagePaths
      ..clear()
      ..addAll(p.imagePaths);
  }

  void _toggleEdit() {
    setState(() => _editing = !_editing);
  }

  void _cancelEdit() {
    // Reset every field back to the saved party and exit edit mode.
    final saved = ref.read(partyByIdProvider(widget.id)) ?? widget.initial;
    if (saved != null) _populate(saved);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _editing = false);
  }

  Future<void> _pickDate() async {
    if (!_editing) return;
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _dateJoined ?? now,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 5),
      helpText: 'Date Joined',
    );
    if (picked == null) return;
    setState(() {
      _dateJoined = picked;
      _dateController.text = DateFormat.yMMMd().format(picked);
    });
  }

  Future<void> _pickImage() async {
    if (!_editing || _imagePaths.length >= _maxImages) return;
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

  Future<void> _useCurrentLocation() async {
    if (!_editing || _locating) return;
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        SnackbarUtils.showError(context, 'Location permission denied.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final next = LatLng(position.latitude, position.longitude);
      setState(() => _pinned = next);
      unawaited(_reverseGeocode(next));
      if (_googleMapsEnabled && _mapController.isCompleted) {
        final controller = await _mapController.future;
        await controller
            .animateCamera(CameraUpdate.newLatLngZoom(next, 16));
      }
    } on Exception catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, "Couldn't fetch your location.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (placemarks.isEmpty || !mounted) return;
      final p = placemarks.first;
      final parts = <String?>[
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ].whereType<String>().where((s) => s.isNotEmpty);
      _addressController.text = parts.join(', ');
    } on Exception catch (_) {
      // best-effort
    }
  }

  void _onMapTap(LatLng latLng) {
    if (!_editing) return;
    setState(() => _pinned = latLng);
    unawaited(_reverseGeocode(latLng));
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final repo = ref.read(partiesRepositoryProvider);
      final updated = Party(
        id: widget.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        ownerName: _ownerController.text.trim().nullIfEmpty(),
        panVat: _panVatController.text.trim().nullIfEmpty(),
        phone: _phoneController.text.trim().nullIfEmpty(),
        email: _emailController.text.trim().nullIfEmpty(),
        dateJoined: _dateJoined,
        partyType: _partyType,
        notes: _notesController.text.trim().nullIfEmpty(),
        latitude: _pinned.latitude,
        longitude: _pinned.longitude,
        imagePaths: List<String>.unmodifiable(_imagePaths),
      );
      await repo.updateParty(updated);
      ref.invalidate(partiesListProvider);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
      SnackbarUtils.showSuccess(
        context,
        'Party details updated successfully.',
      );
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    }
  }

  void _previewImage(int index) {
    if (index < 0 || index >= _imagePaths.length) return;
    FullScreenImage.show(context, _imagePaths[index]);
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
                      child: ScrollConfiguration(
                        // Suppress Android's overscroll glow so it doesn't
                        // paint a coloured rectangle behind the rounded cards.
                        behavior: const NoGlowScrollBehavior(),
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
                                onOpenMaps: () {
                                  SnackbarUtils.showInfo(
                                    context,
                                    'External maps not wired yet.',
                                  );
                                },
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
                                  hintText: 'Party Name',
                                  prefixIcon: Icons.business_outlined,
                                  floatingLabel: true,
                                  enabled: _editing,
                                  validator: (v) => (v?.trim().isEmpty ?? true)
                                      ? 'Party name is required'
                                      : null,
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _ownerController,
                                  hintText: 'Owner Name',
                                  prefixIcon: Icons.person_outline,
                                  floatingLabel: true,
                                  enabled: _editing,
                                  validator: (v) => (v?.trim().isEmpty ?? true)
                                      ? 'Owner name is required'
                                      : null,
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _panVatController,
                                  hintText: 'PAN/VAT Number',
                                  prefixIcon: Icons.receipt_long_outlined,
                                  keyboardType: TextInputType.number,
                                  floatingLabel: true,
                                  enabled: _editing,
                                  maxLength: 9,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (v) {
                                    final t = v?.trim() ?? '';
                                    if (t.isEmpty) {
                                      return 'PAN/VAT number is required';
                                    }
                                    if (t.length != 9) {
                                      return 'PAN/VAT number must be 9 digits';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _phoneController,
                                  hintText: 'Phone Number',
                                  prefixIcon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  floatingLabel: true,
                                  enabled: _editing,
                                  maxLength: 10,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (v) {
                                    final t = v?.trim() ?? '';
                                    if (t.isEmpty) {
                                      return 'Phone number is required';
                                    }
                                    if (t.length != 10) {
                                      return 'Phone number must be 10 digits';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _emailController,
                                  hintText: 'Email Address',
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  floatingLabel: true,
                                  enabled: _editing,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? null
                                          : Validators.email(v),
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
                                  hintText: 'Notes',
                                  prefixIcon: Icons.note_outlined,
                                  minLines: 1,
                                  maxLines: 4,
                                  floatingLabel: true,
                                  enabled: _editing,
                                ),
                                SizedBox(height: 16.h),
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _addressController,
                                  builder: (_, value, __) {
                                    return PrimaryTextField(
                                      controller: _addressController,
                                      hintText: 'Search address...',
                                      prefixIcon: Icons.search,
                                      floatingLabel: true,
                                      enabled: _editing,
                                      suffixWidget: value.text.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.close,
                                                size: 20.sp,
                                                color: AppColors
                                                    .textSecondary,
                                              ),
                                              tooltip: 'Clear',
                                              onPressed:
                                                  _addressController.clear,
                                            )
                                          : null,
                                      validator: (v) =>
                                          (v?.trim().isEmpty ?? true)
                                              ? 'Address is required'
                                              : null,
                                    );
                                  },
                                ),
                                if (_editing) ...<Widget>[
                                  SizedBox(height: 12.h),
                                  CustomButton(
                                    label: 'Use My Current Location',
                                    leadingIcon: Icons.my_location,
                                    isLoading: _locating,

                                    onPressed: _useCurrentLocation,
                                  ),
                                ],
                                SizedBox(height: 14.h),
                                _MapPreview(
                                  target: _pinned,
                                  editing: _editing,
                                  onTap: _onMapTap,
                                  onMapCreated: (controller) {
                                    if (!_mapController.isCompleted) {
                                      _mapController.complete(controller);
                                    }
                                  },
                                ),
                                SizedBox(height: 14.h),
                                InfoBanner(
                                  message: _editing
                                      ? 'Drag & pinch to navigate the map. '
                                          'Tap anywhere to pinpoint exact '
                                          'location. Use +/- zoom controls '
                                          'for precision.'
                                      : 'View current location on map. '
                                          'Enable edit mode to change '
                                          'location.',
                                ),
                                SizedBox(height: 18.h),
                                Text(
                                  'Location Details (Auto-generated from map)',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                CoordField(
                                  label: 'Latitude',
                                  value:
                                      _pinned.latitude.toStringAsFixed(6),
                                ),
                                SizedBox(height: 10.h),
                                CoordField(
                                  label: 'Longitude',
                                  value:
                                      _pinned.longitude.toStringAsFixed(6),
                                ),
                                SizedBox(height: 12.h),
                                GestureDetector(
                                  onTap: _pickDate,
                                  child: AbsorbPointer(
                                    child: PrimaryTextField(
                                      controller: _dateController,
                                      hintText: 'Date Joined',
                                      prefixIcon:
                                          Icons.calendar_today_outlined,
                                      floatingLabel: true,
                                      enabled: _editing,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 18.h),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      'Party Image',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_imagePaths.length}/$_maxImages',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10.h),
                                _PartyImageStrip(
                                  paths: _imagePaths,
                                  maxImages: _maxImages,
                                  editing: _editing,
                                  onAdd: _pickImage,
                                  onRemove: _removeImageAt,
                                  onPreview: _previewImage,
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                          ],
                        ),
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
    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        height: 200.h,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.headerGradientStart,
              AppColors.headerGradientEnd,
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * 0.30)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.45,
        size.width,
        size.height * 0.85,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
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
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 6.h,
                ),
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
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 14.w, 20.h),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  name.isEmpty ? '—' : name,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Material(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10.r),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10.r),
                  onTap: onOpenMaps,
                  child: Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Icon(
                      Icons.open_in_new,
                      color: AppColors.primary,
                      size: 18.sp,
                    ),
                  ),
                ),
              ),
            ],
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
              Expanded(
                child: Text(
                  address.isEmpty ? '—' : address,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.target,
    required this.editing,
    required this.onTap,
    required this.onMapCreated,
  });

  final LatLng target;
  final bool editing;
  final ValueChanged<LatLng> onTap;
  final void Function(GoogleMapController) onMapCreated;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: SizedBox(
        height: 220.h,
        child: _googleMapsEnabled
            ? GoogleMap(
                initialCameraPosition:
                    CameraPosition(target: target, zoom: 14),
                markers: <Marker>{
                  Marker(
                    markerId: const MarkerId('pinned'),
                    position: target,
                  ),
                },
                onTap: editing ? onTap : null,
                onMapCreated: onMapCreated,
                myLocationButtonEnabled: false,
                compassEnabled: false,
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppColors.headerGradientStart,
                      AppColors.headerGradientEnd,
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 56.w,
                        height: 56.w,
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.map_outlined,
                          color: AppColors.primary,
                          size: 28.sp,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Map preview unavailable',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Text(
                          'Configure your Google Maps API key to enable.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.sp,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Strip of party images. View mode: read-only thumbnails that open
/// fullscreen preview on tap. Edit mode: thumbnails get a clear-X overlay
/// and an "add image" tile fills the remaining slot up to [maxImages].
class _PartyImageStrip extends StatelessWidget {
  const _PartyImageStrip({
    required this.paths,
    required this.maxImages,
    required this.editing,
    required this.onAdd,
    required this.onRemove,
    required this.onPreview,
  });

  final List<String> paths;
  final int maxImages;
  final bool editing;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int index) onPreview;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty && !editing) {
      return Container(
        height: 160.h,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.image_outlined,
              color: AppColors.textSecondary,
              size: 48.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              'No images attached',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      );
    }

    final canAddMore = editing && paths.length < maxImages;
    final tiles = <Widget>[
      for (int i = 0; i < paths.length; i++)
        Expanded(
          child: _DetailImageTile(
            path: paths[i],
            editing: editing,
            onClear: () => onRemove(i),
            onPreview: () => onPreview(i),
          ),
        ),
      if (canAddMore)
        Expanded(child: _DetailAddTile(onTap: onAdd)),
    ];

    final separated = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) separated.add(SizedBox(width: 12.w));
      separated.add(tiles[i]);
    }
    return SizedBox(
      height: 160.h,
      child: Row(children: separated),
    );
  }
}

class _DetailImageTile extends StatelessWidget {
  const _DetailImageTile({
    required this.path,
    required this.editing,
    required this.onClear,
    required this.onPreview,
  });

  final String path;
  final bool editing;
  final VoidCallback onClear;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            onTap: onPreview,
            child: Image.file(File(path), fit: BoxFit.cover),
          ),
          Positioned(
            right: 8.w,
            bottom: 8.h,
            child: Material(
              color: AppColors.overlay,
              borderRadius: BorderRadius.circular(20.r),
              child: InkWell(
                borderRadius: BorderRadius.circular(20.r),
                onTap: onPreview,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 4.h,
                  ),
                  child: Icon(
                    Icons.zoom_in,
                    color: AppColors.textWhite,
                    size: 16.sp,
                  ),
                ),
              ),
            ),
          ),
          if (editing)
            Positioned(
              top: 6.h,
              right: 6.w,
              child: Material(
                color: AppColors.overlay,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onClear,
                  child: Padding(
                    padding: EdgeInsets.all(6.w),
                    child: Icon(
                      Icons.close,
                      color: AppColors.textWhite,
                      size: 18.sp,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailAddTile extends StatelessWidget {
  const _DetailAddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.add_photo_alternate_outlined,
              color: AppColors.textSecondary,
              size: 32.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              'Tap to add image',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
              ),
            ),
          ],
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
            size: ButtonSize.large,
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
    return DarkStatusBar(
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
              child: Skeleton(
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
                    child: ScrollConfiguration(
                      behavior: const NoGlowScrollBehavior(),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // Name + address card placeholder.
                            Container(
                              padding:
                                  EdgeInsets.fromLTRB(20.w, 18.h, 12.w, 18.h),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16.r),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: AppColors.shadow,
                                    blurRadius: 12.r,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Skeleton.line(width: 140.w, height: 20.h),
                                  SizedBox(height: 14.h),
                                  Skeleton.line(
                                    width: double.infinity,
                                    height: 12.h,
                                  ),
                                  SizedBox(height: 6.h),
                                  Skeleton.line(width: 200.w, height: 12.h),
                                ],
                              ),
                            ),
                            SizedBox(height: 20.h),
                            Skeleton.line(width: 90.w, height: 12.h),
                            SizedBox(height: 12.h),
                            // Form-fields card placeholder.
                            SectionCard(
                              children: <Widget>[
                                for (var i = 0; i < 6; i++) ...<Widget>[
                                  if (i > 0) SizedBox(height: 12.h),
                                  Skeleton(
                                    width: double.infinity,
                                    height: 56.h,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ],
                                SizedBox(height: 16.h),
                                Skeleton(
                                  width: double.infinity,
                                  height: 200.h,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                SizedBox(height: 14.h),
                                Skeleton(
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
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
