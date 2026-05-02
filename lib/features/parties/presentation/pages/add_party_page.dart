import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/parties/data/parties_repository.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/presentation/widgets/party_type_picker.dart';
import 'package:sales_sphere_erp/shared/utils/app_date_picker.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/location_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class AddPartyPage extends ConsumerStatefulWidget {
  const AddPartyPage({super.key});

  @override
  ConsumerState<AddPartyPage> createState() => _AddPartyPageState();
}

class _AddPartyPageState extends ConsumerState<AddPartyPage> {
  // Default camera target — Bengaluru. Replaced as soon as the user picks
  // a point or taps "use my current location".
  static const _defaultLat = 13.134965;
  static const _defaultLng = 77.566811;

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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _dateJoined ?? now,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _dateJoined = picked;
      _dateController.text = DateFormat.yMMMd().format(picked);
    });
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
      final repo = ref.read(partiesRepositoryProvider);
      final draft = Party(
        id: '', // assigned by the API mock
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        ownerName: _ownerController.text.trim().nullIfEmpty(),
        panVat: _panVatController.text.trim().nullIfEmpty(),
        phone: _phoneController.text.trim().nullIfEmpty(),
        email: _emailController.text.trim().nullIfEmpty(),
        dateJoined: _dateJoined,
        partyType: _partyType,
        notes: _notesController.text.trim().nullIfEmpty(),
        latitude: _latitude,
        longitude: _longitude,
        imagePaths: List<String>.unmodifiable(_imagePaths),
      );
      await repo.addParty(draft);
      ref.invalidate(partiesListProvider);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Party added.');
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
                    top: Radius.circular(28.r),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 24.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        PrimaryTextField(
                          controller: _nameController,
                          hintText: 'Party Name',
                          prefixIcon: Icons.business_outlined,
                          textInputAction: TextInputAction.next,
                          floatingLabel: true,
                          validator: (v) =>
                              Validators.requiredField(v, 'Party name'),
                        ),
                        SizedBox(height: 14.h),
                        PrimaryTextField(
                          controller: _ownerController,
                          hintText: 'Owner Name',
                          prefixIcon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          floatingLabel: true,
                          validator: (v) =>
                              Validators.requiredField(v, 'Owner name'),
                        ),
                        SizedBox(height: 14.h),
                        PrimaryTextField(
                          controller: _panVatController,
                          hintText: 'PAN/VAT Number',
                          prefixIcon: Icons.receipt_long_outlined,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          floatingLabel: true,
                          maxLength: 9,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: Validators.panVat,
                        ),
                        SizedBox(height: 14.h),
                        PrimaryTextField(
                          controller: _phoneController,
                          hintText: 'Phone Number',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          floatingLabel: true,
                          maxLength: 10,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: Validators.phone10,
                        ),
                        SizedBox(height: 14.h),
                        PrimaryTextField(
                          controller: _emailController,
                          hintText: 'Email Address',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          floatingLabel: true,
                          validator: Validators.emailOptional,
                        ),
                        SizedBox(height: 14.h),
                        // Date Joined — read-only, opens a date picker on tap.
                        GestureDetector(
                          onTap: _pickDate,
                          child: AbsorbPointer(
                            child: PrimaryTextField(
                              controller: _dateController,
                              hintText: 'Date Joined',
                              prefixIcon: Icons.calendar_today_outlined,
                              floatingLabel: true,
                              suffixWidget: Icon(
                                Icons.calendar_month_outlined,
                                color: AppColors.primary,
                                size: 20.sp,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 14.h),
                        PartyTypePicker(
                          value: _partyType,
                          enabled: true,
                          onChanged: (v) => setState(() => _partyType = v),
                        ),
                        SizedBox(height: 14.h),
                        PrimaryTextField(
                          controller: _notesController,
                          hintText: 'Notes',
                          prefixIcon: Icons.note_outlined,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          floatingLabel: true,
                        ),
                        SizedBox(height: 14.h),
                        LocationPicker(
                          addressController: _addressController,
                          latitude: _latitude,
                          longitude: _longitude,
                          editing: true,
                          onLocationChanged: _onLocationChanged,
                          addressValidator: (v) =>
                              Validators.requiredField(v, 'Address'),
                        ),
                        SizedBox(height: 18.h),
                        Row(
                          children: <Widget>[
                            Text(
                              'Party Image (Optional)',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_imagePaths.length}/$_maxImages',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        _ImagePickerStrip(
                          paths: _imagePaths,
                          maxImages: _maxImages,
                          onAdd: _pickImage,
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8.w, 4.h, 16.w, 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: AppColors.textWhite,
                  size: 24.sp,
                ),
                onPressed: onBack,
                tooltip: 'Back',
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'New member in the Family',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textWhite.withValues(alpha: 0.8),
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Add New Party',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 26.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the picked images side-by-side with a "tap to add" placeholder
/// in the next free slot. Supports up to [maxImages] entries.
class _ImagePickerStrip extends StatelessWidget {
  const _ImagePickerStrip({
    required this.paths,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> paths;
  final int maxImages;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final canAddMore = paths.length < maxImages;
    final tiles = <Widget>[
      for (int i = 0; i < paths.length; i++)
        Expanded(
          child: _ImageTile(
            path: paths[i],
            onClear: () => onRemove(i),
          ),
        ),
      if (canAddMore)
        Expanded(child: _AddImageTile(onTap: onAdd)),
    ];

    final separated = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) separated.add(SizedBox(width: 12.w));
      separated.add(tiles[i]);
    }
    return SizedBox(
      height: 150.h,
      child: Row(children: separated),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.path, required this.onClear});

  final String path;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.file(File(path), fit: BoxFit.cover),
          Positioned(
            top: 6.h,
            right: 6.w,
            child: Material(
              color: AppColors.overlay,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClear,
                child: Padding(
                  padding: EdgeInsets.all(6.w),
                  child: Icon(
                    Icons.close,
                    color: AppColors.textWhite,
                    size: 18.sp,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.add_photo_alternate_outlined,
              color: AppColors.textSecondary,
              size: 32.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              'Tap to add image',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
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
