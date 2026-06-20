import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_monthly_report.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/odometer_formatting.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/providers/odometer_providers.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

/// Detail view for a day's odometer trips. Reached with a single trip id —
/// the first trip of a day (from the history day card) or a specific trip
/// (from the home carousel). It resolves that trip's calendar day, loads
/// the day's sibling trips, and shows one tab per trip, so a day with
/// several trips reads as a single entry with a tab switcher.
class OdometerTripDetailPage extends ConsumerWidget {
  const OdometerTripDetailPage({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(odometerTripByIdProvider(tripId));

    return tripAsync.when(
      loading: () => const _DetailSkeleton(),
      error: (_, __) => _StatusScaffold(
        child: Text(
          "Couldn't load this trip",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      data: (trip) {
        final day = trip.date;
        if (day == null) {
          // No calendar day → can't resolve siblings; show this trip alone.
          return _DayDetail(dayTrips: <OdometerTrip>[trip], initialId: trip.id);
        }
        // Siblings come from the trip's OWN month (possibly a past month).
        // While that report resolves we already have the trip itself, so we
        // degrade to a single-trip view instead of a blank spinner.
        final report = ref
            .watch(odometerMonthlyReportProvider(day.year, day.month))
            .asData
            ?.value;
        final dayTrips = report == null
            ? <OdometerTrip>[trip]
            : _siblingsFor(trip, report);
        return _DayDetail(dayTrips: dayTrips, initialId: trip.id);
      },
    );
  }
}

/// Day bucket key for a trip — mirrors the history page's grouping
/// (`date ?? startedAt ?? createdAt`, day precision).
DateTime? _dayKey(OdometerTrip t) {
  final raw = t.date ?? t.startedAt ?? t.createdAt;
  return raw == null ? null : DateTime(raw.year, raw.month, raw.day);
}

/// All trips sharing [trip]'s calendar day, sorted by trip number. [trip]
/// is always included even if a stale [report] omits it.
List<OdometerTrip> _siblingsFor(
  OdometerTrip trip,
  OdometerMonthlyReport report,
) {
  final key = _dayKey(trip);
  final list = <OdometerTrip>[
    for (final t in report.records)
      if (_dayKey(t) == key) t,
  ];
  if (!list.any((t) => t.id == trip.id)) list.add(trip);
  list.sort((a, b) => a.tripNumber.compareTo(b.tripNumber));
  return list;
}

/// The decorative corner bubble behind the header — the app-wide page
/// motif. Returned from a function (not a widget) so the [Positioned] stays
/// a direct child of its [Stack].
Widget _cornerBubble() => Positioned(
  top: 0,
  left: 0,
  right: 0,
  child: SvgPicture.asset(
    'assets/images/corner_bubble.svg',
    fit: BoxFit.cover,
    height: 180.h,
  ),
);

/// Back button + title row sitting over the corner bubble.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 20.w, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
              size: 20.sp,
            ),
            onPressed: () => context.pop(),
            tooltip: 'Back',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scaffold shell for the loading / error states, before the day is known.
class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            _cornerBubble(),
            SafeArea(
              child: Column(
                children: <Widget>[
                  const _PageHeader(title: 'Trip Details'),
                  Expanded(child: Center(child: child)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page chrome + shimmer card placeholders shown while the trip loads.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            _cornerBubble(),
            SafeArea(
              child: Column(
                children: <Widget>[
                  const _PageHeader(title: 'Trip Details'),
                  Expanded(
                    child: Skeletonizer(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                        children: <Widget>[
                          const _CardSkeleton(rows: 3),
                          SizedBox(height: 16.h),
                          const _CardSkeleton(rows: 4),
                          SizedBox(height: 16.h),
                          const _CardSkeleton(rows: 4),
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
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Bone(
            width: 120.w,
            height: 14.h,
            borderRadius: BorderRadius.circular(4.r),
          ),
          SizedBox(height: 16.h),
          for (var i = 0; i < rows; i++) ...<Widget>[
            if (i > 0) SizedBox(height: 12.h),
            Row(
              children: <Widget>[
                Bone(
                  width: 110.w,
                  height: 12.h,
                  borderRadius: BorderRadius.circular(4.r),
                ),
                const Spacer(),
                Bone(
                  width: 56.w,
                  height: 12.h,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A day's trips with a per-trip tab switcher. Owns the [TabController],
/// rebuilding it only when the set of trip ids changes (e.g. an external
/// refresh) while preserving the selected tab.
class _DayDetail extends StatefulWidget {
  const _DayDetail({required this.dayTrips, required this.initialId});

  final List<OdometerTrip> dayTrips;

  /// The trip the page was opened on — drives the initial tab.
  final String initialId;

  @override
  State<_DayDetail> createState() => _DayDetailState();
}

class _DayDetailState extends State<_DayDetail>
    with SingleTickerProviderStateMixin {
  TabController? _controller;
  List<String> _ids = const <String>[];

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(_DayDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// (Re)builds the controller only when the trip-id list changes, keeping
  /// the currently-selected trip selected where possible.
  void _syncController() {
    final newIds = widget.dayTrips.map((t) => t.id).toList(growable: false);
    if (_controller != null && listEquals(newIds, _ids)) return;

    int target;
    if (_controller == null) {
      target = newIds.indexOf(widget.initialId);
    } else {
      final i = _controller!.index;
      final currentId = (i >= 0 && i < _ids.length)
          ? _ids[i]
          : widget.initialId;
      target = newIds.indexOf(currentId);
      if (target < 0) target = i.clamp(0, newIds.length - 1);
    }
    if (target < 0) target = 0;

    _controller?.dispose();
    _controller = TabController(
      length: newIds.length,
      vsync: this,
      initialIndex: target.clamp(0, newIds.length - 1),
    );
    _ids = newIds;
  }

  @override
  Widget build(BuildContext context) {
    final trips = widget.dayTrips;
    final controller = _controller!;
    final multi = trips.length > 1;

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            _cornerBubble(),
            SafeArea(
              child: Column(
                children: <Widget>[
                  const _PageHeader(title: 'Trip Details'),
                  if (multi) ...<Widget>[
                    SizedBox(height: 4.h),
                    TabBar(
                      controller: controller,
                      isScrollable: trips.length > 3,
                      tabAlignment: trips.length > 3
                          ? TabAlignment.start
                          : null,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.secondary,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: <Widget>[
                        for (final t in trips)
                          Tab(text: 'Trip ${t.tripNumber}'),
                      ],
                    ),
                  ],
                  Expanded(
                    child: multi
                        ? TabBarView(
                            controller: controller,
                            children: <Widget>[
                              for (final t in trips) _TripDetailBody(trip: t),
                            ],
                          )
                        : _TripDetailBody(trip: trips.first),
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

class _TripDetailBody extends StatelessWidget {
  const _TripDetailBody({required this.trip});

  final OdometerTrip trip;

  @override
  Widget build(BuildContext context) {
    final unit = trip.distanceUnit.label;
    final isActive = trip.isInProgress;

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
      children: <Widget>[
        // ── Readings (start / end / distance) ─────────────────────────
        _ReadingsCard(trip: trip, unit: unit, isActive: isActive),
        SizedBox(height: 16.h),
        // ── Start leg ─────────────────────────────────────────────────
        _LegCard(
          heading: 'Start',
          icon: Icons.play_circle_fill_rounded,
          accent: AppColors.blue500,
          time: trip.startedAt,
          location: trip.startLocation,
          imageUrl: trip.startImageUrl,
          description: trip.startDescription,
        ),
        // ── End leg (completed trips only) ────────────────────────────
        if (!isActive) ...<Widget>[
          SizedBox(height: 16.h),
          _LegCard(
            heading: 'End',
            icon: Icons.flag_circle_rounded,
            accent: AppColors.red500,
            time: trip.stoppedAt,
            location: trip.stopLocation,
            imageUrl: trip.stopImageUrl,
            description: trip.stopDescription,
          ),
        ],
      ],
    );
  }
}

/// Plain-text readings card: start reading, end reading and the distance
/// travelled — so the figures read at a glance, separate from the per-leg
/// details below.
class _ReadingsCard extends StatelessWidget {
  const _ReadingsCard({
    required this.trip,
    required this.unit,
    required this.isActive,
  });

  final OdometerTrip trip;
  final String unit;
  final bool isActive;

  String _value(double? reading) =>
      reading == null ? '—' : '${formatReading(reading)} $unit';

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.speed_rounded, color: AppColors.primary, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              'Readings',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        _InfoRow(label: 'Start reading', value: _value(trip.startReading)),
        SizedBox(height: 12.h),
        _InfoRow(
          label: 'End reading',
          value: isActive ? '—' : _value(trip.stopReading),
        ),
        SizedBox(height: 12.h),
        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
        SizedBox(height: 12.h),
        _InfoRow(
          label: 'Distance travelled',
          value: isActive ? '—' : _value(trip.distance),
          emphasize: true,
        ),
      ],
    );
  }
}

/// One trip leg (Start / End) grouped into a card: time + date, location
/// (with Open in Maps), photo and note.
class _LegCard extends StatelessWidget {
  const _LegCard({
    required this.heading,
    required this.icon,
    required this.accent,
    required this.time,
    required this.location,
    required this.imageUrl,
    required this.description,
  });

  final String heading;
  final IconData icon;
  final Color accent;
  final DateTime? time;
  final TripLocation? location;
  final String? imageUrl;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final loc = location;
    final t = time;

    return SectionCard(
      children: <Widget>[
        // Time + date header.
        Row(
          children: <Widget>[
            Container(
              width: 40.r,
              height: 40.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: accent, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    heading,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    t == null
                        ? '--'
                        : DateFormat('d MMM yyyy · hh:mm a').format(t),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Location (address + coordinates + Open in Maps).
        if (loc != null) ...<Widget>[
          SizedBox(height: 14.h),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
          SizedBox(height: 14.h),
          _LocationBlock(location: loc),
        ],
        // Description — always shown (placeholder when empty) so Start and
        // End cards stay uniform.
        SizedBox(height: 14.h),
        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
        SizedBox(height: 14.h),
        _NoteBlock(text: description),
        // Photo last — preceded by a divider like the other sections.
        if (imageUrl != null) ...<Widget>[
          SizedBox(height: 14.h),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
          SizedBox(height: 14.h),
          _PhotoBlock(url: imageUrl!),
        ],
      ],
    );
  }
}

/// A plain label-on-the-left, value-on-the-right row. [emphasize] makes the
/// row read as the headline figure (the distance).
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 14.sp,
            fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: emphasize ? 16.sp : 14.sp,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// "Start / End Location" — address, coordinates and an Open-in-Maps button.
class _LocationBlock extends StatelessWidget {
  const _LocationBlock({required this.location});

  final TripLocation location;

  Future<void> _openMaps(BuildContext context) async {
    final lat = location.latitude;
    final lng = location.longitude;
    // Prefer the geo: scheme (Android), fall back to the web URL which
    // works everywhere — including emulators without a maps app.
    final geo = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final web = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      if (await canLaunchUrl(geo)) {
        await launchUrl(geo);
        return;
      }
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } on Exception catch (_) {
      if (!context.mounted) return;
      SnackbarUtils.showError(context, "Couldn't open Maps.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = location.address;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.location_on_outlined,
              color: AppColors.textSecondary,
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              'Location',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (address != null && address.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: 6.h),
          Text(
            address,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
        SizedBox(height: 10.h),
        Text(
          'Coordinates: ${location.latitude.toStringAsFixed(6)}, '
          '${location.longitude.toStringAsFixed(6)}',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: 14.h),
        OutlinedCustomButton(
          label: 'Open in Maps',
          leadingIcon: Icons.map_outlined,
          onPressed: () => _openMaps(context),
        ),
      ],
    );
  }
}

/// A captioned trip note.
class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final note = text?.trim() ?? '';
    final hasNote = note.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.sticky_note_2_outlined,
              color: AppColors.textSecondary,
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              'Description',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          hasNote ? note : 'No description added',
          style: TextStyle(
            color: hasNote ? AppColors.textSecondary : AppColors.textHint,
            fontSize: 14.sp,
            fontStyle: hasNote ? FontStyle.normal : FontStyle.italic,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// A captioned trip photo.
class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.image_outlined,
              color: AppColors.textSecondary,
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              'Photo',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        _ZoomableImage(url: url),
      ],
    );
  }
}

class _ZoomableImage extends StatelessWidget {
  const _ZoomableImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showViewer(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.r),
        child: CachedNetworkImage(
          imageUrl: url,
          height: 180.h,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            height: 180.h,
            color: AppColors.background,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 180.h,
            color: AppColors.background,
            child: Center(
              child: Icon(
                Icons.broken_image_rounded,
                color: AppColors.textHint,
                size: 28.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showViewer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(12.w),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
