import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_allocation.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_invoice.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/invoice_due.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_allocator.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/repositories/collection_plus_repository.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/controllers/collection_controller.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/providers/collection_providers.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/widgets/bank_name_field.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/widgets/cheque_status_field.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/widgets/invoice_multi_picker_field.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/widgets/outstanding_invoices_section.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/widgets/payment_mode_field.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/cheque_status_action.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);

class EditCollectionPlusDetailPage extends ConsumerStatefulWidget {
  const EditCollectionPlusDetailPage({required this.id, this.initial, super.key});

  final String id;

  /// Optional starting record passed via `extra` when navigating from
  /// the list — saves a re-read on first paint.
  final CollectionPlus? initial;

  @override
  ConsumerState<EditCollectionPlusDetailPage> createState() =>
      _EditCollectionPlusDetailPageState();
}

class _EditCollectionPlusDetailPageState
    extends ConsumerState<EditCollectionPlusDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final _partyController = TextEditingController();
  final _amountController = TextEditingController();
  final _receivedDateController = TextEditingController();
  final _chequeNumberController = TextEditingController();
  final _chequeDateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _createdAtController = TextEditingController();

  static const _maxImages = 2;

  // The party a receipt belongs to is fixed — only the amount, the
  // invoice allocation, and the metadata (date/mode/bank/cheque/notes)
  // can change. [_allocations] holds the last-saved split; in edit mode
  // it's recomputed FIFO from [_selectedInvoiceIds] + the amount.
  List<CollectionPlusAllocation> _allocations = const <CollectionPlusAllocation>[];
  double _amount = 0;
  CollectionPlusParty? _party;
  final Set<String> _selectedInvoiceIds = <String>{};
  DateTime? _receivedDate;
  PaymentMode? _paymentMode;
  String? _bankName;
  DateTime? _chequeDate;
  ChequeStatus? _chequeStatus;
  DateTime? _createdAt;
  final List<String> _imagePaths = <String>[];

  bool _editing = false;
  bool _saving = false;

  /// Whether the form has been seeded from a resolved row. The row arrives
  /// either through `extra` (from the list, instant) or asynchronously on a
  /// cold-start deep link — so "not found" can't be decided until the read
  /// settles.
  bool _populated = false;

  /// The saved row, so Cancel can restore it and the chrome can reflect
  /// status / sync state.
  CollectionPlus? _saved;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _saved = initial;
      _populate(initial);
      _populated = true;
    }
  }

  @override
  void dispose() {
    _partyController.dispose();
    _amountController.dispose();
    _receivedDateController.dispose();
    _chequeNumberController.dispose();
    _chequeDateController.dispose();
    _descriptionController.dispose();
    _createdAtController.dispose();
    super.dispose();
  }

  /// Renders an amount without a trailing `.0` for whole numbers — used
  /// while the amount field is editable.
  String _rawAmount(double amount) => amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toStringAsFixed(2);

  void _populate(CollectionPlus c) {
    _allocations = c.allocations;
    _amount = c.amount;
    _party = c.party;
    _partyController.text = c.party.name;
    // Currency-formatted while viewing; switched to a raw number on edit.
    _amountController.text = _currency.format(c.amount);
    _selectedInvoiceIds
      ..clear()
      ..addAll(c.allocations.map((a) => a.invoiceId));
    _receivedDate = c.receivedDate;
    _receivedDateController.text =
        DateFormat('dd MMM yyyy').format(c.receivedDate);
    _paymentMode = c.paymentMode;
    _bankName = c.bankName;
    _chequeNumberController.text = c.chequeNumber ?? '';
    _chequeDate = c.chequeDate;
    _chequeDateController.text = c.chequeDate == null
        ? ''
        : DateFormat('dd MMM yyyy').format(c.chequeDate!);
    _chequeStatus = c.chequeStatus;
    _descriptionController.text = c.description;
    _createdAt = c.createdAt;
    _createdAtController.text =
        DateFormat('dd MMM yyyy, hh:mm a').format(c.createdAt);
    _imagePaths
      ..clear()
      ..addAll(c.imagePaths);
  }

  void _toggleEdit() {
    setState(() {
      _editing = true;
      // Show a raw, editable number instead of the formatted currency.
      _amountController.text = _rawAmount(_amount);
    });
  }

  void _cancelEdit() {
    final saved = _saved ?? widget.initial;
    if (saved != null) _populate(saved);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _editing = false);
  }

  void _onInvoicesChanged(Set<String> ids) {
    setState(() {
      _selectedInvoiceIds
        ..clear()
        ..addAll(ids);
    });
  }

  /// When the payment mode changes, drop conditional state the new mode
  /// no longer needs so a stale bank / cheque value can't be saved.
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
    if (!_editing || _imagePaths.length >= _maxImages) return;
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
    if (!_editing) return;
    setState(() => _imagePaths.removeAt(index));
  }

  /// Amount validator: required, > 0, and never more than the party's
  /// total outstanding (computed with this collection released).
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

  Future<void> _save(List<InvoiceDue> selectedDues) async {
    final party = _party;
    if (party == null) {
      SnackbarUtils.showError(context, 'Missing party.');
      return;
    }
    if (selectedDues.isEmpty) {
      SnackbarUtils.showError(context, 'Please select at least one invoice.');
      return;
    }

    final formValid = _formKey.currentState?.validate() ?? false;
    final mode = _paymentMode;
    final receivedDate = _receivedDate;

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
    setState(() => _saving = true);
    try {
      // Allocations stay empty here: the client sends the *selection*, and the
      // server re-runs FIFO against live balances. On an edit it first releases
      // this receipt's own allocations back into the pool — which is exactly
      // what `excludeCollectionId` mirrors on the outstanding read — then
      // re-splits the new amount.
      final updated = CollectionPlus(
        id: widget.id,
        collectionNo: _saved?.collectionNo ?? '',
        allocations: const <CollectionPlusAllocation>[],
        party: party,
        amount: amount,
        receivedDate: receivedDate,
        paymentMode: mode,
        status: _saved?.status ?? CollectionStatus.draft,
        bankName: mode.requiresBank ? _bankName : null,
        chequeNumber: mode.requiresChequeDetails
            ? _chequeNumberController.text.trim()
            : null,
        chequeDate: mode.requiresChequeDetails ? _chequeDate : null,
        chequeStatus: mode.requiresChequeDetails ? _chequeStatus : null,
        description: _descriptionController.text.trim(),
        imagePaths: List<String>.unmodifiable(_imagePaths),
        createdAt: _createdAt ?? DateTime.now(),
      );
      final saved = await ref
          .read(collectionPlusControllerProvider.notifier)
          .updateCollection(
            updated,
            invoiceIds: selectedDues
                .map((d) => d.invoice.id)
                .toList(growable: false),
          );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
        _amount = amount;
        // The server's split, not the preview's.
        _allocations = saved.allocations;
        _amountController.text = _currency.format(amount);
      });
      SnackbarUtils.showSuccess(context, 'Collection updated.');
    } on PartialImageUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
      SnackbarUtils.showError(
        context,
        'Collection updated, but the payment proof failed to upload: '
        '${e.firstMessage}',
      );
    } on ApiException catch (e) {
      // Surfaces the coverage-short 422 and the "Only DRAFT collections can be
      // updated" 409 verbatim.
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarUtils.showError(context, e.message);
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    }
  }

  /// Advance the cheque through its clearing lifecycle.
  ///
  /// Unlike the plain module, these transitions do **real accounting** once the
  /// receipt is posted: clearing writes a contra entry moving the money out of
  /// Cheque-in-Hand into the bank, and bouncing writes a reversal that cancels
  /// the receipt and puts every invoice it settled back to outstanding.
  ///
  /// That is why it goes through the dedicated endpoint and behind a
  /// confirmation naming the entries — not through a generic form save.
  Future<void> _advanceChequeStatus() async {
    final current = _chequeStatus;
    if (current == null || current.isTerminal) return;

    final next = await showChequeStatusSheet<ChequeStatus>(
      context: context,
      currentLabel: current.label,
      transitions: current.nextStates
          .map(
            (s) => ChequeTransition<ChequeStatus>(
              value: s,
              label: s.label,
              icon: s.icon,
              color: s.color,
              confirmationCopy: s.confirmationCopy,
            ),
          )
          .toList(growable: false),
    );
    if (next == null || !mounted) return;

    try {
      final updated = await ref
          .read(collectionPlusControllerProvider.notifier)
          .updateChequeStatus(id: widget.id, status: next);
      if (!mounted) return;
      setState(() {
        _chequeStatus = updated.chequeStatus;
        _allocations = updated.allocations;
      });
      SnackbarUtils.showSuccess(context, 'Cheque marked as ${next.label}.');
    } on ApiException catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(context, e.message);
    } on Exception catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Could not update the cheque status.');
    }
  }

  void _back() {
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final rowAsync = ref.watch(collectionPlusByIdProvider(widget.id));

    rowAsync.whenData((row) {
      if (row == null) return;
      _saved = row;
      // Seed on first resolve (cold-start deep link), and re-seed on later
      // emissions only while the user isn't mid-edit — clobbering a half-typed
      // form because a sync landed would be hostile.
      if (!_populated || !_editing) {
        _populate(row);
        _populated = true;
      }
    });

    if (rowAsync.hasValue && rowAsync.value == null && widget.initial == null) {
      return const _NotFoundScaffold();
    }
    if (!_populated) return const _LoadingScaffold();

    final mode = _paymentMode;
    final showBank = mode?.requiresBank ?? false;
    final showCheque = mode?.requiresChequeDetails ?? false;

    final party = _party;

    // Outstanding with THIS receipt's own allocations released, so its money is
    // available to re-allocate. Without `excludeCollectionId` the collection
    // being edited still holds down the very amount it's about to re-spend, and
    // re-saving it unchanged fails validation every single time.
    final dues = party == null
        ? const <InvoiceDue>[]
        : ref
                  .watch(
                    outstandingInvoicesForPartyProvider(
                      party.id,
                      excludeCollectionId: widget.id,
                    ),
                  )
                  .value ??
              const <InvoiceDue>[];

    // Invoice lookup for the read-mode breakdown, so each settled invoice shows
    // its date and total alongside what this receipt put against it.
    //
    // Uses `invoice-meta` rather than the outstanding read: an invoice this
    // receipt *fully settled* has no outstanding balance left and so is absent
    // from that list — but it still has to render here.
    final settledIds = _allocations
        .map((a) => a.invoiceId)
        .toList(growable: false);
    final invoiceById = <String, CollectionPlusInvoice>{
      for (final d
          in settledIds.isEmpty
              ? const <InvoiceDue>[]
              : ref
                        .watch(
                          invoiceMetaProvider(
                            settledIds,
                            excludeCollectionId: widget.id,
                          ),
                        )
                        .value ??
                    const <InvoiceDue>[])
        d.invoice.id: d.invoice,
    };
    final dueByInvoiceId = <String, InvoiceDue>{
      for (final d in dues) d.invoice.id: d,
    };
    final totalOutstanding = PaymentAllocator.totalOutstanding(dues);
    final selectedDues = dues
        .where((d) => _selectedInvoiceIds.contains(d.invoice.id))
        .toList(growable: false);
    final selectedOutstanding = PaymentAllocator.totalOutstanding(selectedDues);

    final entered = double.tryParse(_amountController.text.trim()) ?? 0;
    final capped =
        entered > selectedOutstanding ? selectedOutstanding : entered;
    final allocations = PaymentAllocator.allocate(capped, selectedDues);
    final allocatedById = <String, double>{
      for (final a in allocations) a.invoiceId: a.amount,
    };
    final unallocated = entered - selectedOutstanding > 0.0001
        ? entered - selectedOutstanding
        : 0.0;
    final amountText = _amountController.text.trim();
    final parsedAmount = double.tryParse(amountText);
    final amountLiveError = _editing &&
            amountText.isNotEmpty &&
            parsedAmount != null &&
            parsedAmount > totalOutstanding + 0.0001
        ? 'Exceeds total outstanding of ${_currency.format(totalOutstanding)}'
        : null;

    // Editable only while it's a DRAFT that has reached the server: a posted
    // receipt is 409'd by any PATCH, and a row still queued in the outbox has
    // no server id to address. Withdraw the affordance rather than offer it and
    // then have the server refuse.
    final canEdit = _saved?.isEditable ?? true;

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: (canEdit || _editing)
            ? _SubmitBar(
                editing: _editing,
                isLoading: _saving,
                onPressed: _editing ? () => _save(selectedDues) : _toggleEdit,
              )
            : null,
        body: Stack(
          children: <Widget>[
            const _CurvedHeader(),
            SafeArea(
              child: Column(
                children: <Widget>[
                  _DetailAppBar(
                    onBack: _back,
                    editing: _editing,
                    onCancel: _cancelEdit,
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            SectionCard(
                              children: <Widget>[
                                // Party is fixed — read-only in both modes.
                                PrimaryTextField(
                                  controller: _partyController,
                                  label: 'Party',
                                  prefixIcon: Icons.storefront_outlined,
                                  enabled: false,
                                  readOnly: true,
                                ),
                                SizedBox(height: 12.h),
                                if (_editing)
                                  PrimaryTextField(
                                    controller: _amountController,
                                    label: 'Amount Received',
                                    hintText: 'Enter amount (Rs)',
                                    prefixIcon: Icons.currency_rupee,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*'),
                                      ),
                                    ],
                                    errorText: amountLiveError,
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) =>
                                        _validateAmount(v, totalOutstanding),
                                  )
                                else
                                  PrimaryTextField(
                                    controller: _amountController,
                                    label: 'Amount Received',
                                    prefixIcon: Icons.currency_rupee,
                                    enabled: false,
                                    readOnly: true,
                                  ),
                                if (_editing) ...<Widget>[
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
                                SizedBox(height: 12.h),
                                if (_editing) ...<Widget>[
                                  InvoiceMultiPickerField(
                                    dues: dues,
                                    selectedIds: _selectedInvoiceIds,
                                    targetAmount: entered,
                                    onChanged: _onInvoicesChanged,
                                  ),
                                  if (selectedDues.isNotEmpty) ...<Widget>[
                                    SizedBox(height: 12.h),
                                    OutstandingInvoicesSection(
                                      dues: selectedDues,
                                      allocatedById: allocatedById,
                                      totalOutstanding: selectedOutstanding,
                                      unallocated: unallocated,
                                    ),
                                  ],
                                ] else
                                _AllocationBreakdown(
                                  allocations: _allocations,
                                  invoiceById: invoiceById,
                                  dueByInvoiceId: dueByInvoiceId,
                                  isCancelled: _saved?.status == CollectionStatus.cancelled,
                                ),
                                SizedBox(height: 12.h),
                                CustomDatePicker(
                                  controller: _receivedDateController,
                                  label: 'Received Date',
                                  hintText: 'When was it received',
                                  prefixIcon: Icons.event_outlined,
                                  enabled: _editing,
                                  initialDate: _receivedDate,
                                  lastDate: DateTime.now(),
                                  validator: (v) => Validators.requiredField(
                                    v,
                                    'Received date',
                                  ),
                                  onDateSelected: (picked) =>
                                      setState(() => _receivedDate = picked),
                                ),
                                SizedBox(height: 12.h),
                                PaymentModeField(
                                  value: _paymentMode,
                                  enabled: _editing,
                                  onChanged: _onPaymentModeChanged,
                                ),
                                if (showBank) ...<Widget>[
                                  SizedBox(height: 12.h),
                                  BankNameField(
                                    value: _bankName,
                                    enabled: _editing,
                                    banks:
                                        ref.watch(bankNamesProvider).value ??
                                        const <String>[],
                                    onChanged: (next) =>
                                        setState(() => _bankName = next),
                                  ),
                                ],
                                if (showCheque) ...<Widget>[
                                  SizedBox(height: 12.h),
                                  PrimaryTextField(
                                    controller: _chequeNumberController,
                                    label: 'Cheque Number',
                                    hintText: 'Enter cheque number',
                                    prefixIcon: Icons.tag_rounded,
                                    enabled: _editing,
                                    validator: (v) => Validators.requiredField(
                                      v,
                                      'Cheque number',
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  CustomDatePicker(
                                    controller: _chequeDateController,
                                    label: 'Cheque Date',
                                    hintText: 'Date on the cheque',
                                    prefixIcon: Icons.event_note_outlined,
                                    enabled: _editing,
                                    initialDate: _chequeDate,
                                    onDateSelected: (picked) =>
                                        setState(() => _chequeDate = picked),
                                  ),
                                  SizedBox(height: 12.h),
                                  ChequeStatusField(
                                    value: _chequeStatus,
                                    enabled: _editing,
                                    onChanged: (next) =>
                                        setState(() => _chequeStatus = next),
                                  ),
                                  // Goes through the dedicated cheque-status
                                  // endpoint: on a POSTED receipt these moves
                                  // write real vouchers, so they must not ride
                                  // in on a generic form save.
                                  if (!_editing &&
                                      _chequeStatus != null &&
                                      !_chequeStatus!.isTerminal &&
                                      (_saved?.syncPending ?? false) == false)
                                    Padding(
                                      padding: EdgeInsets.only(top: 12.h),
                                      child: OutlinedButton.icon(
                                        onPressed: _advanceChequeStatus,
                                        icon: Icon(
                                          Icons.sync_alt_rounded,
                                          size: 18.sp,
                                        ),
                                        label: const Text(
                                          'Update cheque status',
                                        ),
                                      ),
                                    ),
                                ],
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _descriptionController,
                                  label: 'Description (Optional)',
                                  hintText: 'Add any details',
                                  prefixIcon: Icons.notes_outlined,
                                  minLines: 1,
                                  maxLines: 6,
                                  enabled: _editing,
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _createdAtController,
                                  label: 'Recorded On',
                                  prefixIcon: Icons.access_time_rounded,
                                  enabled: false,
                                  readOnly: true,
                                ),
                                SizedBox(height: 18.h),
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
                                  enabled: _editing,
                                  showLabel: false,
                                  onPick: _pickImage,
                                  onRemove: _removeImageAt,
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                          ],
                        ),
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

/// Read-only list of which invoices the payment settled and by how much.
/// For each, shows the invoice date and total (resolved from
/// [invoiceById]) alongside the amount collected against it.
class _AllocationBreakdown extends StatelessWidget {
  const _AllocationBreakdown({
    required this.allocations,
    required this.invoiceById,
    required this.dueByInvoiceId,
    this.isCancelled = false,
  });

  final List<CollectionPlusAllocation> allocations;
  final Map<String, CollectionPlusInvoice> invoiceById;
  final Map<String, InvoiceDue> dueByInvoiceId;
  final bool isCancelled;

  @override
  Widget build(BuildContext context) {
    if (allocations.isEmpty) return const SizedBox.shrink();
    final dateFmt = DateFormat('dd MMM yyyy');
    final totalCollected =
        allocations.fold<double>(0, (sum, a) => sum + a.amount);

    return Container(
      decoration: BoxDecoration(
        // Match the disabled `PrimaryTextField` fill + faded border so the
        // card reads as one of the other read-only fields on the page.
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header (no icon) — labelled distinctly from the add form.
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
            child: Row(
              children: <Widget>[
                Text(
                  'Settled Invoices',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  allocations.length == 1
                      ? '1 invoice'
                      : '${allocations.length} invoices',
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
          for (var i = 0; i < allocations.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, color: AppColors.border.withValues(alpha: 0.4)),
            _SettledInvoiceRow(
              allocation: allocations[i],
              invoice: invoiceById[allocations[i].invoiceId],
              due: dueByInvoiceId[allocations[i].invoiceId],
              dateFmt: dateFmt,
              isCancelled: isCancelled,
            ),
          ],
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 12.h),
            child: Row(
              children: <Widget>[
                Text(
                  'Total collected',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  _currency.format(totalCollected),
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettledInvoiceRow extends StatelessWidget {
  const _SettledInvoiceRow({
    required this.allocation,
    required this.invoice,
    required this.due,
    required this.dateFmt,
    this.isCancelled = false,
  });

  final CollectionPlusAllocation allocation;
  final CollectionPlusInvoice? invoice;
  final InvoiceDue? due;
  final DateFormat dateFmt;
  final bool isCancelled;

  @override
  Widget build(BuildContext context) {
    final inv = invoice ?? due?.invoice;
    final d = due;
    final remaining = inv == null
        ? 0.0
        : (inv.amount - (d?.paid ?? 0) - allocation.amount)
            .clamp(0.0, double.infinity);
    final isSettled = inv != null && remaining <= 0.0001;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    allocation.invoiceNumber,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (inv != null) ...<Widget>[
                  SizedBox(height: 3.h),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Total ${_currency.format(inv.amount)} · ${dateFmt.format(inv.invoiceDate)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
                if (d != null && d.paid > 0.0001) ...<Widget>[
                  SizedBox(height: 2.h),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      d.lastPaidOn == null
                          ? 'Paid ${_currency.format(d.paid)}'
                          : 'Paid ${_currency.format(d.paid)} · last on ${dateFmt.format(d.lastPaidOn!)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
                if (inv != null) ...<Widget>[
                  SizedBox(height: 3.h),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isCancelled
                          ? 'Void — bill not settled'
                          : isSettled
                              ? 'Bill settled'
                              : 'Outstanding ${_currency.format(remaining)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _currency.format(allocation.amount),
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'Collected',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurvedHeader extends StatelessWidget {
  const _CurvedHeader();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SvgPicture.asset(
        'assets/images/corner_bubble.svg',
        fit: BoxFit.cover,
        height: 180.h,
      ),
    );
  }
}

class _DetailAppBar extends StatelessWidget {
  const _DetailAppBar({
    required this.onBack,
    required this.editing,
    required this.onCancel,
  });

  final VoidCallback onBack;
  final bool editing;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 4.h),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textdark,
              size: 20.sp,
            ),
            tooltip: 'Back',
            onPressed: onBack,
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              'Collection Details',
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
          if (editing)
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.editing,
    required this.isLoading,
    required this.onPressed,
  });

  final bool editing;
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
            label: editing ? 'Save Changes' : 'Edit Detail',
            leadingIcon: editing ? Icons.check : Icons.edit,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class _NotFoundScaffold extends StatelessWidget {
  const _NotFoundScaffold();

  @override
  Widget build(BuildContext context) {
    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.primary,
          title: const Text('Collection Details'),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              "Couldn't load this collection — it may have been removed.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while a cold-start deep link resolves the receipt from the server.
class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.primary,
          title: const Text('Collection Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
