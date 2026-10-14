import 'package:flutter/material.dart';

/// Keeps the app in the device's real logical coordinates.
///
/// Layouts respond to their own constraints instead of scaling a virtual
/// 360-pixel canvas. Preserve system text sizing and keyboard/safe-area metrics.
/// Only horizontal safe areas are applied here; each screen owns its header
/// and bottom inset so backgrounds can still extend behind the system bars.
class ResponsiveScale extends StatelessWidget {
  const ResponsiveScale({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        bottom: false,
        child: child,
      );
}
