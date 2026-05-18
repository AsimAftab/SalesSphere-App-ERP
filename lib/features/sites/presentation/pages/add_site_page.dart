import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/sites/domain/repositories/sites_repository.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';
import 'package:sales_sphere_erp/features/sites/domain/site_contact.dart';
import 'package:sales_sphere_erp/features/sites/domain/sub_organization.dart';
import 'package:sales_sphere_erp/features/sites/presentation/controllers/sites_controller.dart';
import 'package:sales_sphere_erp/features/sites/presentation/providers/sites_providers.dart';
import 'package:sales_sphere_erp/features/sites/presentation/widgets/site_contact_picker.dart';
import 'package:sales_sphere_erp/features/sites/presentation/widgets/sub_organization_picker.dart';
import 'package:sales_sphere_erp/shared/domain/interest.dart';
import 'package:sales_sphere_erp/shared/domain/interest_catalogue.dart';
import 'package:sales_sphere_erp/shared/utils/image_validation.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/interest_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/location_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class AddSitePage extends ConsumerStatefulWidget {
  const AddSitePage({super.key});

  @override
  ConsumerState<AddSitePage> createState() => _AddSitePageState();
}

class _AddSitePageState extends ConsumerState<AddSitePage> {
  // Default camera target — Kathmandu. Replaced as soon as the user picks
  // a point or taps "use my current location".
  static const _defaultLat = 27.7172;
  static const _defaultLng = 85.3240;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();

  static const _maxImages = 2;

  List<Interest> _interests = const <Interest>[];
  List<SiteContact> _contacts = const <SiteContact>[];
  String? _subOrganizationId;
  DateTime? _dateJoined;
  double _latitude = _defaultLat;
  double _longitude = _defaultLng;
  final List<String> _imagePaths = <String>[];
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
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

  /// Looks up the display name for [_subOrganizationId] from the
  /// currently-loaded catalogue. Used at submit time so the POST body
  /// carries `subOrganizationName` (the server resolves the id +
  /// auto-upserts).
  String? _resolveSubOrgName() {
    final id = _subOrganizationId;
    if (id == null) return null;
    final orgs = ref.read(siteSubOrganizationsProvider).value ??
        const <SubOrganization>[];
    for (final org in orgs) {
      if (org.id == id) return org.name;
    }
    return null;
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
      final draft = Site(
        id: '', // assigned by the server on create
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        ownerName: _ownerController.text.trim(),
        phone: _phoneController.text.trim(),
        subOrganizationId: _subOrganizationId,
        subOrganizationName: _resolveSubOrgName(),
        email: _emailController.text.trim().nullIfEmpty(),
        dateJoined: _dateJoined,
        interests: List<Interest>.unmodifiable(_interests),
        contacts: List<SiteContact>.unmodifiable(_contacts),
        notes: _notesController.text.trim().nullIfEmpty(),
        latitude: _latitude,
        longitude: _longitude,
        imagePaths: List<String>.unmodifiable(_imagePaths),
      );
      await ref.read(sitesControllerProvider.notifier).addSite(draft);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Site added successfully.');
      context.pop();
    } on PartialSiteImageUploadException catch (e) {
      // Site was saved; one or more images didn't upload. Still pop
      // back — the user has a row to look at and can re-attach the
      // missing slots from the edit page.
      if (!mounted) return;
      final n = e.failedSlots.length;
      SnackbarUtils.showError(
        context,
        "Site added, but $n image${n == 1 ? '' : 's'} didn't upload: "
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
                          controller: _nameController,
                          label: 'Site Name',
                          hintText: 'Enter site name',
                          prefixIcon: Icons.business_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.requiredField(v, 'Site name'),
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
                        SubOrganizationPicker(
                          value: _subOrganizationId,
                          onChanged: (next) =>
                              setState(() => _subOrganizationId = next),
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
                        Consumer(
                          builder: (context, ref, _) {
                            final catalogueAsync = ref.watch(
                              siteInterestsProvider,
                            );
                            return InterestPicker(
                              value: _interests,
                              catalogue: catalogueAsync.value ??
                                  InterestCatalogue.empty(),
                              enabled: true,
                              label: 'Site Interest',
                              hintText: 'Select site interest',
                              onChanged: (next) =>
                                  setState(() => _interests = next),
                              // POST /sites auto-upserts unknown
                              // categories + brands when they appear in
                              // the interests body. No separate write
                              // round-trip needed; the picker already
                              // adds them to its in-sheet catalogue and
                              // the user's selection.
                              onAddCategory: (_) {},
                              onAddBrand: (_, __) {},
                            );
                          },
                        ),
                        SizedBox(height: 16.h),
                        SiteContactPicker(
                          value: _contacts,
                          enabled: true,
                          onChanged: (next) =>
                              setState(() => _contacts = next),
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
                              'Site Image (Optional)',
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
            SizedBox(height: 8.h),
            Text(
              'New Site Incoming',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Add New Site',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 32.h),
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
            label: 'Add Site',
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
