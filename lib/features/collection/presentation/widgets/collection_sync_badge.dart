import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Whether a collection has made it to the server yet — and, if not, why.
///
/// Deliberately separate from the `DRAFT / POSTED / CANCELLED` status badge.
/// Those are two orthogonal axes and conflating them is the easiest mistake to
/// make here: a DRAFT receipt is perfectly healthy (it just hasn't been posted
/// to the ledger, and in a CRM-only org it never will be), whereas a red sync
/// badge means the server actually refused the row.
///
/// Three states:
///
///  * **nothing** — synced. The common case; renders no chrome at all.
///  * **orange `cloud_off`** — queued in the outbox, waiting for a connection.
///    Normal in the field.
///  * **red `error_outline`** — the sync drain gave up. [syncError] carries the
///    server's own copy, which the rep needs to read: typically
///    "Selected invoices cover only Rs X. Select more to cover Rs Y."
///    — i.e. someone else collected against that invoice first, and this
///    receipt no longer fits. Long-press to read it in full.
class CollectionSyncBadge extends StatelessWidget {
  const CollectionSyncBadge({
    required this.syncPending,
    required this.syncError,
    super.key,
  });

  final bool syncPending;
  final String? syncError;

  @override
  Widget build(BuildContext context) {
    if (!syncPending && syncError == null) return const SizedBox.shrink();

    final failed = syncError != null;
    final color = failed ? AppColors.error : AppColors.warning;
    final icon = failed ? Icons.error_outline : Icons.cloud_off;
    final label = failed ? 'Rejected' : 'Pending sync';

    return Tooltip(
      message: syncError ?? 'Waiting for a connection to sync this receipt.',
      triggerMode: TooltipTriggerMode.longPress,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
