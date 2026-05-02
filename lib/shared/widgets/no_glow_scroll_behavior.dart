import 'package:flutter/material.dart';

/// Removes the Android overscroll glow without disabling the underlying
/// scroll behavior. The glow rectangle leaks past rounded card corners and
/// reads as an unwanted secondary background.
class NoGlowScrollBehavior extends ScrollBehavior {
  const NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
