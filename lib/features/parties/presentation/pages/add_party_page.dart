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
import 'package:sales_sphere_erp/shared/widgets/info_banner.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Flip to `true` once you've added a Google Maps API key to
/// `android/app/src/main/AndroidManifest.xml`:
///
/// ```xml
/// <meta-data
///     android:name="com.google.android.geo.API_KEY"
///     android:value="YOUR_KEY_HERE"/>
/// ```
///
/// Without the key the Maps SDK throws `IllegalStateException` and crashes
/// the app, so we render a static placeholder until the key is wired up.
const bool _googleMapsEnabled = false;

class AddPartyPage extends ConsumerStatefulWidget {
  const AddPartyPage({super.key});

  @override
  ConsumerState<AddPartyPage> createState() => _AddPartyPageState();
}

class _AddPartyPageState extends ConsumerState<AddPartyPage> {
  // Default camera target — Bengaluru. Replaced as soon as the user picks
  // a point or taps "use my current location".
  static const _defaultLatLng = LatLng(13.134965, 77.566811);

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _panVatController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();

  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();

  static const _maxImages = 2;

  String? _partyType;
  DateTime? _dateJoined;
  LatLng _pinned = _defaultLatLng;
  final List<String> _imagePaths = <String>[];
  bool _locating = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _panVatController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
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
    if (_imagePaths.length >= _maxImages) return;
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
    setState(() => _imagePaths.removeAt(index));
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
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

      // Best-effort reverse-geocode to fill the search-address field.
      unawaited(_reverseGeocode(next));

