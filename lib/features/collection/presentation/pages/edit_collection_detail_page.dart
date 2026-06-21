import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_invoice.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection/presentation/controllers/collection_controller.dart';
import 'package:sales_sphere_erp/features/collection/presentation/providers/collection_providers.dart';
import 'package:sales_sphere_erp/features/collection/presentation/widgets/bank_name_field.dart';
import 'package:sales_sphere_erp/features/collection/presentation/widgets/cheque_status_field.dart';
import 'package:sales_sphere_erp/features/collection/presentation/widgets/invoice_picker_field.dart';
import 'package:sales_sphere_erp/features/collection/presentation/widgets/payment_mode_field.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

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

  CollectionInvoice? _invoice;
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
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    final collection =
        widget.initial ?? ref.read(collectionByIdProvider(widget.id));
    if (collection != null) {
      _populate(collection);
    } else {
      _notFound = true;
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

  void _populate(Collection c) {
    _invoice = c.invoice;
    _party = c.party;
    _partyController.text = c.party.name;
    _amountController.text = _trimAmount(c.amount);
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

  /// Renders the stored amount without a trailing `.0` for whole numbers
  /// so the edit field shows `12500`, not `12500.0`.
  String _trimAmount(double amount) =>
      amount == amount.roundToDouble()
          ? amount.toInt().toString()
          : amount.toString();

  void _toggleEdit() {
    setState(() => _editing = !_editing);
  }

  void _cancelEdit() {
    final saved =
        ref.read(collectionByIdProvider(widget.id)) ?? widget.initial;
    if (saved != null) _populate(saved);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _editing = false);
  }

  /// The collection is booked against an invoice, so the party is the
  /// invoice's party — never picked independently. Resolves the full
  /// [CollectionParty] from the known parties, falling back to a slim
  /// record built from the invoice when the party isn't in the corpus.
  CollectionParty _partyForInvoice(CollectionInvoice inv) {
    for (final p in ref.read(collectionPartiesProvider)) {
      if (p.id == inv.partyId) return p;
    }
    return CollectionParty(
      id: inv.partyId ?? inv.id,
      name: inv.partyName,
      address: '',
    );
  }

  /// Picking a different invoice re-points the party. The amount is left
  /// as-is unless it's empty (an existing collection always has one).
  void _onInvoicePicked(CollectionInvoice? inv) {
    setState(() {
      _invoice = inv;
      if (inv == null) {
        _party = null;
        _partyController.text = '';
        return;
      }
      _party = _partyForInvoice(inv);
      _partyController.text = _party!.name;
      if (_amountController.text.trim().isEmpty) {
        _amountController.text = _trimAmount(inv.amount);
      }
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
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
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

  String? _validateAmount(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Amount is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than 0';
    return null;
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    final invoice = _invoice;
    final party = _party;
    final mode = _paymentMode;
    final receivedDate = _receivedDate;

    if (invoice == null || party == null) {
      SnackbarUtils.showError(context, 'Please select an invoice.');
      return;
    }
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

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final updated = Collection(
        id: widget.id,
        invoice: invoice,
        party: party,
        amount: double.parse(_amountController.text.trim()),
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
        createdAt: _createdAt ?? DateTime.now(),
      );
      await ref
          .read(collectionControllerProvider.notifier)
          .updateCollection(updated);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
      SnackbarUtils.showSuccess(context, 'Collection updated.');
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
    if (_notFound) return const _NotFoundScaffold();
    // Keep the provider warm so cancelEdit reads the saved snapshot.
    ref.watch(collectionByIdProvider(widget.id));

    final mode = _paymentMode;
    final showBank = mode?.requiresBank ?? false;
    final showCheque = mode?.requiresChequeDetails ?? false;

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: _SubmitBar(
          editing: _editing,
          isLoading: _saving,
          onPressed: _editing ? _save : _toggleEdit,
        ),
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
                                InvoicePickerField(
                                  value: _invoice,
                                  enabled: _editing,
                                  invoices:
                                      ref.watch(collectionInvoicesProvider),
                                  onChanged: _onInvoicePicked,
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _partyController,
                                  label: 'Party',
                                  hintText: 'Set from the selected invoice',
                                  prefixIcon: Icons.storefront_outlined,
                                  enabled: false,
                                  readOnly: true,
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _amountController,
                                  label: 'Amount Received',
                                  hintText: 'Enter amount (Rs)',
                                  prefixIcon: Icons.currency_rupee,
                                  enabled: _editing,
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
                                    banks: ref.watch(bankNamesProvider),
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
