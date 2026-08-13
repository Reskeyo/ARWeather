import 'dart:ui';
import 'package:flutter/material.dart';

/// A capsule-shaped badge for displaying weather metrics (wind, rain, etc.).
///
/// Uses a pill shape with glassmorphism styling to match the app's design language.
class MetricBadge extends StatelessWidget {
  /// Icon to display (e.g. wind icon, rain drop).
  final IconData icon;

  /// The metric value text (e.g. "12 km/h").
  final String value;

  /// Label text displayed below the value (e.g. "Wind").
  final String label;

  /// Optional icon color override.
  final Color? iconColor;

  const MetricBadge({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: iconColor ?? Colors.white.withOpacity(0.9),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
