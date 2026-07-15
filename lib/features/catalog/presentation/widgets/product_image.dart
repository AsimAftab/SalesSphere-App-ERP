import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Product thumbnail with a colour-coded initials fallback.
///
/// Renders the network image when [imageUrl] is set (spinner while it
/// loads, initials on error); otherwise paints initials derived from
/// [name]. Ported from v1's `ProductImageWidget` (sans the full-screen
/// preview, which isn't needed for the catalog grid).
class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.name,
    this.imageUrl,
    this.borderRadius,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  /// Stable per-name palette — same name always maps to the same colour.
  static const _palette = <Color>[
    Color(0xFF6366F1), // Indigo
    Color(0xFFEC4899), // Pink
    Color(0xFF10B981), // Green
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF14B8A6), // Teal
    Color(0xFFEF4444), // Red
    Color(0xFF3B82F6), // Blue
  ];

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return trimmed.length > 1
        ? trimmed.substring(0, 2).toUpperCase()
        : trimmed[0].toUpperCase();
  }

  Color get _background => _palette[name.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12.r);
    final url = imageUrl;

    final Widget content;
    if (url != null && url.isNotEmpty) {
      content = ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: double.infinity,
          child: Image.network(
            url,
            fit: fit,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return ColoredBox(
                color: Colors.grey.shade100,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              );
            },
            errorBuilder: (context, error, stack) => _initialsBox(radius),
          ),
        ),
      );
    } else {
      content = _initialsBox(radius);
    }

    return Skeleton.replace(
      replacement: Bone(
        width: double.infinity,
        height: double.infinity,
        borderRadius: radius,
      ),
      child: content,
    );
  }

  Widget _initialsBox(BorderRadius radius) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _background.withValues(alpha: 0.85),
            _background,
          ],
        ),
        borderRadius: radius,
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: 26.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.15),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
