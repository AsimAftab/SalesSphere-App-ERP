import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:url_launcher/url_launcher.dart';

/// `/attendance/:date` — single-day detail surface reached by tapping a
/// day in the calendar. Renders the status hero, check-in (and
/// optional check-out) cards, and the marked-by card.
class AttendanceDayDetailPage extends ConsumerWidget {
  const AttendanceDayDetailPage({required this.date, super.key});

  /// Midnight-normalized day this detail page is rendering. `null`
  /// when the path's `:date` segment failed to parse; the page renders
  /// a graceful "not found" state in that case.
  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theDate = date;
    if (theDate == null) {
      return const _Scaffold(child: _NotFound());
    }
    final async = ref.watch(attendanceByDateProvider(theDate));

    return _Scaffold(
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _Error(),
        data: (record) => record == null
            ? _NoRecord(date: theDate)
            : _DetailBody(record: record),
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SvgPicture.asset(
                'assets/images/corner_bubble.svg',
                fit: BoxFit.cover,
                height: 180.h,
              ),
            ),
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
                          onPressed: () => context.pop(),
                          tooltip: 'Back',
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Attendance Details',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _StatusHeroCard(record: record),
          SizedBox(height: 16.h),
          if (record.hasCheckIn)
            _CheckEventCard(
              kind: _CheckEventKind.checkIn,
              at: record.checkInAt!,
              lat: record.checkInLat,
              lng: record.checkInLng,
              address: record.checkInAddress,
            ),
          if (record.hasCheckOut) ...<Widget>[
            SizedBox(height: 16.h),
            _CheckEventCard(
              kind: _CheckEventKind.checkOut,
              at: record.checkOutAt!,
              lat: record.checkOutLat,
              lng: record.checkOutLng,
              address: record.checkOutAddress,
            ),
          ],
          if (record.markedByName != null) ...<Widget>[
            SizedBox(height: 16.h),
            _MarkedByCard(
              name: record.markedByName!,
              role: record.markedByRole ?? 'Member',
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final p = record.status.palette;
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: p.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 64.r,
            height: 64.r,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(p.icon, color: Colors.white, size: 36.sp),
          ),
          SizedBox(height: 14.h),
          Text(
            p.label,
            style: TextStyle(
              color: p.accent,
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            DateFormat('EEEE, MMM d, yyyy').format(record.date),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

enum _CheckEventKind { checkIn, checkOut }

class _CheckEventCard extends StatelessWidget {
  const _CheckEventCard({
    required this.kind,
    required this.at,
    required this.lat,
    required this.lng,
    required this.address,
  });

  final _CheckEventKind kind;
  final DateTime at;
  final double? lat;
  final double? lng;
  final String? address;

  bool get _isIn => kind == _CheckEventKind.checkIn;
  String get _heading => _isIn ? 'Check-In' : 'Check-Out';
  IconData get _icon => _isIn ? Icons.login_rounded : Icons.logout_rounded;
  Color get _accent => _isIn ? AppColors.green500 : AppColors.red500;

  Future<void> _openMaps(BuildContext context) async {
    final lt = lat;
    final ln = lng;
    if (lt == null || ln == null) return;
    // Try the geo: scheme first (Android), fall back to the web URL
    // which works everywhere including emulators without a maps app.
    final geo = Uri.parse('geo:$lt,$ln?q=$lt,$ln');
    final web = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lt,$ln');
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
    return SectionCard(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 40.r,
              height: 40.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(_icon, color: _accent, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _heading,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  DateFormat('hh:mm a').format(at),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (address != null || (lat != null && lng != null)) ...<Widget>[
          SizedBox(height: 14.h),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
          SizedBox(height: 14.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.location_on_outlined,
                color: AppColors.textSecondary,
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                '$_heading Location',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (address != null) ...<Widget>[
            SizedBox(height: 6.h),
            Text(
              address!,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
          if (lat != null && lng != null) ...<Widget>[
            SizedBox(height: 10.h),
            Text(
              'Coordinates: ${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}',
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
        ],
      ],
    );
  }
}

class _MarkedByCard extends StatelessWidget {
  const _MarkedByCard({required this.name, required this.role});

  final String name;
  final String role;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.person_outline_rounded,
              color: AppColors.secondary,
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              'Marked By',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        Row(
          children: <Widget>[
            Container(
              width: 44.r,
              height: 44.r,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.greyLight,
                shape: BoxShape.circle,
              ),
              child: Text(
                _initials,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  role,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _NoRecord extends StatelessWidget {
  const _NoRecord({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.event_busy_rounded,
              color: AppColors.textSecondary,
              size: 48.sp,
            ),
            SizedBox(height: 12.h),
            Text(
              'No record for ${DateFormat('MMM d, yyyy').format(date)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              "This day hasn't been logged yet.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          "Couldn't read the date from the URL.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          "Couldn't load this day. Pull back to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}
