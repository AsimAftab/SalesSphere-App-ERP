import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/invoice_due.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_allocator.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/repositories/collection_plus_repository.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/controllers/collection_controller.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/providers/collection_providers.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/widgets/bank_name_field.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/widgets/cheque_status_field.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/widgets/collection_party_picker_field.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/widgets/invoice_multi_picker_field.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/widgets/outstanding_invoices_section.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/widgets/payment_mode_field.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/add_form_header.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class AddCollectionPlusPage extends ConsumerStatefulWidget {
  const AddCollectionPlusPage({super.key});

  @override
  ConsumerState<AddCollectionPlusPage> createState() => _AddCollectionPlusPageState();
}

class _AddCollectionPlusPageState extends ConsumerState<AddCollectionPlusPage> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _receivedDateController = TextEditingController();
  final _chequeNumberController = TextEditingController();
  final _chequeDateController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const _maxImages = 2;

  CollectionPlusParty? _party;

  /// Ids of the invoices the user ticked in the picker. The payment is
  /// FIFO-split across these (oldest-first); the user adds another when
  /// the amount overflows beyond the ones already chosen.
  final Set<String> _selectedInvoiceIds = <String>{};

  DateTime? _receivedDate;
  PaymentMode? _paymentMode;
  String? _bankName;
  DateTime? _chequeDate;
  ChequeStatus? _chequeStatus;
  final List<String> _imagePaths = <String>[];
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _receivedDateController.dispose();
    _chequeNumberController.dispose();
    _chequeDateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Picking a (different) party changes which invoices the payment can
  /// settle, so clear the invoice selection and amount — both only make
  /// sense against the previously chosen party.
  void _onPartyPicked(CollectionPlusParty? party) {
    setState(() {
      _party = party;
      _selectedInvoiceIds.clear();
      _amountController.clear();
    });
  }

  /// The user changed the ticked invoices in the picker.
  void _onInvoicesChanged(Set<String> ids) {
    setState(() {
      _selectedInvoiceIds
        ..clear()
        ..addAll(ids);
    });
  }

  /// When the payment mode changes, drop any conditional state that the
  /// new mode no longer needs so a stale bank / cheque value can't be
  /// submitted (e.g. switching Cheque → Cash).
  void _onPaymentModeChanged(PaymentMode? next) {
    setState(() {
      _paymentMode = next;
      if (next == null || !next.requiresBank) {
        _bankName = null;
      }
      if (next == null || !next.requiresChequeDetails) {
        _chequeNumberController.clear();
        _chequeDateController.clear();
        _chequeDate = null;
        _chequeStatus = null;
      }
    });
  }

  Future<void> _pickImage() async {
    if (_imagePaths.length >= _maxImages) return;
    try {
      final file = await showImagePickerSheet(
        context,
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

  /// Amount validator: required, a number > 0, and never more than the
  /// party's total outstanding (overpayment is blocked). Whether the
  /// *selected* invoices cover the amount is enforced separately on submit
  /// — that's a "tick another bill" nudge, not a hard amount error.
  String? _validateAmount(String? value, double totalOutstanding) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Amount is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than 0';
    if (parsed > totalOutstanding + 0.0001) {
      return 'Exceeds total outstanding of '
          '${_currency.format(totalOutstanding)}';
    }
    return null;
  }

  Future<void> _submit(List<InvoiceDue> selectedDues) async {
    final party = _party;
    if (party == null) {
      SnackbarUtils.showError(context, 'Please select a party.');
      return;
    }
    if (selectedDues.isEmpty) {
      SnackbarUtils.showError(context, 'Please select at least one invoice.');
      return;
    }

    final formValid = _formKey.currentState?.validate() ?? false;
    final mode = _paymentMode;
    final receivedDate = _receivedDate;

    // The payment-mode picker has no Form validator, so its required-ness
    // is enforced here. Surface a snackbar rather than silently no-op.
    if (mode == null) {
      SnackbarUtils.showError(context, 'Please choose a payment mode.');
      return;
    }
    if (mode.requiresBank && (_bankName == null || _bankName!.isEmpty)) {
      SnackbarUtils.showError(context, 'Please select a bank.');
      return;
    }
    if (mode.requiresChequeDetails) {
      if (_chequeDate == null) {
        SnackbarUtils.showError(context, 'Please select the cheque date.');
        return;
      }
      if (_chequeStatus == null) {
        SnackbarUtils.showError(context, 'Please choose a cheque status.');
        return;
      }
    }
    if (!formValid || receivedDate == null) return;

    final amount = double.parse(_amountController.text.trim());
    // The selected invoices must cover the whole amount; otherwise part of
    // the payment would have nowhere to land — nudge to tick another bill.
    final selectedOutstanding = PaymentAllocator.totalOutstanding(selectedDues);
    if (amount > selectedOutstanding + 0.0001) {
      SnackbarUtils.showError(
        context,
        'Selected invoices cover only ${_currency.format(selectedOutstanding)}. '
        'Select more to cover ${_currency.format(amount)}.',
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      // Send the **selection, not the split**. The FIFO preview above is a
      // courtesy for the user; the server re-runs the same algorithm against
      // live balances and returns the allocation it actually booked. Sending a
      // client-computed split would be asking it to trust arithmetic done
      // against a balance that may already be stale — which, offline, it
      // almost certainly is.
      final created = await ref
          .read(collectionPlusControllerProvider.notifier)
          .addCollection(
            invoiceIds: selectedDues
                .map((d) => d.invoice.id)
                .toList(growable: false),
            party: party,
            amount: amount,
            receivedDate: receivedDate,
            paymentMode: mode,
            bankName: mode.requiresBank ? _bankName : null,
            chequeNumber: mode.requiresChequeDetails
                ? _chequeNumberController.text.trim()
                : null,
            chequeDate: mode.requiresChequeDetails ? _chequeDate : null,
            chequeStatus: mode.requiresChequeDetails ? _chequeStatus : null,
            description: _descriptionController.text.trim(),
            imagePaths: List<String>.unmodifiable(_imagePaths),
          );
      if (!mounted) return;
      SnackbarUtils.showSuccess(
        context,
        created.syncPending
            ? 'Collection saved offline. It will sync when you reconnect.'
            : 'Collection recorded.',
      );
      context.pop();
    } on PartialImageUploadException catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(
        context,
        'Collection saved, but the payment proof failed to upload: '
        '${e.firstMessage}',
      );
      context.pop();
    } on ApiException catch (e) {
      // The message that matters here is the server's coverage-short 422:
      // "Selected invoices cover only Rs X. Select more to cover Rs Y." It
      // means another rep settled that invoice first, and the rep needs to
      // read it — a generic "Could not save" would leave them re-trying
      // forever.
      if (!mounted) return;
      SnackbarUtils.showError(context, e.message);
    } on Exception catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = _paymentMode;
    final showBank = mode?.requiresBank ?? false;
    final showCheque = mode?.requiresChequeDetails ?? false;

    final party = _party;
    // Read from the server — never derived on-device. An empty list means the
    // party has nothing POSTED to settle yet (a rep's order stays DRAFT until
    // the web app posts it), which is a normal state, not a bug.
    final dues = party == null
        ? const <InvoiceDue>[]
        : ref
                  .watch(
                    outstandingInvoicesForPartyProvider(
                      party.id,
                      // Cap the pool to what was due on the picked Received
                      // Date: a backdated receipt must not be offered invoices
                      // issued later, nor have its balances erased by payments
                      // taken later. Null (date not yet picked) reads as today.
                      asOfDate: _receivedDate,
                    ),
                  )
                  .value ??
              const <InvoiceDue>[];
    // Party-level cap: a collection can never exceed everything the party
    // owes. The selected invoices must then *cover* the entered amount.
    final totalOutstanding = PaymentAllocator.totalOutstanding(dues);

    // Selected invoices, kept in the dues' oldest-first order.
    final selectedDues = dues
        .where((d) => _selectedInvoiceIds.contains(d.invoice.id))
        .toList(growable: false);
    final selectedOutstanding = PaymentAllocator.totalOutstanding(selectedDues);

    // Live FIFO preview of how the entered amount splits across the
    // selected invoices, plus any portion not yet covered by a selection.
    final entered = double.tryParse(_amountController.text.trim()) ?? 0;
    final capped =
        entered > selectedOutstanding ? selectedOutstanding : entered;
    final allocations = PaymentAllocator.allocate(capped, selectedDues);
    final allocatedById = <String, double>{
      for (final a in allocations) a.invoiceId: a.amount,
    };
    final unallocated =
        entered - selectedOutstanding > 0.0001 ? entered - selectedOutstanding : 0.0;

    // Live overpayment feedback: as soon as the typed amount exceeds what
    // the party owes in total, flag it (no waiting for submit).
    final amountText = _amountController.text.trim();
    final parsedAmount = double.tryParse(amountText);
    final amountLiveError = amountText.isNotEmpty &&
            parsedAmount != null &&
            parsedAmount > totalOutstanding + 0.0001
        ? 'Exceeds total outstanding of ${_currency.format(totalOutstanding)}'
        : null;

    return LightStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.primary,
        bottomNavigationBar: _SubmitBar(
          isLoading: _submitting,
          onPressed: () => _submit(selectedDues),
        ),
        body: Column(
          children: <Widget>[
            AddFormHeader(
              title: 'Add Collection',
              subtitle: 'Record a payment collected from a party',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32.r),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 28.h),
                    child: SectionCard(
                      children: <Widget>[
                        CollectionPlusPartyPickerField(
                          value: _party,
                          parties: ref.watch(collectionPlusPartiesProvider),
                          onChanged: _onPartyPicked,
                        ),
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _amountController,
                          label: 'Amount Received',
                          hintText: party == null
                              ? 'Select a party first'
                              : (dues.isEmpty
                                  ? 'No outstanding invoices'
                                  : 'Enter amount (Rs)'),
                          prefixIcon: Icons.currency_rupee,
                          enabled: party != null && dues.isNotEmpty,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          textInputAction: TextInputAction.next,
                          errorText: amountLiveError,
                          onChanged: (_) => setState(() {}),
                          validator: (v) =>
                              _validateAmount(v, totalOutstanding),
                        ),
                        if (party != null && dues.isNotEmpty) ...<Widget>[
                          SizedBox(height: 6.h),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 13.sp,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                'Total outstanding: '
                                '${_currency.format(totalOutstanding)}',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (party != null) ...<Widget>[
                          SizedBox(height: 16.h),
                          if (dues.isEmpty)
                            OutstandingInvoicesSection(
                              dues: dues,
                              allocatedById: allocatedById,
                              totalOutstanding: selectedOutstanding,
                              unallocated: unallocated,
                            )
                          else ...<Widget>[
                            InvoiceMultiPickerField(
                              dues: dues,
                              selectedIds: _selectedInvoiceIds,
                              targetAmount: entered,
                              onChanged: _onInvoicesChanged,
                            ),
                            if (selectedDues.isNotEmpty) ...<Widget>[
                              SizedBox(height: 16.h),
                              OutstandingInvoicesSection(
                                dues: selectedDues,
                                allocatedById: allocatedById,
                                totalOutstanding: selectedOutstanding,
                                unallocated: unallocated,
                              ),
                            ],
                          ],
                        ],
                        SizedBox(height: 16.h),
                        CustomDatePicker(
                          controller: _receivedDateController,
                          label: 'Received Date',
                          hintText: 'When was it received',
                          prefixIcon: Icons.event_outlined,
                          // A payment is received in the past or today —
                          // block future dates.
                          lastDate: DateTime.now(),
                          validator: (v) =>
                              Validators.requiredField(v, 'Received date'),
                          onDateSelected: (picked) =>
                              setState(() => _receivedDate = picked),
                        ),
                        SizedBox(height: 16.h),
                        PaymentModeField(
                          value: _paymentMode,
                          onChanged: _onPaymentModeChanged,
                        ),
                        if (showBank) ...<Widget>[
                          SizedBox(height: 16.h),
                          BankNameField(
                            value: _bankName,
                            // A suggestion list, not an enum — the picker keeps
                            // its "add a different bank" escape hatch, so an
                            // empty catalogue is survivable.
                            banks:
                                ref.watch(bankNamesProvider).value ??
                                const <String>[],
                            onChanged: (next) =>
                                setState(() => _bankName = next),
                          ),
                        ],
                        if (showCheque) ...<Widget>[
                          SizedBox(height: 16.h),
                          PrimaryTextField(
                            controller: _chequeNumberController,
                            label: 'Cheque Number',
                            hintText: 'Enter cheque number',
                            prefixIcon: Icons.tag_rounded,
                            textInputAction: TextInputAction.next,
                            validator: (v) => Validators.requiredField(
                              v,
                              'Cheque number',
                            ),
                          ),
                          SizedBox(height: 16.h),
                          CustomDatePicker(
                            controller: _chequeDateController,
                            label: 'Cheque Date',
                            hintText: 'Date on the cheque',
                            prefixIcon: Icons.event_note_outlined,
                            onDateSelected: (picked) =>
                                setState(() => _chequeDate = picked),
                          ),
                          SizedBox(height: 16.h),
                          ChequeStatusField(
                            value: _chequeStatus,
                            onChanged: (next) =>
                                setState(() => _chequeStatus = next),
                          ),
                        ],
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _descriptionController,
                          label: 'Description (Optional)',
                          hintText: 'Add any details',
                          prefixIcon: Icons.notes_outlined,
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                        ),
                        SizedBox(height: 20.h),
                        Row(
                          children: <Widget>[
                            Text(
                              'Payment Proof (Optional)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_imagePaths.length}/$_maxImages',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        PrimaryImagePicker(
                          imagePaths: _imagePaths,
                          maxImages: _maxImages,
                          showLabel: false,
                          onPick: _pickImage,
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

/// `Rs 98,000` style formatter shared by the amount validator.
final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);

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
            label: 'Add Collection',
            leadingIcon: Icons.add_circle_outline,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
