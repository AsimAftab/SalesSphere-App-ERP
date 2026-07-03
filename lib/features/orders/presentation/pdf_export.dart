import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sales_sphere_erp/core/services/downloads_saver.dart';
import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/presentation/controllers/order_controller.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';

/// Shared "Download PDF" flow used by both the order-history cards and the
/// order detail page. Renders [order] to a PDF, saves it into the device's
/// Downloads folder (Play-compliant MediaStore write), then surfaces the
/// result: a success snackbar with an "Open" action, or an actionable error.
Future<void> downloadOrderPdf(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  // Resolve the messenger up front and drive every message through it. The
  // export awaits a network + render round-trip, during which the widget
  // that started it (a history row) may scroll off or rebuild — a
  // `context`-based snackbar (or a `context.mounted` guard) would then be
  // dropped silently. The ScaffoldMessengerState outlives the row.
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(orderControllerProvider.notifier);
  SnackbarUtils.showInfoOn(
    messenger,
    'Preparing ${order.number}.pdf…',
    duration: const Duration(seconds: 20),
  );

  final String path;
  try {
    path = await controller.downloadPdf(order);
  } on DownloadsPermissionException {
    SnackbarUtils.showErrorWithActionOn(
      messenger,
      'Allow storage access to save the PDF.',
      actionLabel: 'Settings',
      onAction: () => unawaited(openAppSettings()),
    );
    return;
  } on Object {
    SnackbarUtils.showErrorOn(messenger, "Couldn't save ${order.number}.pdf.");
    return;
  }

  SnackbarUtils.showSuccessWithActionOn(
    messenger,
    'Saved to Downloads · ${order.number}.pdf',
    actionLabel: 'Open',
    onAction: () => unawaited(_openSaved(messenger, path)),
  );
}

Future<void> _openSaved(ScaffoldMessengerState messenger, String path) async {
  final result = await OpenFilex.open(path);
  if (result.type == ResultType.done) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      const SnackBar(
        content: Text('No app found to open the PDF. Check Downloads.'),
      ),
    );
}
