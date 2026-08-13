import 'dart:ui';
import 'package:flutter/material.dart';

/// A glassmorphism-styled card widget with backdrop blur and frosted appearance.
///
/// Used throughout the app for weather info overlays on top of the camera feed.
/// Follows the design spec: blur sigma 10, semi-transparent white fill,
/// rounded corners (24px), fine white border.
class GlassCard extends StatelessWidget {
  /// The content to display inside the glass card.
  final Widget child;

  /// Optional padding override (defaults to 20px all sides).
  final EdgeInsetsGeometry padding;

  /// Optional border radius override.
  final double borderRadius;

  /// Opacity of the white background fill (0.0 - 1.0).
  final double backgroundOpacity;

  /// Blur intensity for the backdrop filter.
  final double blurSigma;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.backgroundOpacity = 0.15,
    this.blurSigma = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(backgroundOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            // Subtle inner glow effect
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.05),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, -2),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: -5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
