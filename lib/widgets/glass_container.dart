import 'dart:ui';
import 'package:flutter/material.dart';

/// Full-bleed atmospheric aurora mesh background that sits behind screens
/// so that pure iOS GlassContainers refract luminous, ambient colors through their blur filters.
class AuroraBackground extends StatelessWidget {
  final Widget child;

  const AuroraBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Base canvas
        Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
          ),
        ),

        // 1. Top-Left: Luminous Royal Indigo & Electric Violet
        Positioned(
          top: -100,
          left: -80,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFF4F46E5) : const Color(0xFF818CF8))
                      .withValues(alpha: isDark ? 0.42 : 0.30),
                  (isDark ? const Color(0xFF7C3AED) : const Color(0xFFA78BFA))
                      .withValues(alpha: isDark ? 0.26 : 0.16),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // 2. Top-Right: Neon Cyan & Emerald Aqua
        Positioned(
          top: 60,
          right: -90,
          child: Container(
            width: 330,
            height: 330,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFF06B6D4) : const Color(0xFF22D3EE))
                      .withValues(alpha: isDark ? 0.35 : 0.24),
                  (isDark ? const Color(0xFF10B981) : const Color(0xFF34D399))
                      .withValues(alpha: isDark ? 0.20 : 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.52, 1.0],
              ),
            ),
          ),
        ),

        // 3. Mid-Left: Sunset Amber & Warm Coral
        Positioned(
          top: 380,
          left: -90,
          child: Container(
            width: 310,
            height: 310,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFFF59E0B) : const Color(0xFFFBBF24))
                      .withValues(alpha: isDark ? 0.28 : 0.18),
                  (isDark ? const Color(0xFFEF4444) : const Color(0xFFF87171))
                      .withValues(alpha: isDark ? 0.16 : 0.10),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),

        // 4. Bottom-Right: Radiant Rose & Deep Magenta
        Positioned(
          bottom: -80,
          right: -60,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFFEC4899) : const Color(0xFFF472B6))
                      .withValues(alpha: isDark ? 0.36 : 0.25),
                  (isDark ? const Color(0xFF8B5CF6) : const Color(0xFFC084FC))
                      .withValues(alpha: isDark ? 0.22 : 0.14),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // Top Content
        child,
      ],
    );
  }
}

/// A pure Apple iOS Frosted Glass container with high backdrop blur,
/// authentic translucency, and continuous corner specular hairlines.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? color;
  final Gradient? gradient;
  final Border? border;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.padding,
    this.margin,
    this.blur = 26.0,
    this.color,
    this.gradient,
    this.border,
    this.borderColor,
    this.borderWidth = 0.8,
    this.boxShadow,
    this.onTap,
    this.width,
    this.height,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Pure iOS Frosted Glass: High translucency, natural liquid refraction
    final defaultGlassColor = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.60);

    // Subtle Apple Specular Hairline (uniform across entire card & continuous corners)
    final defaultBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.65);

    final resolvedBorder = border ??
        Border.all(
          color: borderColor ?? defaultBorderColor,
          width: borderWidth,
        );

    final defaultShadow = boxShadow ??
        [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];

    final rRadius = BorderRadius.circular(borderRadius);

    Widget innerContent = child;
    if (padding != null) {
      innerContent = Padding(padding: padding!, child: innerContent);
    }

    if (onTap != null) {
      innerContent = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: rRadius,
          onTap: onTap,
          child: innerContent,
        ),
      );
    }

    return Container(
      margin: margin,
      width: width,
      height: height,
      alignment: alignment,
      decoration: BoxDecoration(
        borderRadius: rRadius,
        boxShadow: defaultShadow,
      ),
      child: ClipRRect(
        borderRadius: rRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color ?? (gradient == null ? defaultGlassColor : null),
              gradient: gradient,
              borderRadius: rRadius,
              border: resolvedBorder,
            ),
            child: innerContent,
          ),
        ),
      ),
    );
  }
}

/// A drop-in GlassCard replacing standard Material Card with Pure iOS Frosted Glass styling
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 22,
    this.onTap,
    this.color,
    this.gradient,
    this.borderColor,
    this.borderWidth = 0.8,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: margin,
      padding: padding,
      borderRadius: borderRadius,
      onTap: onTap,
      color: color,
      gradient: gradient,
      borderColor: borderColor,
      borderWidth: borderWidth,
      boxShadow: boxShadow,
      child: child,
    );
  }
}
