import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:sales_sphere_erp/core/config/env.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/services/google_places_service.dart';
import 'package:sales_sphere_erp/core/services/location_service.dart';
import 'package:sales_sphere_erp/core/utils/reverse_geocode.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// True when the active flavor's `env/<flavor>.json` carries a
/// `GOOGLE_MAPS_ANDROID_KEY`. Gradle plumbs the same value into the
/// AndroidManifest's `com.google.android.geo.API_KEY` meta-data, so the
/// Dart-side flag and the native SDK key go live together. When empty,
/// LocationPicker renders a placeholder rather than crashing the SDK.
bool get _googleMapsEnabled => Env.current.googleMapsAndroidKey.isNotEmpty;

/// True when a `GOOGLE_PLACES_API_KEY` is configured. When false, the
/// autocomplete dropdown never renders — the search field still works
/// as a plain text input. Mirrors the [_googleMapsEnabled] kill-switch.
bool get _googlePlacesEnabled => Env.current.googlePlacesApiKey.isNotEmpty;

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
class LocationPicker extends ConsumerStatefulWidget {
  const LocationPicker({
    required this.addressController,
    required this.latitude,
    required this.longitude,
    required this.editing,
    required this.onLocationChanged,
    super.key,
    this.addressValidator,
    this.showFullAddressCard = true,
  });

  final TextEditingController addressController;
  final double latitude;
  final double longitude;

  /// When `false` the search field is disabled, the action button hides,
  /// and map taps are ignored. View-mode in the detail page passes false.
  final bool editing;

  /// Toggles the green "Full Address" callout below the search field.
  /// Add-pages use it as confirmation that the picked location resolved
  /// to a real address; detail pages already show the address in their
  /// own header card so they pass false to avoid duplication.
  final bool showFullAddressCard;

  /// Fired with the new coordinates whenever the user taps the map or
  /// successfully picks "Use My Current Location". Parent should persist
  /// these (e.g. via setState) — [addressController] is updated in place
  /// by the picker via reverse-geocoding.
  final void Function(double lat, double lng) onLocationChanged;

  /// Optional validator for the search-address field. When provided, the
  /// field is treated as required by the form.
  final String? Function(String?)? addressValidator;

  @override
  ConsumerState<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<LocationPicker> {
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();

  bool _locating = false;

  // Autocomplete state.
  Timer? _debounce;
  List<PlacePrediction> _predictions = const <PlacePrediction>[];
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(LocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved =
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    if (!moved) return;
    if (!_googleMapsEnabled || !_mapController.isCompleted) return;
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
      final locationService = ref.read(locationServiceProvider);
      final permission = await locationService.ensurePermission();
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        // Permanent denial — re-requesting won't show the prompt again,
        // so route the user straight to the system settings screen.
        SnackbarUtils.showErrorWithAction(
          context,
          'Location permission permanently denied. Open Settings to grant access.',
          actionLabel: 'Settings',
          onAction: locationService.openAppSettings,
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        SnackbarUtils.showError(context, 'Location permission denied.');
        return;
      }
      final position = await locationService.getCurrentLocation();
      if (position == null) {
        if (!mounted) return;
        SnackbarUtils.showError(context, "Couldn't fetch your location.");
        return;
      }
      widget.onLocationChanged(position.latitude, position.longitude);
      unawaited(_reverseGeocode(position.latitude, position.longitude));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onMapTap(LatLng latLng) {
    if (!widget.editing) return;
    _commitPin(latLng);
  }

  void _onMarkerDragEnd(LatLng latLng) {
    if (!widget.editing) return;
    _commitPin(latLng);
  }

  void _commitPin(LatLng latLng) {
    widget.onLocationChanged(latLng.latitude, latLng.longitude);
    unawaited(_reverseGeocode(latLng.latitude, latLng.longitude));
  }

  /// Best-effort reverse geocoding. Failures are silent — the user can
  /// still see the lat/lng values and edit the address manually.
  Future<void> _reverseGeocode(double lat, double lng) async {
    final address = await reverseGeocodeAddress(lat, lng);
    if (!mounted || address == null) return;
    widget.addressController.text = address;
  }

  void _onSearchChanged(String value) {
    if (!_googlePlacesEnabled || !widget.editing) return;
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      if (_predictions.isNotEmpty) {
        setState(() => _predictions = const <PlacePrediction>[]);
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_runAutocomplete(trimmed));
    });
  }

  Future<void> _runAutocomplete(String query) async {
    if (!mounted || _lastQuery == query) return;
    _lastQuery = query;
    final places = ref.read(googlePlacesServiceProvider);
    final results = await places.getAutocompletePredictions(
      query,
      bias: LatLng(widget.latitude, widget.longitude),
    );
    if (!mounted || _lastQuery != query) return;
    setState(() => _predictions = results);
  }

