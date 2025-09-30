import 'package:flutter/material.dart';

/// Helper class for theme-aware color and styling utilities
class ThemeHelper {
  /// Get adaptive text color based on theme brightness
  static Color getAdaptiveTextColor(BuildContext context, {double opacity = 1.0}) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(opacity)
        : Colors.black87.withOpacity(opacity);
  }

  /// Get adaptive secondary text color
  static Color getAdaptiveSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB0B0B0)
        : const Color(0xFF757575);
  }

  /// Get adaptive card color
  static Color getAdaptiveCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2D2D2D)
        : Colors.white;
  }

  /// Get adaptive container color with opacity
  static Color getAdaptiveContainerColor(BuildContext context, {double opacity = 0.1}) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(opacity * 0.5)
        : Colors.black.withOpacity(opacity);
  }

  /// Get adaptive shadow color
  static Color getAdaptiveShadowColor(BuildContext context, {double opacity = 0.08}) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withOpacity(opacity * 3)
        : Colors.black.withOpacity(opacity);
  }

  /// Get adaptive divider color
  static Color getAdaptiveDividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF424242)
        : const Color(0xFFE0E0E0);
  }

  /// Get gradient colors that work in both themes
  static List<Color> getAdaptiveGradient(
    BuildContext context,
    List<Color> lightColors,
    List<Color> darkColors,
  ) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkColors
        : lightColors;
  }

  /// Create dark-mode aware LinearGradient
  static LinearGradient createAdaptiveGradient(
    BuildContext context, {
    required List<Color> lightColors,
    required List<Color> darkColors,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: Theme.of(context).brightness == Brightness.dark
          ? darkColors
          : lightColors,
    );
  }

  /// Get adaptive box decoration with shadow
  static BoxDecoration getAdaptiveBoxDecoration(
    BuildContext context, {
    Color? color,
    BorderRadius? borderRadius,
    bool withShadow = true,
    Gradient? gradient,
  }) {
    return BoxDecoration(
      color: color ?? getAdaptiveCardColor(context),
      gradient: gradient,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      boxShadow: withShadow
          ? [
              BoxShadow(
                color: getAdaptiveShadowColor(context, opacity: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ]
          : null,
    );
  }

  /// Common gradients for both themes
  static LinearGradient getPrimaryGradient(BuildContext context) {
    return createAdaptiveGradient(
      context,
      lightColors: const [Color(0xFF667EEA), Color(0xFF764BA2)],
      darkColors: const [Color(0xFF5A67D8), Color(0xFF6B46C1)],
    );
  }

  static LinearGradient getSuccessGradient(BuildContext context) {
    return createAdaptiveGradient(
      context,
      lightColors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
      darkColors: const [Color(0xFF0E8074), Color(0xFF2DD4BF)],
    );
  }

  static LinearGradient getWarningGradient(BuildContext context) {
    return createAdaptiveGradient(
      context,
      lightColors: const [Color(0xFFFFB75E), Color(0xFFED8F03)],
      darkColors: const [Color(0xFFEDA145), Color(0xFFD97706)],
    );
  }

  static LinearGradient getErrorGradient(BuildContext context) {
    return createAdaptiveGradient(
      context,
      lightColors: const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      darkColors: const [Color(0xFFEF4444), Color(0xFFF97316)],
    );
  }

  static LinearGradient getInfoGradient(BuildContext context) {
    return createAdaptiveGradient(
      context,
      lightColors: const [Color(0xFF56CCF2), Color(0xFF2F80ED)],
      darkColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    );
  }

  /// Get icon color with better contrast in dark mode
  static Color getAdaptiveIconColor(
    BuildContext context,
    Color baseColor, {
    bool onGradient = false,
  }) {
    if (onGradient) return Colors.white;
    
    return Theme.of(context).brightness == Brightness.dark
        ? baseColor.withOpacity(0.9)
        : baseColor;
  }

  /// Get button text style
  static TextStyle getAdaptiveButtonTextStyle(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.white,
    );
  }
}
