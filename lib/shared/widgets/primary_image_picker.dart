
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Stacked image picker for forms. Mixes:
/// - Local file paths in [imagePaths] (added via [onPick], removed via
///   [onRemove]) — rendered with [Image.file].
/// - Existing remote URLs in [networkImageUrls] (or [networkImageUrl] for
///   a single legacy URL) — rendered with [Image.network] with a
///   layout-stable error state. Removed via [onRemoveNetwork] or replaced
///   via [onReplaceNetwork] / [onReplace].
///
/// Renders an empty drop-zone when nothing is attached, full-width
/// thumbnails for each existing image, and an "add more" tile while
/// below [maxImages]. Tapping a thumbnail opens an [InteractiveViewer]
/// dialog with pinch-to-zoom and drag-to-pan.
///
/// `[networkImageUrls]` takes precedence over `[networkImageUrl]` when
/// both are passed. Single-URL legacy mode hides the network image once a
/// local upload arrives (treated as a replacement); the explicit list
/// keeps remote and local images side-by-side.
class PrimaryImagePicker extends StatelessWidget {
  const PrimaryImagePicker({
    required this.imagePaths,
    required this.onPick,
    required this.onRemove,
    super.key,
    this.networkImageUrl,
    this.networkImageUrls,
    this.maxImages = 1,
    this.label,
    this.hintText,
    this.onReplace,
    this.onReplaceNetwork,
    this.onRemoveNetwork,
    this.enabled = true,
    this.showLabel = true,
  });

  final List<String> imagePaths;
  final String? networkImageUrl;
  final List<String>? networkImageUrls;
  final int maxImages;
  final String? label;
  final String? hintText;
  final VoidCallback onPick;
  final void Function(int index) onRemove;
  final VoidCallback? onReplace;
  final void Function(int index)? onReplaceNetwork;
  final void Function(int index)? onRemoveNetwork;
  final bool enabled;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final hasLocalImages = imagePaths.isNotEmpty;
    final resolvedNetworkUrls =
        networkImageUrls ??
        ((networkImageUrl != null && networkImageUrl!.isNotEmpty)
            ? <String>[networkImageUrl!]
            : const <String>[]);
    final isExplicitNetworkList = networkImageUrls != null;
    final showNetworkImages = isExplicitNetworkList
        ? resolvedNetworkUrls.isNotEmpty
        : (resolvedNetworkUrls.isNotEmpty && !hasLocalImages);
    final visibleNetworkCount = showNetworkImages
        ? resolvedNetworkUrls.length
        : 0;
    final totalCount = imagePaths.length + visibleNetworkCount;
    final hasAnyImage = totalCount > 0;
    final canAddMore = enabled && totalCount < maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null && showLabel) ...<Widget>[
          Text(
            label!,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        for (var i = 0; i < visibleNetworkCount; i++)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: _NetworkThumbnail(
              imageUrl: resolvedNetworkUrls[i],
              index: i,
              isSingleImage: maxImages == 1 && visibleNetworkCount == 1,
              enabled: enabled,
              onRemoveNetwork: onRemoveNetwork,
              onReplaceNetwork: onReplaceNetwork,
              onReplace: onReplace,
            ),
          ),
        for (var i = 0; i < imagePaths.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: _LocalThumbnail(
              path: imagePaths[i],
              index: i,
              isSingleImage: maxImages == 1,
              enabled: enabled,
              onRemove: onRemove,
            ),
          ),
        if (maxImages > 1 && canAddMore && hasAnyImage) ...<Widget>[
          SizedBox(height: 8.h),
          _AddMoreTile(
            currentCount: totalCount,
            maxImages: maxImages,
            onPick: onPick,
          ),
        ],
        if (!hasAnyImage)
          _EmptyDropZone(
            enabled: enabled,
            maxImages: maxImages,
            currentCount: imagePaths.length,
            hintText: hintText,
            onPick: onPick,
          ),
      ],
    );
  }
}

class _EmptyDropZone extends StatelessWidget {
  const _EmptyDropZone({
    required this.enabled,
    required this.maxImages,
    required this.currentCount,
    required this.hintText,
    required this.onPick,
  });