  Future<void> _onPredictionTap(PlacePrediction prediction) async {
    // Hide the dropdown immediately so the user gets feedback while we
    // fetch details — no jank if Places latency is high.
    setState(() {
      _predictions = const <PlacePrediction>[];
      _lastQuery = prediction.mainText;
    });
    final places = ref.read(googlePlacesServiceProvider);
    final details = await places.getPlaceDetails(prediction.placeId);
    if (!mounted) return;
    if (details == null) {
      SnackbarUtils.showError(context, "Couldn't fetch place details.");
      return;
    }
    widget.addressController.text = details.formattedAddress.isNotEmpty
        ? details.formattedAddress
        : details.name;
    widget.onLocationChanged(
      details.location.latitude,
      details.location.longitude,
    );
    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(details.location, 17),
      );
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
            onChanged: _onSearchChanged,
            suffixWidget: value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20.sp,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Clear',
                    onPressed: () {
                      widget.addressController.clear();
                      _debounce?.cancel();
                      setState(() {
                        _predictions = const <PlacePrediction>[];
                        _lastQuery = '';
                      });
                    },
                  )
                : null,
            validator: widget.addressValidator,
          ),
        ),
        if (_predictions.isNotEmpty) ...<Widget>[
          SizedBox(height: 8.h),
          _PredictionList(
            predictions: _predictions,
            onTap: _onPredictionTap,
          ),
        ],
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
          onDragEnd: _onMarkerDragEnd,
          onMapCreated: (controller) {
            if (!_mapController.isCompleted) {
              _mapController.complete(controller);
            }
          },
        ),
        SizedBox(height: 14.h),
        // Reflects whatever the search field / map tap / current-location
        // fetch has resolved into the address controller. Hidden until a
        // location actually exists so we never show an empty card. Detail
        // pages opt out via `showFullAddressCard: false` to avoid
        // duplicating the address that's already in their header card.
        if (widget.showFullAddressCard)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.addressController,
            builder: (_, value, __) {
              if (value.text.trim().isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(bottom: 14.h),
                child: _FullAddressCard(address: value.text),
              );
            },
          ),
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
    required this.onDragEnd,
    required this.onMapCreated,
  });

  final LatLng target;
  final bool editing;
  final ValueChanged<LatLng> onTap;
  final ValueChanged<LatLng> onDragEnd;
  final void Function(GoogleMapController) onMapCreated;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: SizedBox(
        height: 300.h,
        child: _googleMapsEnabled
            ? GoogleMap(
                initialCameraPosition: CameraPosition(target: target, zoom: 14),
                markers: <Marker>{
                  Marker(
                    markerId: const MarkerId('pinned'),
                    position: target,
                    draggable: editing,
                    onDragEnd: editing ? onDragEnd : null,
                  ),
                },
                onTap: editing ? onTap : null,
                onMapCreated: onMapCreated,
                myLocationEnabled: editing,
                myLocationButtonEnabled: false,
                minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
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

// Darker shades used by the location picker's status cards. Pulled out
// so the green/blue tints stay consistent across the address card and
// info banner without scattering hex literals.
const Color _kSuccessDark = Color(0xFF1B5E20); // Material green 900
const Color _kInfoDark = Color(0xFF0D47A1); // Material blue 900

class _FullAddressCard extends StatelessWidget {
  const _FullAddressCard({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.location_on, color: _kSuccessDark, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Full Address',
                style: TextStyle(
                  color: _kSuccessDark,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            address,
            style: TextStyle(
              color: _kSuccessDark,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
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
        color: AppColors.info.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, color: _kInfoDark, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: _kInfoDark,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionList extends StatelessWidget {
  const _PredictionList({required this.predictions, required this.onTap});

  final List<PlacePrediction> predictions;
  final ValueChanged<PlacePrediction> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(12.r),
      shadowColor: AppColors.shadow,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 220.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: predictions.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.3),
            ),
            itemBuilder: (_, index) {
              final p = predictions[index];
              return ListTile(
                dense: true,
                leading: Icon(
                  Icons.place_outlined,
                  size: 20.sp,
                  color: AppColors.primary,
                ),
                title: Text(
                  p.mainText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: p.secondaryText.isEmpty
                    ? null
                    : Text(
                        p.secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                          fontFamily: 'Poppins',
                        ),
                      ),
                onTap: () => onTap(p),
              );
            },
          ),
        ),
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
          color: AppColors.textSecondary.withValues(alpha: 0.4),
          size: 20.sp,
        ),
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14.sp,
          fontFamily: 'Poppins',
        ),
        floatingLabelStyle: TextStyle(
          color: AppColors.textSecondary,
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
          color: AppColors.textSecondary.withValues(alpha: 0.6),
          fontSize: 15.sp,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
