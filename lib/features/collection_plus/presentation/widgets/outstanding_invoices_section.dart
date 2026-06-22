import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/invoice_due.dart';

final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
final _dateFmt = DateFormat('dd MMM yyyy');

/// Polished summary of the invoices the user selected, with a live preview
/// of how the entered amount settles them (FIFO, oldest-first).
///
/// [allocatedById] maps an invoice id to the slice of the current amount
/// applied to it (empty when no/zero amount is entered). [unallocated] is
/// the part of the amount the selection doesn't yet cover — when positive
/// a "tick another bill" prompt is shown. When [dues] is empty this
/// renders the "nothing outstanding" notice instead.
class OutstandingInvoicesSection extends StatelessWidget {
  const OutstandingInvoicesSection({
    required this.dues,
    required this.allocatedById,
    required this.totalOutstanding,
    this.unallocated = 0,
    super.key,
  });

  final List<InvoiceDue> dues;
  final Map<String, double> allocatedById;
  final double totalOutstanding;
  final double unallocated;

  @override
  Widget build(BuildContext context) {
    if (dues.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.check_circle_outline,
              size: 18.sp,
              color: AppColors.textSecondary,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'No outstanding invoices for this party.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final applied = allocatedById.values.fold<double>(0, (s, v) => s + v);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header.
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
            child: Row(
              children: <Widget>[
                Container(
                  width: 30.r,
                  height: 30.r,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9.r),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 17.sp,
                    color: AppColors.secondary,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Selected Invoices',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Oldest invoice settled first',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  dues.length == 1 ? '1 invoice' : '${dues.length} invoices',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
          // Invoice rows.
          for (var i = 0; i < dues.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, color: AppColors.border.withValues(alpha: 0.4)),
            _AllocationRow(
              due: dues[i],
              allocated: allocatedById[dues[i].invoice.id] ?? 0,
            ),
          ],
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
          // Footer: either the "more needed" prompt or the applied total.
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 12.h),
            child: unallocated > 0.0001
                ? _FooterPrompt(unallocated: unallocated)
                : _FooterTotal(applied: applied, due: totalOutstanding),
          ),
        ],
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({required this.due, required this.allocated});

  final InvoiceDue due;
  final double allocated;

  @override
  Widget build(BuildContext context) {
    final hasAllocation = allocated > 0.0001;
    final settles = allocated >= due.outstanding - 0.0001;
    final color = settles ? Colors.green.shade700 : AppColors.secondary;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        due.invoice.number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      _dateFmt.format(due.invoice.invoiceDate),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  'Outstanding ${_currency.format(due.outstanding)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          if (hasAllocation)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _currency.format(allocated),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  settles ? 'Settles' : 'Partial',
                  style: TextStyle(
                    color: color,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Text(
              'Not applied',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 11.sp,
              ),
            ),
        ],
      ),
    );
  }
}

class _FooterTotal extends StatelessWidget {
  const _FooterTotal({required this.applied, required this.due});

  final double applied;
  final double due;

  @override
  Widget build(BuildContext context) {
    final label = applied > 0.0001 ? 'Total amount' : 'Total due';
    final value = applied > 0.0001 ? applied : due;
    return Row(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          _currency.format(value),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FooterPrompt extends StatelessWidget {
  const _FooterPrompt({required this.unallocated});

  final double unallocated;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(Icons.error_outline, size: 16.sp, color: AppColors.error),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            '${_currency.format(unallocated)} not yet allocated — select '
            'another invoice to cover it.',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