      if (_googleMapsEnabled && _mapController.isCompleted) {
        final controller = await _mapController.future;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(next, 16),
        );
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
      // Reverse geocoding is non-critical; ignore failures silently.
    }
  }

  void _onMapTap(LatLng latLng) {
    setState(() => _pinned = latLng);
    unawaited(_reverseGeocode(latLng));
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      final repo = ref.read(partiesRepositoryProvider);
      final draft = Party(
        id: '', // assigned by the API mock
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
      await repo.addParty(draft);
      ref.invalidate(partiesListProvider);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Party added.');
      context.pop();
    } on Exception catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LightStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.primary,
        bottomNavigationBar: _SubmitBar(
          isLoading: _submitting,
          onPressed: _submit,
        ),
        body: Column(
          children: <Widget>[
            _Header(onBack: () => context.pop()),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28.r),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 24.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        PrimaryTextField(
                          controller: _nameController,
                          hintText: 'Party Name',
                          prefixIcon: Icons.business_outlined,
                          textInputAction: TextInputAction.next,
                          floatingLabel: true,
                          validator: (v) => (v?.trim().isEmpty ?? true)
                              ? 'Party name is required'
                              : null,
                        ),
                        SizedBox(height: 14.h),
                        PrimaryTextField(
                          controller: _ownerController,
                          hintText: 'Owner Name',
                          prefixIcon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          floatingLabel: true,
                          validator: (v) => (v?.trim().isEmpty ?? true)
                              ? 'Owner name is required'
                              : null,
                        ),
                        SizedBox(height: 14.h),
                        PrimaryTextField(
                          controller: _panVatController,
                          hintText: 'PAN/VAT Number',
                          prefixIcon: Icons.receipt_long_outlined,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          floatingLabel: true,
                          maxLength: 9,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return 'PAN/VAT number is required';
                            if (t.length != 9) {
                              return 'PAN/VAT number must be 9 digits';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 14.h),
                        PrimaryTextField(
                          controller: _phoneController,
                          hintText: 'Phone Number',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          floatingLabel: true,
                          maxLength: 10,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return 'Phone number is required';
                            if (t.length != 10) {
                              return 'Phone number must be 10 digits';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 14.h),
                        PrimaryTextField(
                          controller: _emailController,
                          hintText: 'Email Address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          floatingLabel: true,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? null
                              : Validators.email(v),
                        ),
                        SizedBox(height: 14.h),
                        // Date Joined — read-only, opens a date picker on tap.
                        GestureDetector(
                          onTap: _pickDate,
                          child: AbsorbPointer(
                            child: PrimaryTextField(
                              controller: _dateController,
                              hintText: 'Date Joined',
                              prefixIcon: Icons.calendar_today_outlined,
                              floatingLabel: true,
                              suffixWidget: Icon(
                                Icons.calendar_month_outlined,
                                color: AppColors.primary,
                                size: 20.sp,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 14.h),
                        PartyTypePicker(
                          value: _partyType,
                          enabled: true,
                          onChanged: (v) => setState(() => _partyType = v),
                        ),
                        SizedBox(height: 14.h),
                        PrimaryTextField(
                          controller: _notesController,
                          hintText: 'Notes',
                          prefixIcon: Icons.note_outlined,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          floatingLabel: true,
                        ),
                        SizedBox(height: 14.h),
                        PrimaryTextField(
                          controller: _addressController,
                          hintText: 'Search address...',
                          prefixIcon: Icons.search,
                          textInputAction: TextInputAction.search,
                          floatingLabel: true,
                          validator: (v) => (v?.trim().isEmpty ?? true)
                              ? 'Address is required'
                              : null,
                        ),
                        SizedBox(height: 14.h),
                        CustomButton(
                          label: 'Use My Current Location',
                          leadingIcon: Icons.my_location,
                          isLoading: _locating,
                          onPressed: _useCurrentLocation,
                        ),
                        SizedBox(height: 16.h),
                        _MapPreview(
                          target: _pinned,
                          onTap: _onMapTap,
                          onMapCreated: (controller) {
                            if (!_mapController.isCompleted) {
                              _mapController.complete(controller);
                            }
                          },
                        ),
                        SizedBox(height: 14.h),
                        const InfoBanner(
                          message:
                              'Drag & pinch to navigate the map. Tap '
                              'anywhere to pinpoint exact location. Use '
                              '+/- zoom controls for precision.',
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
                          value: _pinned.latitude.toStringAsFixed(6),
                        ),
                        SizedBox(height: 10.h),
                        CoordField(
                          label: 'Longitude',
                          value: _pinned.longitude.toStringAsFixed(6),
                        ),
                        SizedBox(height: 18.h),
                        Row(
                          children: <Widget>[
                            Text(
                              'Party Image (Optional)',
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
                        _ImagePickerStrip(
                          paths: _imagePaths,
                          maxImages: _maxImages,
                          onAdd: _pickImage,
                          onRemove: _removeImageAt,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8.w, 4.h, 16.w, 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: AppColors.textWhite,
                  size: 24.sp,
                ),
                onPressed: onBack,
                tooltip: 'Back',
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'New member in the Family',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textWhite.withValues(alpha: 0.8),
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Add New Party',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 26.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.target,
    required this.onTap,
    required this.onMapCreated,
  });

  final LatLng target;
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
                onTap: onTap,
                onMapCreated: onMapCreated,
                myLocationButtonEnabled: false,
                compassEnabled: false,
              )
            : const _MapPlaceholder(),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.map_outlined,
            color: AppColors.textSecondary,
            size: 48.sp,
          ),
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Text(
              'Map disabled — add a Google Maps API key to '
              'AndroidManifest.xml to enable.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.sp,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the picked images side-by-side with a "tap to add" placeholder
/// in the next free slot. Supports up to [maxImages] entries.
class _ImagePickerStrip extends StatelessWidget {
  const _ImagePickerStrip({
    required this.paths,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> paths;
  final int maxImages;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final canAddMore = paths.length < maxImages;
    final tiles = <Widget>[
      for (int i = 0; i < paths.length; i++)
        Expanded(
          child: _ImageTile(
            path: paths[i],
            onClear: () => onRemove(i),
          ),
        ),
      if (canAddMore)
        Expanded(child: _AddImageTile(onTap: onAdd)),
    ];

    final separated = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) separated.add(SizedBox(width: 12.w));
      separated.add(tiles[i]);
    }
    return SizedBox(
      height: 150.h,
      child: Row(children: separated),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.path, required this.onClear});

  final String path;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.file(File(path), fit: BoxFit.cover),
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

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
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
  const _SubmitBar({required this.isLoading, required this.onPressed});

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
            label: 'Add Party',
            leadingIcon: Icons.add_circle_outline,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
