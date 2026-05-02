import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Edge-to-edge image previewer. Renders the image centred on a black
/// background with pinch-to-zoom (`InteractiveViewer`) and a circular
/// close button anchored just below the status bar in the top-right.
///
/// Use [show] to open it; it pushes a transparent fade-in route so the
/// underlying page stays composited until the animation finishes.
class ImagePreview extends StatelessWidget {
  const ImagePreview({required this.imagePath, super.key});

  final String imagePath;

  static Future<void> show(BuildContext context, String imagePath) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => ImagePreview(imagePath: imagePath),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.black,
      // No SafeArea around the body so the image extends edge-to-edge,
      // covering the full screen — including the status-bar and gesture
      // areas. Only the close button respects the top inset.
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: Image.file(
                  File(imagePath),
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64.sp,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: topInset + 8.h,
            right: 8.w,
            child: Material(
              color: Colors.black.withValues(alpha: 0.5),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
