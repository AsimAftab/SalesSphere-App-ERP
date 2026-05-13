import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/presentation/controllers/miscellaneous_work_controller.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/location_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class AddMiscellaneousWorkPage extends ConsumerStatefulWidget {
  const AddMiscellaneousWorkPage({super.key});

  @override
  ConsumerState<AddMiscellaneousWorkPage> createState() =>
      _AddMiscellaneousWorkPageState();
}

class _AddMiscellaneousWorkPageState
    extends ConsumerState<AddMiscellaneousWorkPage> {
  // Default camera target — Kathmandu, matches `add_party_page`. The
  // LocationPicker won't render usefully if it opens at (0, 0), so we
  // seed a sensible position and the address validator below ensures
  // the user still resolves a real address before submit.
  static const _defaultLat = 27.7172;
  static const _defaultLng = 85.3240;

  final _formKey = GlobalKey<FormState>();

  final _natureController = TextEditingController();
  final _assignedByController = TextEditingController();
  final _workDateController = TextEditingController();
  final _addressController = TextEditingController();

  static const _maxImages = 2;

  // Work date stays unset until the user picks one — the field
  // renders empty (with the hint) instead of defaulting to today, so
  // the user has to deliberately confirm the date and the form's
  // required-field validator catches an unfilled submit.
  DateTime? _workDate;
  double _latitude = _defaultLat;
  double _longitude = _defaultLng;
  final List<String> _imagePaths = <String>[];
  bool _submitting = false;

  @override
  void dispose() {
    _natureController.dispose();
    _assignedByController.dispose();
    _workDateController.dispose();
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
      final draft = MiscellaneousWork(
        id: '',
        // assigned by the API mock
        natureOfWork: _natureController.text.trim(),
        assignedBy: _assignedByController.text.trim(),
        // Safe to assert non-null: the form's required-field
        // validator on `_workDateController` blocks submit when empty,
        // so we only reach here once the user has picked a date.
        workDate: _workDate!,
        address: _addressController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        // Repository/API assigns the canonical createdAt — placeholder.
        createdAt: DateTime.now(),
        imagePaths: List<String>.unmodifiable(_imagePaths),
      );
      await ref
          .read(miscellaneousWorkControllerProvider.notifier)
          .addWork(draft);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Work added.');
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
            _Header(onBack: () => context.pop()),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32.r),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 32.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        PrimaryTextField(
                          controller: _natureController,
                          label: 'Nature of Work',
                          hintText: 'Enter nature of work',
                          prefixIcon: Icons.work_outline_rounded,
                          minLines: 1,
                          maxLines: 2,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.requiredField(v, 'Nature of Work'),
                        ),
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _assignedByController,
                          label: 'Assigned By',
                          hintText: 'Who assigned this task?',
                          prefixIcon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.requiredField(v, 'Assigned By'),
                        ),
                        SizedBox(height: 16.h),
                        CustomDatePicker(
                          controller: _workDateController,
                          label: 'Work Date',
                          hintText: 'When was this work done?',
                          prefixIcon: Icons.calendar_today_outlined,
                          initialDate: _workDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          onDateSelected: (picked) =>
                              setState(() => _workDate = picked),
                          validator: (v) =>
                              Validators.requiredField(v, 'Work Date'),
                        ),
                        SizedBox(height: 16.h),
                        LocationPicker(
                          addressController: _addressController,
                          latitude: _latitude,
                          longitude: _longitude,
                          editing: true,
                          showFullAddressCard: false,
                          onLocationChanged: _onLocationChanged,
                          addressValidator: (v) =>
                              Validators.requiredField(v, 'Address'),
                        ),
                        SizedBox(height: 20.h),
                        Row(
                          children: <Widget>[
                            Text(
                              'Work Image (Optional)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
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

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                    onPressed: onBack,
                    tooltip: 'Back',
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Text(
              'Add Miscellaneous Work',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 24.h),
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
            label: 'Submit',
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
