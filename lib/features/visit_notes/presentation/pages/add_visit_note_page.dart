import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/visit_notes/domain/visit_note.dart';
import 'package:sales_sphere_erp/features/visit_notes/presentation/controllers/visit_notes_controller.dart';
import 'package:sales_sphere_erp/features/visit_notes/presentation/widgets/visit_link_field.dart';
import 'package:sales_sphere_erp/features/visit_notes/presentation/widgets/visit_link_picker.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class AddVisitNotePage extends ConsumerStatefulWidget {
  const AddVisitNotePage({super.key});

  @override
  ConsumerState<AddVisitNotePage> createState() => _AddVisitNotePageState();
}

class _AddVisitNotePageState extends ConsumerState<AddVisitNotePage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const _maxImages = 2;

  VisitLinkSelection? _link;
  final List<String> _imagePaths = <String>[];
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    final link = _link;
    if (link == null) return; // form validator already covers this
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      final draft = VisitNote(
        id: '', // assigned by the API mock
        title: _titleController.text.trim(),
        linkType: link.type,
        linkId: link.id,
        linkDisplayName: link.displayName,
        description: _descriptionController.text.trim(),
        // Repository/API assigns the canonical createdAt — placeholder.
        createdAt: DateTime.now(),
        imagePaths: List<String>.unmodifiable(_imagePaths),
      );
      await ref
          .read(visitNotesControllerProvider.notifier)
          .addVisitNote(draft);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Visit note added.');
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
                          controller: _titleController,
                          label: 'Title',
                          hintText: 'Enter visit-note title',
                          prefixIcon: Icons.title_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.requiredField(v, 'Title'),
                        ),
                        SizedBox(height: 16.h),
                        VisitLinkField(
                          value: _link,
                          onChanged: (next) => setState(() => _link = next),
                          // `next` is nullable: the picker can clear
                          // the selection from inside the bottom sheet.
                        ),
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          hintText: 'What happened on this visit?',
                          prefixIcon: Icons.note_outlined,
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          validator: (v) =>
                              Validators.requiredField(v, 'Description'),
                        ),
                        SizedBox(height: 20.h),
                        Row(
                          children: <Widget>[
                            Text(
                              'Images (Optional)',
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
            SizedBox(height: 8.h),
            Text(
              "Capture today's visit",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Add Visit Note',
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
            label: 'Add Note',
            leadingIcon: Icons.add_circle_outline,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
