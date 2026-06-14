import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:sales_sphere_erp/features/tracking/service/tracking_ipc.dart';

/// The ongoing foreground-service notification is owned here via
/// `flutter_local_notifications` (the background-service plugin can only render
/// a plain title+text). We re-`show()` the SAME id the plugin uses for its
/// foreground notification (`foregroundServiceNotificationId`, default 112233)
/// so updates replace it in place and the service stays foreground.
const String kTrackingChannelId = 'salessphere_tracking';
const String kTrackingChannelName = 'Live tracking';
const String kTrackingChannelDescription =
    'Keeps your beat-plan location updates streaming while you work.';

/// MUST equal `AndroidConfiguration.foregroundServiceNotificationId`.
const int kTrackingNotificationId = 112233;

/// Create the channel (idempotent) — must exist before `configure()` since the
/// service plugin references the channel id.
Future<void> createTrackingChannel(
  FlutterLocalNotificationsPlugin plugin,
) async {
  const channel = AndroidNotificationChannel(
    kTrackingChannelId,
    kTrackingChannelName,
    description: kTrackingChannelDescription,
    importance: Importance.low, // persistent but silent (no heads-up/sound)
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

/// Initialise the plugin in the current isolate (called in both the UI and the
/// service isolate — each has its own plugin instance). [onForegroundTap]
/// handles taps while the app is alive (deep-link to the plan); action-button
/// taps are always routed to [trackingNotificationTapBackground].
Future<void> initTrackingNotifications(
  FlutterLocalNotificationsPlugin plugin, {
  DidReceiveNotificationResponseCallback? onForegroundTap,
}) async {
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await plugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: onForegroundTap,
    onDidReceiveBackgroundNotificationResponse:
        trackingNotificationTapBackground,
  );
  await createTrackingChannel(plugin);
}

/// Build + show (or update) the ongoing tracking notification.
Future<void> showTrackingNotification(
  FlutterLocalNotificationsPlugin plugin, {
  required String beatPlanId,
  required String title,
  required String body,
  required bool paused,
  required int whenEpochMs,
  int? maxProgress,
  int? progress,
}) async {
  final showProgress = maxProgress != null && maxProgress > 0;

  // No action buttons: tracking is system-controlled — a rep can't pause or
  // stop it. It ends only when the plan completes / is force-completed /
  // attendance checkout / stale-timeout (all server-driven).
  final details = AndroidNotificationDetails(
    kTrackingChannelId,
    kTrackingChannelName,
    channelDescription: kTrackingChannelDescription,
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    onlyAlertOnce: true,
    playSound: false,
    enableVibration: false,
    category: AndroidNotificationCategory.service,
    visibility: NotificationVisibility.public,
    showProgress: showProgress,
    maxProgress: maxProgress ?? 0,
    progress: progress ?? 0,
    usesChronometer: !paused,
    when: whenEpochMs,
    styleInformation: BigTextStyleInformation(body),
  );

  await plugin.show(
    kTrackingNotificationId,
    title,
    body,
    NotificationDetails(android: details),
    payload: 'beat-plans/$beatPlanId',
  );
}

Future<void> cancelTrackingNotification(
  FlutterLocalNotificationsPlugin plugin,
) =>
    plugin.cancel(kTrackingNotificationId);

/// Runs in `flutter_local_notifications`' dedicated background isolate when a
/// notification ACTION button is tapped. It can't touch the service isolate's
/// Dart objects directly, so it bridges through the plugin's native channel:
/// `FlutterBackgroundService().invoke('action', {id})` is delivered to the
/// running service's `on('action')` listener.
@pragma('vm:entry-point')
void trackingNotificationTapBackground(NotificationResponse response) {
  final actionId = response.actionId;
  if (actionId == null || actionId.isEmpty) return;
  DartPluginRegistrant.ensureInitialized();
  FlutterBackgroundService()
      .invoke(TrackingIpc.cmdAction, <String, dynamic>{
    TrackingIpc.kActionId: actionId,
  });
}
