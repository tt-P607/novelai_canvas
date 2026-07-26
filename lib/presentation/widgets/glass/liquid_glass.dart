import 'dart:ui';

import 'package:flutter/material.dart';

/// Visual constants shared by every frosted surface so blur radius, tint and
/// specular edges stay consistent across the app.
abstract final class GlassSpec {
  static const blurSigma = 24.0;
  static const thinBlurSigma = 18.0;
  static const radius = 22.0;

  /// Translucent fill layered over the blurred backdrop.
  static Color tint(ColorScheme colors, {double opacity = 0.14}) =>
      colors.surfaceBright.withValues(alpha: opacity);

  /// Bright hairline that reads as the lit edge of a glass slab.
  static Color edge(ColorScheme colors, {double opacity = 0.22}) =>
      Colors.white.withValues(alpha: opacity);

  /// Top-down sheen that gives the surface its liquid, curved-glass feel.
  static LinearGradient sheen() => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.16),
      Colors.white.withValues(alpha: 0.04),
      Colors.transparent,
    ],
    stops: const [0, 0.42, 1],
  );
}

/// A frosted panel that blurs whatever sits behind it.
///
/// Blur is expensive, so the filter is applied once per surface and the widget
/// clips to its own rounded rect to keep the sampling area minimal.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.radius = GlassSpec.radius,
    this.blurSigma = GlassSpec.blurSigma,
    this.tintOpacity = 0.14,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final double blurSigma;
  final double tintOpacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: GlassSpec.tint(colors, opacity: tintOpacity),
              border: Border.all(color: GlassSpec.edge(colors), width: 0.8),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: GlassSpec.sheen(),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: borderRadius,
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ambient colour field rendered behind the app so the glass has something to
/// refract. Without it the frosted panels would blur a flat colour and look
/// like plain translucent boxes.
class LiquidGlassBackdrop extends StatelessWidget {
  const LiquidGlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(decoration: BoxDecoration(color: colors.surface)),
        ),
        Positioned(
          top: -140,
          left: -90,
          child: _Orb(color: colors.primary, size: 380),
        ),
        Positioned(
          top: 180,
          right: -120,
          child: _Orb(color: colors.tertiary, size: 320),
        ),
        Positioned(
          bottom: -160,
          left: 20,
          child: _Orb(color: colors.secondary, size: 400),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
    ),
  );
}
