import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection/domain/repositories/collection_repository.dart';
import 'package:sales_sphere_erp/features/collection/presentation/controllers/collection_controller.dart';
import 'package:sales_sphere_erp/features/collection/presentation/providers/collection_providers.dart';
import 'package:sales_sphere_erp/features/collection/presentation/widgets/bank_name_field.dart';
import 'package:sales_sphere_erp/features/collection/presentation/widgets/cheque_status_field.dart';
import 'package:sales_sphere_erp/features/collection/presentation/widgets/collection_party_picker_field.dart';
import 'package:sales_sphere_erp/features/collection/presentation/widgets/payment_mode_field.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/add_form_header.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class AddCollectionPage extends ConsumerStatefulWidget {
  const AddCollectionPage({super.key});

  @override
  ConsumerState<AddCollectionPage> createState() => _AddCollectionPageState();
}

class _AddCollectionPageState extends ConsumerState<AddCollectionPage> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _receivedDateController = TextEditingController();
  final _chequeNumberController = TextEditingController();
  final _chequeDateController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const _maxImages = 2;

  CollectionParty? _party;
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

  void _onPartyPicked(CollectionParty? party) {
    setState(() => _party = party);
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

  /// Amount validator: required, a number > 0.
  String? _validateAmount(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Amount is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than 0';
    return null;
  }

  Future<void> _submit() async {
    final party = _party;
    if (party == null) {
      SnackbarUtils.showError(context, 'Please select a party.');
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

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      final created = await ref
          .read(collectionControllerProvider.notifier)
          .addCollection(
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
      // Offline is a success, not a failure: the receipt is cached and queued,
      // and it syncs when the device reconnects. Say so plainly rather than
      // letting the rep think the money wasn't recorded.
      SnackbarUtils.showSuccess(
        context,
        created.syncPending
            ? 'Collection saved offline. It will sync when you reconnect.'
            : 'Collection recorded.',
      );
      context.pop();
    } on PartialImageUploadException catch (e) {
      // The money is recorded; only a proof photo failed. Don't imply the
      // receipt was lost.
      if (!mounted) return;
      SnackbarUtils.showError(
        context,
        'Collection saved, but the payment proof failed to upload: '
        '${e.firstMessage}',
      );
      context.pop();
    } on ApiException catch (e) {
      // Surface the backend's own copy — "Received date cannot be in the
      // future.", "Customer not found", and so on. A generic "Could not save"
      // hides exactly the information the rep needs to fix it.
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

    return LightStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.primary,
        bottomNavigationBar: _SubmitBar(
          isLoading: _submitting,
          onPressed: _submit,
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
                        CollectionPartyPickerField(
                          value: _party,
                          parties: ref.watch(collectionPartiesProvider),
                          onChanged: _onPartyPicked,
                        ),
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _amountController,
                          label: 'Amount Received',
                          hintText: party == null
                              ? 'Select a party first'
                              : 'Enter amount (Rs)',
                          prefixIcon: Icons.currency_rupee,
                          enabled: party != null,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          textInputAction: TextInputAction.next,
                          validator: _validateAmount,
                        ),
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
                            // A suggestion list, not an enum — the field is
                            // free text and the picker keeps its "add a
                            // different bank" escape hatch, so an empty
                            // catalogue (offline, say) is survivable.
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