  final bool enabled;
  final int maxImages;
  final int currentCount;
  final String? hintText;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final isSingle = maxImages == 1;
    // Read-only / view mode with no images attached — render a plain
    // "no image attached" placeholder instead of an "add image"
    // dropzone that looks tappable but isn't.
    if (!enabled) {
      return Container(
        height: isSingle ? 120.h : 100.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.image_not_supported_outlined,
              size: isSingle ? 40.sp : 32.sp,
              color: AppColors.textDisabled,
            ),
            SizedBox(height: isSingle ? 8.h : 4.h),
            Text(
              'No image attached',
              style: TextStyle(fontSize: 12.sp, color: AppColors.textDisabled),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: isSingle ? 120.h : 100.h,
        width: double.infinity,
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
              size: isSingle ? 40.sp : 32.sp,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: isSingle ? 8.h : 4.h),
            Text(
              hintText ??
                  (isSingle
                      ? 'Tap to add image'
                      : 'Tap to add image ($currentCount/$maxImages)'),
              style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMoreTile extends StatelessWidget {
  const _AddMoreTile({
    required this.currentCount,
    required this.maxImages,
    required this.onPick,
  });

  final int currentCount;
  final int maxImages;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 100.h,
        width: double.infinity,
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
              size: 32.sp,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 4.h),
            Text(
              'Tap to add image ($currentCount/$maxImages)',
              style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalThumbnail extends StatelessWidget {
  const _LocalThumbnail({
    required this.path,
    required this.index,
    required this.isSingleImage,
    required this.enabled,
    required this.onRemove,
  });

  final String path;
  final int index;
  final bool isSingleImage;
  final bool enabled;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    final height = isSingleImage ? 200.h : 140.h;
    return GestureDetector(
      onTap: () => showPrimaryImagePreview(context, FileImage(File(path))),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Image.file(
                File(path),
                width: double.infinity,
                height: height,
                fit: BoxFit.cover,
              ),
            ),
            _PreviewBadge(isSingleImage: isSingleImage),
            if (enabled)
              Positioned(
                top: 8.h,
                right: 8.w,
                child: _OverlayButton(
                  icon: Icons.close,
                  size: isSingleImage ? 20.sp : 16.sp,
                  padding: isSingleImage ? 6.w : 4.w,
                  onTap: () => onRemove(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NetworkThumbnail extends StatelessWidget {
  const _NetworkThumbnail({
    required this.imageUrl,
    required this.index,
    required this.isSingleImage,
    required this.enabled,
    required this.onRemoveNetwork,
    required this.onReplaceNetwork,
    required this.onReplace,
  });

  final String imageUrl;
  final int index;
  final bool isSingleImage;
  final bool enabled;
  final void Function(int)? onRemoveNetwork;
  final void Function(int)? onReplaceNetwork;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    final height = isSingleImage ? 200.h : 140.h;
    return GestureDetector(
      onTap: () => showPrimaryImagePreview(
        context,
        CachedNetworkImageProvider(imageUrl),
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: height,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _NetworkErrorBox(height: height),
              ),
            ),
            _PreviewBadge(isSingleImage: isSingleImage),
            if (enabled)
              Positioned(
                top: 8.h,
                right: 8.w,
                child: _OverlayButton(
                  icon: onRemoveNetwork != null ? Icons.close : Icons.edit,
                  size: 20.sp,
                  padding: 6.w,
                  onTap: () {
                    if (onRemoveNetwork != null) {
                      onRemoveNetwork!(index);
                    } else if (onReplaceNetwork != null) {
                      onReplaceNetwork!(index);
                    } else {
                      onReplace?.call();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NetworkErrorBox extends StatelessWidget {
  const _NetworkErrorBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.broken_image_outlined,
            size: 40.sp,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 8.h),
          Text(
            'Failed to load image',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.isSingleImage});

  final bool isSingleImage;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 8.h,
      right: 8.w,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSingleImage ? 12.w : 10.w,
          vertical: isSingleImage ? 6.h : 4.h,
        ),
        decoration: BoxDecoration(
          color: AppColors.overlay,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.zoom_in,
              color: AppColors.textWhite,
              size: isSingleImage ? 16.sp : 14.sp,
            ),
            SizedBox(width: 4.w),
            Text(
              isSingleImage ? 'Tap to preview' : 'Preview',
              style: TextStyle(color: AppColors.textWhite, fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.size,
    required this.padding,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final double padding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: AppColors.overlay,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.textWhite, size: size),
      ),
    );
  }
}

void showPrimaryImagePreview(BuildContext context, ImageProvider provider) {
  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final size = MediaQuery.of(dialogContext).size;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(16.w),
        child: Stack(
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: size.height * 0.8,
                maxWidth: size.width,
              ),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Image(
                    image: provider,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        _NetworkErrorBox(height: size.height * 0.4),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: AppColors.textWhite,
                    size: 24.sp,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16.h,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    'Pinch to zoom • Drag to pan',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Gallery + camera bottom sheet that returns the picked file. Use as
/// `final file = await showImagePickerSheet(context);`. Returns `null`
/// when the user dismisses the sheet without picking. Quality is capped
/// at 70 by default to keep upload sizes reasonable.
Future<XFile?> showImagePickerSheet(
  BuildContext context, {
  int imageQuality = 70,
  double? maxWidth,
  double? maxHeight,
  bool cameraOnly = false,
}) async {
  final source = cameraOnly
      ? ImageSource.camera
      : await showModalBottomSheet<ImageSource>(
          context: context,
          backgroundColor: AppColors.surface,
          barrierColor: Colors.black.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
          ),
          builder: (BuildContext sheetContext) => SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(30.w, 26.h, 30.w, 36.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Choose Image Source',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 28.h),
                  _ImageSourceOptionTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => sheetContext.pop(ImageSource.camera),
                  ),
                  SizedBox(height: 20.h),
                  _ImageSourceOptionTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => sheetContext.pop(ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        );

  if (source == null) return null;

  return ImagePicker().pickImage(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
  );
}

class _ImageSourceOptionTile extends StatelessWidget {
  const _ImageSourceOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: Row(
          children: <Widget>[
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                color: const Color(0xFFE9EEF4),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20.sp),
            ),
            SizedBox(width: 16.w),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
