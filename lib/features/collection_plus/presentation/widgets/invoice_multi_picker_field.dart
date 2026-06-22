import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/invoice_due.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_allocator.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
final _dateFmt = DateFormat('dd MMM yyyy');

/// Field-shaped tappable that opens a multi-select bottom sheet of the
/// party's outstanding invoices. The user ticks the bill(s) the payment
/// settles — one for a single invoice, more when the amount overflows
/// beyond it. Invoices are listed oldest-first; each card shows the total,
/// what's already been collected (and when), and what's left.
///
/// Carries no `validator`; the add page guards on an empty selection.
class InvoiceMultiPickerField extends StatefulWidget {
  const InvoiceMultiPickerField({
    required this.dues,
    required this.selectedIds,
    required this.onChanged,
    this.targetAmount = 0,
    this.enabled = true,
    super.key,
  });

  final List<InvoiceDue> dues;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  /// The amount the user has entered, if any — shown in the sheet so they
  /// can tick exactly enough bills to cover it in one pass.
  final double targetAmount;
  final bool enabled;

  @override
  State<InvoiceMultiPickerField> createState() =>
      _InvoiceMultiPickerFieldState();
}

class _InvoiceMultiPickerFieldState extends State<InvoiceMultiPickerField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = _summary;
  }

  @override
  void didUpdateWidget(InvoiceMultiPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _summary;
    if (_controller.text != next) _controller.text = next;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _summary {
    if (widget.selectedIds.isEmpty) return '';
    final selected = widget.dues
        .where((d) => widget.selectedIds.contains(d.invoice.id))
        .toList(growable: false);
    if (selected.length == 1) return selected.first.invoice.number;
    return '${selected.length} invoices selected';
  }

  Future<void> _open() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvoiceMultiPickerSheet(
        dues: widget.dues,
        initial: widget.selectedIds,
        targetAmount: widget.targetAmount,
      ),
    );
    if (!mounted || result == null) return;
    widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    // A read-only text field is the shared "tap to pick" surface used by
    // every other picker on the form, so this reads identically.
    return PrimaryTextField(
      controller: _controller,
      label: 'Invoice(s)',
      hintText: 'Select the invoice(s) being settled',
      prefixIcon: Icons.receipt_long_outlined,
      enabled: widget.enabled,
      readOnly: true,
      onTap: _open,
      suffixWidget: widget.enabled
          ? Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textSecondary,
                size: 20.sp,
              ),
            )
          : null,
    );
  }
}

class _InvoiceMultiPickerSheet extends StatefulWidget {
  const _InvoiceMultiPickerSheet({
    required this.dues,
    required this.initial,
    required this.targetAmount,
  });

  final List<InvoiceDue> dues;
  final Set<String> initial;
  final double targetAmount;

  @override
  State<_InvoiceMultiPickerSheet> createState() =>
      _InvoiceMultiPickerSheetState();
}

class _InvoiceMultiPickerSheetState extends State<_InvoiceMultiPickerSheet> {
  late final Set<String> _selected = <String>{...widget.initial};

  void _toggle(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasTarget = widget.targetAmount > 0.0001;
    // Selected invoices in the dues' oldest-first order, and the FIFO
    // slice the target amount applies to each — so the user sees, per
    // card, how much of their payment lands where as they tick bills.
    final selectedOrdered = widget.dues
        .where((d) => _selected.contains(d.invoice.id))
        .toList(growable: false);
    final appliedById = <String, double>{
      for (final a in PaymentAllocator.allocate(widget.targetAmount, selectedOrdered))
        a.invoiceId: a.amount,
    };
    final selectedOutstanding =
        PaymentAllocator.totalOutstanding(selectedOrdered);
    final covered = selectedOutstanding < widget.targetAmount
        ? selectedOutstanding
        : widget.targetAmount;
    final fullyCovered = covered >= widget.targetAmount - 0.0001;

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(0, 12.h, 0, 0),
        child: Column(
          children: <Widget>[
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Select invoice(s)',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Oldest first',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
            if (hasTarget) ...<Widget>[
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  'Tick invoices to cover ${_currency.format(widget.targetAmount)}.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ],
            SizedBox(height: 12.h),
            Expanded(
              child: widget.dues.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Text(
                          'No outstanding invoices for this party.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
                      itemCount: widget.dues.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.h),
                      itemBuilder: (context, i) {
                        final due = widget.dues[i];
                        return _InvoiceOptionCard(
                          due: due,
                          selected: _selected.contains(due.invoice.id),
                          applied: appliedById[due.invoice.id] ?? 0,
                          onTap: () => _toggle(due.invoice.id),
                        );
                      },
                    ),
            ),
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 12.h),
              child: Column(
                children: <Widget>[
                  if (hasTarget) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          fullyCovered
                              ? Icons.check_circle
                              : Icons.error_outline,
                          size: 16.sp,
                          color: fullyCovered
                              ? Colors.green.shade700
                              : AppColors.error,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            fullyCovered
                                ? 'Covered ${_currency.format(widget.targetAmount)}'
                                : 'Covered ${_currency.format(covered)} of '
                                    '${_currency.format(widget.targetAmount)}',
                            style: TextStyle(
                              color: fullyCovered
                                  ? Colors.green.shade700
                                  : AppColors.error,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                  ],
                  PrimaryButton(
                    label: _selected.isEmpty
                        ? 'Done'
                        : 'Done · ${_selected.length} selected',
                    onPressed: () =>
                        Navigator.of(context).pop<Set<String>>(_selected),
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

class _InvoiceOptionCard extends StatelessWidget {
  const _InvoiceOptionCard({
    required this.due,
    required this.selected,
    required this.applied,
    required this.onTap,
  });

  final InvoiceDue due;
  final bool selected;

  /// Slice of the entered amount this invoice would absorb (FIFO), shown
  /// when the card is selected and an amount has been entered.
  final double applied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPaid = due.paid > 0.0001;
    final hasApplied = applied > 0.0001;
    final settles = applied >= due.outstanding - 0.0001;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.secondary.withValues(alpha: 0.06)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: selected ? AppColors.secondary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: selected ? AppColors.secondary : AppColors.textSecondary,
                size: 22.sp,
              ),
              SizedBox(width: 12.w),
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
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
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
                    SizedBox(height: 6.h),
                    Text(
                      'Total ${_currency.format(due.invoice.amount)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                    if (hasPaid) ...<Widget>[
                      SizedBox(height: 2.h),
                      Text(
                        due.lastPaidOn == null
                            ? 'Paid ${_currency.format(due.paid)}'
                            : 'Paid ${_currency.format(due.paid)} · '
                                'last on ${_dateFmt.format(due.lastPaidOn!)}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                    SizedBox(height: 2.h),
                    Text(
                      'Outstanding ${_currency.format(due.outstanding)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasApplied) ...<Widget>[
                      SizedBox(height: 4.h),
                      Text(
                        settles
                            ? 'Applies ${_currency.format(applied)} · settles'
                            : 'Applies ${_currency.format(applied)} · partial',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
