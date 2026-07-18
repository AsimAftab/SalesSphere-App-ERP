import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/notes/domain/note.dart';
import 'package:sales_sphere_erp/features/notes/domain/repositories/notes_repository.dart';
import 'package:sales_sphere_erp/features/notes/presentation/controllers/notes_controller.dart';
import 'package:sales_sphere_erp/features/notes/presentation/widgets/note_link_field.dart';
import 'package:sales_sphere_erp/features/notes/presentation/widgets/note_link_picker.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/add_form_header.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class AddNotePage extends ConsumerStatefulWidget {
  const AddNotePage({super.key});

  @override
  ConsumerState<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends ConsumerState<AddNotePage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const _maxImages = 2;

  NoteLinkSelection? _link;
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

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    final link = _link;
    if (link == null) return; // form validator already covers this
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      final draft = Note(
        id: '',
        // assigned by the API mock
        title: _titleController.text.trim(),
        linkType: link.type,
        linkId: link.id,
        linkDisplayName: link.displayName,
        description: _descriptionController.text.trim(),
        // Repository/API assigns the canonical createdAt — placeholder.
        createdAt: DateTime.now(),
        imagePaths: List<String>.unmodifiable(_imagePaths),
      );
      await ref.read(notesControllerProvider.notifier).addNote(draft);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Note added.');
      context.pop();
    } on PartialImageUploadException catch (e) {
      // Note was saved; one or more images didn't upload. Still pop
      // back — the user has a row to look at and can re-attach the
      // missing slots from the edit page.
      if (!mounted) return;
      final n = e.failedSlots.length;
      SnackbarUtils.showError(
        context,
        "Note added, but $n image${n == 1 ? '' : 's'} didn't upload: "
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
              title: 'Add Note',
              subtitle: 'Log the details of your visit',
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
                          controller: _titleController,
                          label: 'Title',
                          hintText: 'Enter note title',
                          prefixIcon: Icons.title_rounded,
                          minLines: 1,
                          maxLines: 2,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.requiredField(v, 'Title'),
                        ),
                        SizedBox(height: 16.h),
                        NoteLinkField(
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
