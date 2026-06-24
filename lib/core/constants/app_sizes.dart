import 'package:flutter/material.dart';

/// Application spacing, sizing, and layout constants
class AppSizes {
  AppSizes._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double iconLg = 32;

  /// Shared minimum height for the header (first) row of the list-row cards
  /// in the leaves / tour-plans / notes modules. Forcing every card's top
  /// row to the same height keeps the cards equal in total height regardless
  /// of whether that row carries a status pill, a leading icon, or neither.
  /// Applied with `.h` (flutter_screenutil) at the use site.
  static const double listRowHeaderHeight = 32;

  /// Shared minimum height for the *content* of the avatar-row list cards
  /// (parties / prospects / sites / miscellaneous-work) — the area inside the
  /// 14.h vertical padding. Matches the inner content height of the
  /// leaves / tour-plans / notes cards (header band + gap + bottom row), so
  /// every non-expense list card lands at the same total height. The leading
  /// avatar is shorter than this, so the floor — not the avatar — drives the
  /// card height, which also makes the cards equal regardless of avatar size.
  /// Applied with `.h` (flutter_screenutil) at the use site.
  static const double listCardContentHeight = 56;

  static const EdgeInsets screenPadding = EdgeInsets.all(md);
}
