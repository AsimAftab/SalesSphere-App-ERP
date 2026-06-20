import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/domain/repositories/parties_repository.dart';
import 'package:sales_sphere_erp/features/parties/presentation/controllers/parties_controller.dart';
import 'package:sales_sphere_erp/features/parties/presentation/widgets/party_type_picker.dart';
import 'package:sales_sphere_erp/shared/utils/image_validation.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/add_form_header.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/location_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class AddPartyPage extends ConsumerStatefulWidget {
  const AddPartyPage({super.key});

  @override
  ConsumerState<AddPartyPage> createState() => _AddPartyPageState();
}

class _AddPartyPageState extends ConsumerState<AddPartyPage> {
  // Default camera target — Kathmandu. Replaced as soon as the user picks
  // a point or taps "use my current location".
  static const _defaultLat = 27.7172;
  static const _defaultLng = 85.3240;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _panVatController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();

  static const _maxImages = 2;

  String? _partyType;
  DateTime? _dateJoined;
  double _latitude = _defaultLat;
  double _longitude = _defaultLng;
  final List<String> _imagePaths = <String>[];
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _panVatController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_imagePaths.length >= _maxImages) return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        // Cap the longest side so a 12MP phone photo doesn't land
        // above the backend's 5MB ceiling. Native resize on device.
        maxWidth: kPickerMaxDimension,
        maxHeight: kPickerMaxDimension,
      );
      if (file == null) return;
      if (!isAllowedImageFile(file.path)) {
        if (!mounted) return;
        SnackbarUtils.showError(context, kUnsupportedImageMessage);
        return;
      }
      final bytes = await imageFileBytes(file.path);
      if (bytes != null && bytes > kMaxImageBytes) {
        if (!mounted) return;
        SnackbarUtils.showError(context, imageTooLargeMessage(bytes));
        return;
      }
      setState(() => _imagePaths.add(file.path));
    } on Exception catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Could not load image.');
    }
  }

  void _removeImageAt(int index) {
    setState(() => _imagePaths.removeAt(index));
  }

  void _onLocationChanged(double lat, double lng) {
    setState(() {
      _latitude = lat;
      _longitude = lng;
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      final draft = Party(
        id: '', // assigned by the API mock
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        ownerName: _ownerController.text.trim(),
        panVat: _panVatController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().nullIfEmpty(),
        dateJoined: _dateJoined,
        partyType: _partyType,
        notes: _notesController.text.trim().nullIfEmpty(),
        latitude: _latitude,
        longitude: _longitude,
        imagePaths: List<String>.unmodifiable(_imagePaths),
      );
      await ref.read(partiesControllerProvider.notifier).addParty(draft);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Party added.');
      context.pop();
    } on PartialImageUploadException catch (e) {
      // Customer was saved; one or more images didn't upload. Still
      // pop back — the user has a row to look at and can re-attach
      // the missing slots from the edit page.
      if (!mounted) return;
      final n = e.failedSlots.length;
      SnackbarUtils.showError(
        context,
        "Party added, but $n image${n == 1 ? '' : 's'} didn't upload: "
        '${e.firstMessage}',
      );
      context.pop();
    } on Exception catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              title: 'Add New Party',
              subtitle: "Enter the new party's details",
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
                        PrimaryTextField(
                          controller: _nameController,
                          label: 'Party Name',
                          hintText: 'Enter party name',
                          prefixIcon: Icons.business_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.requiredField(v, 'Party name'),
                        ),
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _ownerController,
                          label: 'Owner Name',
                          hintText: 'Enter owner name',
                          prefixIcon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.requiredField(v, 'Owner name'),
                        ),
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _panVatController,
                          label: 'PAN/VAT Number',
                          hintText: 'Enter PAN or VAT number',
                          prefixIcon: Icons.receipt_long_outlined,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          maxLength: 9,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: Validators.panVat,
                        ),
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          hintText: 'Enter phone number',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          maxLength: 10,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: Validators.phone10,
                        ),
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hintText: 'Enter email address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: Validators.emailOptional,
                        ),
                        SizedBox(height: 16.h),
                        CustomDatePicker(
                          controller: _dateController,
                          label: 'Date Joined',
                          hintText: 'Select date',
                          prefixIcon: Icons.calendar_today_outlined,
                          initialDate: _dateJoined,
                          firstDate: DateTime(DateTime.now().year - 50),
                          lastDate: DateTime(DateTime.now().year + 5),
                          validator: (v) =>
                              Validators.requiredField(v, 'Date joined'),
                          onDateSelected: (date) =>
                              setState(() => _dateJoined = date),
                        ),
                        SizedBox(height: 16.h),
                        PartyTypePicker(
                          value: _partyType,
                          enabled: true,
                          onChanged: (v) => setState(() => _partyType = v),
                        ),
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _notesController,
                          label: 'Notes',
                          hintText: 'Add notes',
                          prefixIcon: Icons.note_outlined,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                        ),
                        SizedBox(height: 16.h),
                        LocationPicker(
                          addressController: _addressController,
                          latitude: _latitude,
                          longitude: _longitude,
                          editing: true,
                          onLocationChanged: _onLocationChanged,
                          addressValidator: (v) =>
                              Validators.requiredField(v, 'Address'),
                        ),
                        SizedBox(height: 20.h),
                        Row(
                          children: <Widget>[
                            Text(
                              'Party Image (Optional)',
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
            label: 'Add Party',
            leadingIcon: Icons.add_circle_outline,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

extension on String {
  String? nullIfEmpty() => isEmpty ? null : this;
}
