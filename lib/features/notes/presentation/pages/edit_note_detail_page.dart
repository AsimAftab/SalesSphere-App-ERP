import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/notes/data/dto/note_image_ref.dart';
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

  /// Local file paths picked in this edit session — uploaded to free
  /// slots in `_save`.
  final List<String> _imagePaths = <String>[];

  /// Server-side images at the moment we render. Mutated as the user
  /// removes thumbnails; `_originalExistingImages` is the snapshot
  /// used by cancel to restore.
  List<NoteImageRef> _existingImages = const <NoteImageRef>[];
  List<NoteImageRef> _originalExistingImages = const <NoteImageRef>[];

  /// Slot numbers (1-indexed) the user asked to delete in this edit
  /// session. Drained in `_save` before uploading new locals so the
  /// freed slots become available targets.
  final Set<int> _slotsToDelete = <int>{};

  bool _editing = false;
  bool _saving = false;
  bool _loading = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _populate(widget.initial!);
      // Fields populate synchronously, but the gallery still needs a
      // fetch — kick it off after first frame so the picker fills in.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hydrateImages();
        _hydrateLinkName();
      });
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
      await _hydrateImages();
      await _hydrateLinkName();
    } else {
      setState(() {
        _loading = false;
        _notFound = true;
      });
    }
  }

  /// Fetch the gallery so the picker shows server-side images.
  /// Failures are swallowed — an empty picker is graceful degradation.
  Future<void> _hydrateImages() async {
    try {
      final images =
          await ref.read(notesRepositoryProvider).listImages(widget.id);
      if (!mounted) return;
      setState(() {
        _existingImages = images;
        _originalExistingImages = List<NoteImageRef>.unmodifiable(images);
      });
    } on Object catch (_) {
      // Not fatal — picker stays empty on the network image side and
      // the user can still pick new locals.
    }
  }

  /// Resolve the real linked-entity name (Party / Prospect / Site)
  /// and patch [_link] so the `NoteLinkField` shows the actual party,
  /// prospect, or site name instead of the generic fallback the wire
  /// shape forces on us. No-op when the lookup misses (the fallback
  /// stays).
  Future<void> _hydrateLinkName() async {
    final current = _link;
    if (current == null || current.id.isEmpty) return;
    try {
      final name = await ref.read(
        noteLinkDisplayNameProvider(current.type, current.id).future,
      );
      if (!mounted) return;
      // Avoid a needless rebuild when the resolver returned the same
      // string we already had (e.g. lookup miss → fallback label).
      if (name == current.displayName) return;
      setState(() {
        _link = NoteLinkSelection(
          type: current.type,
          id: current.id,
          displayName: name,
        );
      });
    } on Object catch (_) {
      // Fallback already in place; nothing to do.
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
    // The wire ships UTC (`Z`-suffixed); show the user their local
    // wall time so "10:30 AM" matches what they actually wrote.
    _dateController.text =
        DateFormat('dd MMM yyyy, hh:mm a').format(n.createdAt.toLocal());
    _nextFollowUpAt = n.nextFollowUpAt;
    _nextFollowUpController.text = n.nextFollowUpAt == null
        ? ''
        : DateFormat('dd MMM yyyy').format(n.nextFollowUpAt!.toLocal());
    _imagePaths.clear();
  }

  void _toggleEdit() {
    setState(() => _editing = !_editing);
  }

  void _cancelEdit() {
    final saved = ref.read(noteByIdProvider(widget.id)).value ?? widget.initial;
    if (saved != null) _populate(saved);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _editing = false;
      // Roll back image edits: restore server-side gallery, drop any
      // queued deletions and any local picks.
      _existingImages = List<NoteImageRef>.from(_originalExistingImages);
      _slotsToDelete.clear();
      _imagePaths.clear();
    });
  }

  int get _totalAttachedImages =>
      _imagePaths.length + _existingImages.length;

  Future<void> _pickImage() async {
    if (!_editing || _totalAttachedImages >= _maxImages) return;
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

  /// Queue the existing image at [index] (in the current
  /// `_existingImages` list) for deletion. Removed from the picker
  /// immediately; the actual DELETE fires on save.
  void _removeExistingImageAt(int index) {
    if (!_editing) return;
    setState(() {
      final removed = _existingImages[index];
      _existingImages = List<NoteImageRef>.from(_existingImages)
        ..removeAt(index);
      _slotsToDelete.add(removed.slot);
    });
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
        // imagePaths is left at its default (empty) — local picks are
        // uploaded separately via _syncImageChanges, the PATCH body
        // doesn't carry filesystem paths.
        nextFollowUpAt: _nextFollowUpAt,
      );
      await ref.read(notesControllerProvider.notifier).updateNote(updated);
      final imageResult = await _syncImageChanges();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
        _imagePaths.clear();
        _slotsToDelete.clear();
      });
      // Re-fetch the now-current gallery to refresh the picker's
      // network thumbnails (new slot URLs + the original snapshot).
      await _hydrateImages();
      if (!mounted) return;
      if (imageResult.uploadFailures > 0 ||
          imageResult.deleteFailures > 0) {
        SnackbarUtils.showError(
          context,
          _formatImageSyncWarning(imageResult),
        );
      } else {
        SnackbarUtils.showSuccess(context, 'Note updated successfully.');
      }
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    }
  }

  /// Drains [_slotsToDelete] first (frees up slots), then uploads each
  /// new local file into the next free slot. Returns per-bucket
  /// failure counts + the first backend error message we ran into,
  /// so [_save] can show a snackbar that says *why* something failed
  /// (not just how many). The note PATCH already succeeded by the
  /// time this runs, so failures are non-fatal — the user can retry
  /// the missing slot on a subsequent edit.
  Future<({int uploadFailures, int deleteFailures, String? firstError})>
      _syncImageChanges() async {
    if (_slotsToDelete.isEmpty && _imagePaths.isEmpty) {
      return (uploadFailures: 0, deleteFailures: 0, firstError: null);
    }
    final repo = ref.read(notesRepositoryProvider);
    var deleteFailures = 0;
    String? firstError;
    for (final slot in _slotsToDelete) {
      try {
        await repo.removeImage(noteId: widget.id, slot: slot);
      } on Object catch (e) {
        deleteFailures++;
        firstError ??= extractBackendErrorMessage(e) ?? 'Delete failed';
      }
    }
    final keptSlots = _existingImages.map((e) => e.slot).toSet();
    final freeSlots = <int>[
      for (var s = 1; s <= _maxImages; s++)
        if (!keptSlots.contains(s)) s,
    ];
    var uploadFailures = 0;
    for (var i = 0; i < _imagePaths.length && i < freeSlots.length; i++) {
      try {
        await repo.uploadImage(
          noteId: widget.id,
          filePath: _imagePaths[i],
          slot: freeSlots[i],
        );
      } on Object catch (e) {
        uploadFailures++;
        firstError ??= extractBackendErrorMessage(e) ?? 'Upload failed';
      }
    }
    return (
      uploadFailures: uploadFailures,
      deleteFailures: deleteFailures,
      firstError: firstError,
    );
  }

  String _formatImageSyncWarning(
    ({int uploadFailures, int deleteFailures, String? firstError}) r,
  ) {
    final parts = <String>[];
    if (r.uploadFailures > 0) {
      parts.add(
        "${r.uploadFailures} image${r.uploadFailures == 1 ? '' : 's'} "
        "didn't upload",
      );
    }
    if (r.deleteFailures > 0) {
      parts.add(
        "${r.deleteFailures} image${r.deleteFailures == 1 ? '' : 's'} "
        "couldn't be removed",
      );
    }
    final summary = 'Saved with issues: ${parts.join(', ')}';
    return r.firstError == null ? '$summary.' : '$summary — ${r.firstError}.';
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
                                  // Block past dates — a follow-up in
                                  // the past is never what the user
                                  // means.
                                  firstDate: DateTime.now(),
                                  onDateSelected: (picked) =>
                                      setState(() => _nextFollowUpAt = picked),
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _dateController,
                                  label: 'Created On',
                                  prefixIcon: Icons.access_time_rounded,
                                  enabled: false,
                                  readOnly: true,
                                ),
                                SizedBox(height: 18.h),
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
                                      '$_totalAttachedImages/$_maxImages',
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
                                  networkImageUrls: _existingImages
                                      .map((e) => e.url)
                                      .toList(growable: false),
                                  onRemoveNetwork: _removeExistingImageAt,
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
                  fontSize: 16.sp,
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
