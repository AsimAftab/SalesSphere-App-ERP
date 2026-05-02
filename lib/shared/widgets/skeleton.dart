import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Single shimmer primitive used by skeleton loaders. Animates a soft
/// lighter band across a flat grey background. Cheap — no extra packages.
class Skeleton extends StatefulWidget {
  const Skeleton({
    required this.width,
    required this.height,
    super.key,
    this.borderRadius,
  });

  /// Convenience constructor for a fully-rounded pill skeleton.
  Skeleton.line({
    required double width,
    double height = 12,
    Key? key,
  }) : this(
          width: width,
          height: height,
          borderRadius: BorderRadius.circular(height / 2),
          key: key,
        );

  /// Convenience constructor for a circular avatar skeleton.
  Skeleton.circle({
    required double size,
    Key? key,
  }) : this(
          width: size,
          height: size,
          borderRadius: BorderRadius.all(Radius.circular(size / 2)),
          key: key,
        );

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Soft, low-contrast greys so the placeholder doesn't shout louder than
    // the surrounding card surface.
    const base = Color(0xFFE7EAF0);
    const highlight = Color(0xFFF1F3F7);
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8.r),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + t * 2, 0),
              end: Alignment(0.0 + t * 2, 0),
              colors: const <Color>[base, highlight, base],
              stops: const <double>[0, 0.5, 1],
            ),
          ),
        );
      },
    );
  }
}
