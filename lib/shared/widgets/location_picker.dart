import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// Flip to `true` once a Google Maps API key has been added to
/// `android/app/src/main/AndroidManifest.xml`:
///
/// ```xml
/// <meta-data
///     android:name="com.google.android.geo.API_KEY"
///     android:value="YOUR_KEY_HERE"/>
/// ```
///
/// Without the key the Maps SDK throws `IllegalStateException` and crashes
/// the app, so the picker renders a placeholder until the key is wired up.
const bool kGoogleMapsEnabled = false;

/// Composite location-picking block. Wraps:
///   * a "Search address" text field (optionally clearable)
///   * a "Use My Current Location" action button (only when [editing])
///   * a Google Map preview / placeholder with tap-to-pin
///   * an info banner explaining the interaction
///   * a "Location Details" label + read-only Latitude / Longitude fields
///
/// Encapsulates the full location-picking flow — geolocator permission,
/// position fetch, reverse-geocoding, and camera animation. Parents just
/// listen for [onLocationChanged] to persist the new coordinates and
/// receive an updated [addressController] text automatically.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    required this.addressController,
    required this.latitude,
    required this.longitude,
    required this.editing,
    required this.onLocationChanged,
    super.key,
    this.addressValidator,
  });

  final TextEditingController addressController;
  final double latitude;
  final double longitude;

  /// When `false` the search field is disabled, the action button hides,
  /// and map taps are ignored. View-mode in the detail page passes false.
  final bool editing;

  /// Fired with the new coordinates whenever the user taps the map or
  /// successfully picks "Use My Current Location". Parent should persist
  /// these (e.g. via setState) — [addressController] is updated in place
  /// by the picker via reverse-geocoding.
  final void Function(double lat, double lng) onLocationChanged;

  /// Optional validator for the search-address field. When provided, the
  /// field is treated as required by the form.
  final String? Function(String?)? addressValidator;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();

  bool _locating = false;

  @override
  void didUpdateWidget(LocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved =
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    if (!moved) return;
    if (!kGoogleMapsEnabled || !_mapController.isCompleted) return;
    _mapController.future.then((controller) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(widget.latitude, widget.longitude),
          16,
        ),
      );
    });
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
      widget.onLocationChanged(position.latitude, position.longitude);
      unawaited(_reverseGeocode(position.latitude, position.longitude));
    } on Exception catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, "Couldn't fetch your location.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onMapTap(LatLng latLng) {
    if (!widget.editing) return;
    widget.onLocationChanged(latLng.latitude, latLng.longitude);
    unawaited(_reverseGeocode(latLng.latitude, latLng.longitude));
  }

  /// Best-effort reverse geocoding. Failures are silent — the user can
  /// still see the lat/lng values and edit the address manually.
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty || !mounted) return;
      final p = placemarks.first;
      final parts = <String?>[
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ].whereType<String>().where((s) => s.isNotEmpty);
      widget.addressController.text = parts.join(', ');
    } on Exception catch (_) {
      // best-effort
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Search-address field — clear-X when there is content to clear.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.addressController,
          builder: (_, value, __) => PrimaryTextField(
            controller: widget.addressController,
            label: 'Search address...',
            prefixIcon: Icons.search,
            textInputAction: TextInputAction.search,
            enabled: widget.editing,
            suffixWidget: value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20.sp,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Clear',
                    onPressed: widget.addressController.clear,
                  )
                : null,
            validator: widget.addressValidator,
          ),
        ),
        if (widget.editing) ...<Widget>[
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
          target: LatLng(widget.latitude, widget.longitude),
          editing: widget.editing,
          onTap: _onMapTap,
          onMapCreated: (controller) {
            if (!_mapController.isCompleted) {
              _mapController.complete(controller);
            }
          },
        ),
        SizedBox(height: 14.h),
        _InfoBanner(
          message: widget.editing
              ? 'Drag & pinch to navigate the map. Tap anywhere to '
                    'pinpoint exact location. Use +/- zoom controls for '
                    'precision.'
              : 'View current location on map. Enable edit mode to '
                    'change location.',
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
        _CoordField(
          label: 'Latitude',
          value: widget.latitude.toStringAsFixed(6),
        ),
        SizedBox(height: 10.h),
        _CoordField(
          label: 'Longitude',
          value: widget.longitude.toStringAsFixed(6),
        ),
      ],
    );
  }
}

// ── Inlined building blocks ──────────────────────────────────────────────

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
        child: kGoogleMapsEnabled
            ? GoogleMap(
                initialCameraPosition: CameraPosition(target: target, zoom: 14),
                markers: <Marker>{
                  Marker(markerId: const MarkerId('pinned'), position: target),
                },
                onTap: editing ? onTap : null,
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
    return DecoratedBox(
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
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, color: AppColors.info, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.info,
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

class _CoordField extends StatelessWidget {
  const _CoordField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        prefixIcon: Icon(
          Icons.explore_outlined,
          color: AppColors.textSecondary,
          size: 20.sp,
        ),
        labelStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13.sp,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15.sp,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
