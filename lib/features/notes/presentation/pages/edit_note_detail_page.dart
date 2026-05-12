import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/notes/domain/note.dart';
import 'package:sales_sphere_erp/features/notes/presentation/controllers/notes_controller.dart';
import 'package:sales_sphere_erp/features/notes/presentation/providers/notes_providers.dart';
import 'package:sales_sphere_erp/features/notes/presentation/widgets/note_link_field.dart';
import 'package:sales_sphere_erp/features/notes/presentation/widgets/note_link_picker.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

class EditNoteDetailPage extends ConsumerStatefulWidget {
  const EditNoteDetailPage({required this.id, this.initial, super.key});

  final String id;

  /// Optional starting note passed via `extra` when navigating from
  /// the list — saves a re-fetch on first paint.
  final Note? initial;

  @override
  ConsumerState<EditNoteDetailPage> createState() => _EditNoteDetailPageState();
}

class _EditNoteDetailPageState extends ConsumerState<EditNoteDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final _nextFollowUpController = TextEditingController();

  static const _maxImages = 2;

  NoteLinkSelection? _link;
  DateTime? _createdAt;
  DateTime? _nextFollowUpAt;
  final List<String> _imagePaths = <String>[];

  bool _editing = false;
  bool _saving = false;
  bool _loading = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _populate(widget.initial!);
    } else {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }
  }

  /// Loads the note by awaiting the byId provider's future.
  Future<void> _hydrate() async {
    Note? note;
    try {
      note = await ref.read(noteByIdProvider(widget.id).future);
    } on Object catch (_) {
      // List failed; fall through to the not-found state below.
    }
    if (!mounted) return;
    if (note != null) {
      _populate(note);
      setState(() => _loading = false);
    } else {
      setState(() {
        _loading = false;
        _notFound = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _nextFollowUpController.dispose();
    super.dispose();
  }

  void _populate(Note n) {
    _titleController.text = n.title;
    _descriptionController.text = n.description;
    _link = NoteLinkSelection(
      type: n.linkType,
      id: n.linkId,
      displayName: n.linkDisplayName,
    );
    _createdAt = n.createdAt;
    _dateController.text = DateFormat('dd MMM yyyy').format(n.createdAt);
    _nextFollowUpAt = n.nextFollowUpAt;
    _nextFollowUpController.text = n.nextFollowUpAt == null
        ? ''
        : DateFormat('dd MMM yyyy').format(n.nextFollowUpAt!);
    _imagePaths
      ..clear()
      ..addAll(n.imagePaths);
  }

  void _toggleEdit() {
    setState(() => _editing = !_editing);
  }

  void _cancelEdit() {
    final saved = ref.read(noteByIdProvider(widget.id)).value ?? widget.initial;
    if (saved != null) _populate(saved);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _editing = false);
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

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final link = _link;
    if (link == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final updated = Note(
        id: widget.id,
        title: _titleController.text.trim(),
        linkType: link.type,
        linkId: link.id,
        linkDisplayName: link.displayName,
        description: _descriptionController.text.trim(),
        createdAt: _createdAt ?? DateTime.now(),
        imagePaths: List<String>.unmodifiable(_imagePaths),
        nextFollowUpAt: _nextFollowUpAt,
      );
      await ref.read(notesControllerProvider.notifier).updateNote(updated);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
      SnackbarUtils.showSuccess(context, 'Note updated successfully.');
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _DetailSkeleton(onBack: _back);
    if (_notFound) return const _NotFoundScaffold();
    ref.watch(noteByIdProvider(widget.id));

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
                        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            SectionCard(
                              children: <Widget>[
                                PrimaryTextField(
                                  controller: _titleController,
                                  label: 'Title',
                                  hintText: 'Enter note title',
                                  prefixIcon: Icons.title_rounded,
                                  minLines: 1,
                                  maxLines: 2,
                                  enabled: _editing,
                                  validator: (v) =>
                                      Validators.requiredField(v, 'Title'),
                                ),
                                SizedBox(height: 12.h),
                                NoteLinkField(
                                  value: _link,
                                  enabled: _editing,
                                  onChanged: (next) =>
                                      setState(() => _link = next),
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _descriptionController,
                                  label: 'Description',
                                  hintText: 'What happened on this visit?',
                                  prefixIcon: Icons.note_outlined,
                                  minLines: 1,
                                  maxLines: 6,
                                  enabled: _editing,
                                  validator: (v) => Validators.requiredField(
                                    v,
                                    'Description',
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                CustomDatePicker(
                                  controller: _nextFollowUpController,
                                  label: 'Next follow-up (Optional)',
                                  hintText: 'When to revisit',
                                  prefixIcon: Icons.event_outlined,
                                  enabled: _editing,
                                  initialDate: _nextFollowUpAt,
                                  // Block past dates — a follow-up in the
                                  // past is never what the user means.
                                  firstDate: DateTime.now(),
                                  onDateSelected: (picked) =>
                                      setState(() => _nextFollowUpAt = picked),
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _dateController,
                                  label: 'Created on',
                                  prefixIcon: Icons.calendar_today_outlined,
                                  enabled: false,
                                ),
                                SizedBox(height: 18.h),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      'Images',
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

// ── Header ─────────────────────────────────────────────────────────

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
          Text(
            'Details',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
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
                  fontSize: 15.sp,
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

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: DarkStatusBar(
        child: Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
                child: Bone(
                  width: double.infinity,
                  height: 60.h,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
          body: Stack(
            children: <Widget>[
              const _CurvedHeader(),
              SafeArea(
                child: Column(
                  children: <Widget>[
                    Padding(
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
                          Text(
                            'Details',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                        child: SectionCard(
                          children: <Widget>[
                            for (var i = 0; i < 3; i++) ...<Widget>[
                              if (i > 0) SizedBox(height: 12.h),
                              Bone(
                                width: double.infinity,
                                height: 56.h,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ],
                            SizedBox(height: 16.h),
                            Bone(
                              width: double.infinity,
                              height: 100.h,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          title: const Text('Details'),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              "Couldn't load this note — it may have been removed.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
            ),
          ),
        ),
      ),
    );
  }
}
