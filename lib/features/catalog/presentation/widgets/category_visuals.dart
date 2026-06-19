import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Per-category icon + accent colour, keyed by category name.
///
/// Presentation-only mapping (kept out of the domain model) so the chip
/// row and the category-selection tiles read consistently. Ported from
/// v1's `_getCategoryIcon` / `_getCategoryColor` helpers — the accents
/// are category-identity colours, independent of the brand palette.
({IconData icon, Color accent}) categoryVisuals(String name) {
  switch (name.toLowerCase()) {
    case 'marble':
      return (icon: Icons.countertops, accent: const Color(0xFF8B4513));
    case 'paints':
      return (icon: Icons.format_paint, accent: const Color(0xFFE91E63));
    case 'sanitary':
      return (icon: Icons.bathroom, accent: const Color(0xFF2196F3));
    case 'cpvc':
      return (icon: Icons.plumbing, accent: const Color(0xFF4CAF50));
    case 'ply':
      return (icon: Icons.layers, accent: const Color(0xFFFF9800));
    case 'tiles':
      return (icon: Icons.grid_view_rounded, accent: const Color(0xFF00BCD4));
    default:
      return (icon: Icons.category, accent: AppColors.secondary);
  }
}
