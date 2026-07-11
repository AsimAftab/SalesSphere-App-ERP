import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection/domain/repositories/collection_repository.dart';
import 'package:sales_sphere_erp/features/collection/presentation/controllers/collection_controller.dart';
import 'package:sales_sphere_erp/features/collection/presentation/providers/collection_providers.dart';
import 'package:sales_sphere_erp/features/collection/presentation/widgets/bank_name_field.dart';
import 'package:sales_sphere_erp/features/collection/presentation/widgets/cheque_status_field.dart';
import 'package:sales_sphere_erp/features/collection/presentation/widgets/payment_mode_field.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

class EditCollectionDetailPage extends ConsumerStatefulWidget {
  const EditCollectionDetailPage({required this.id, this.initial, super.key});

  final String id;

  /// Optional starting record passed via `extra` when navigating from
  /// the list — saves a re-read on first paint.
  final Collection? initial;

  @override
  ConsumerState<EditCollectionDetailPage> createState() =>
      _EditCollectionDetailPageState();
}

class _EditCollectionDetailPageState
    extends ConsumerState<EditCollectionDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final _partyController = TextEditingController();
  final _amountController = TextEditingController();
  final _receivedDateController = TextEditingController();
  final _chequeNumberController = TextEditingController();
  final _chequeDateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _createdAtController = TextEditingController();

  static const _maxImages = 2;

  // The party a receipt belongs to is fixed — only the amount and the
  // metadata (date/mode/bank/cheque/notes) can change.
  double _amount = 0;
  CollectionParty? _party;
  DateTime? _receivedDate;
  PaymentMode? _paymentMode;
  String? _bankName;
  DateTime? _chequeDate;
  ChequeStatus? _chequeStatus;
  DateTime? _createdAt;
  final List<String> _imagePaths = <String>[];

  bool _editing = false;
  bool _saving = false;

  /// Whether the form fields have been seeded from a resolved row.
  ///
  /// The row arrives one of two ways: pushed through `extra` from the list
  /// (the common case, instant), or resolved asynchronously by
  /// `collectionByIdProvider` on a cold-start deep link. We can't decide
  /// "not found" until that read has actually settled — doing it in
  /// `initState`, as the mock version did, would flash a spurious not-found
  /// screen at anyone opening the app straight onto a receipt.
  bool _populated = false;

  /// The saved row, kept so the edit lifecycle can render sync/status chrome
  /// and so Cancel can restore the last-known-good values.
  Collection? _saved;

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

  void _populate(Collection c) {
    _amount = c.amount;
    _party = c.party;
    _partyController.text = c.party.name;
    // Currency-formatted while viewing; switched to a raw number on edit.
    _amountController.text = _currency.format(c.amount);
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

  /// Amount validator: required, > 0.
  String? _validateAmount(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Amount is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than 0';
    return null;
  }

  Future<void> _save() async {
    final party = _party;
    if (party == null) {
      SnackbarUtils.showError(context, 'Missing party.');
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

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final updated = Collection(
        id: widget.id,
        collectionNo: _saved?.collectionNo ?? '',
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
        // Only newly-picked local files are uploaded; already-stored proofs
        // live in `imageUrls` and aren't re-sent.
        imagePaths: List<String>.unmodifiable(_imagePaths),
        createdAt: _createdAt ?? DateTime.now(),
      );
      await ref
          .read(collectionControllerProvider.notifier)
          .updateCollection(updated);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
        _amount = amount;
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
      // Surface the server's own copy. The one that matters most here is the
      // 409 — "Only DRAFT collections can be updated" — which happens when an
      // accountant posted the receipt while this page was open.
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarUtils.showError(context, e.message);
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    }
  }

  void _back() {
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Drift-backed stream: the row re-emits when a background sync lands or a
    // cheque status changes, so the page stays live without a manual refresh.
    final rowAsync = ref.watch(collectionByIdProvider(widget.id));

    rowAsync.whenData((row) {
      if (row == null) return;
      _saved = row;
      // Seed the form the first time the row resolves (cold-start deep link),
      // and re-seed on later emissions only while the user isn't mid-edit —
      // clobbering a half-typed form because a sync landed would be hostile.
      if (!_populated || !_editing) {
        _populate(row);
        _populated = true;
      }
    });

    // Only call it missing once the read has actually settled on nothing.
    if (rowAsync.hasValue && rowAsync.value == null && widget.initial == null) {
      return const _NotFoundScaffold();
    }
    if (!_populated) return const _LoadingScaffold();

    final mode = _paymentMode;
    final showBank = mode?.requiresBank ?? false;
    final showCheque = mode?.requiresChequeDetails ?? false;

    // A receipt is only editable while it's a DRAFT that has actually reached
    // the server. Once an accountant posts it the server 409s any PATCH, and a
    // row still queued in the outbox has no server id to address — so in both
    // cases the Edit affordance is withdrawn rather than offered and then
    // rejected.
    final canEdit = _saved?.isEditable ?? true;

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: (canEdit || _editing)
            ? _SubmitBar(
                editing: _editing,
                isLoading: _saving,
                onPressed: _editing ? _save : _toggleEdit,
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
                                    validator: _validateAmount,
                                  )
                                else
                                  PrimaryTextField(
                                    controller: _amountController,
                                    label: 'Amount Received',
                                    prefixIcon: Icons.currency_rupee,
                                    enabled: false,
                                    readOnly: true,
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
                                        ref
                                            .watch(collectionBankNamesProvider)
                                            .value ??
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
/// Only reachable when the page wasn't handed the row through `extra`.
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
