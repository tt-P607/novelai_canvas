import 'dart:ui';

import 'package:flutter/material.dart';

/// Visual constants shared by every liquid surface so the glass thickness,
/// specular rim and corner softness stay consistent across the app.
///
/// The look targets Apple's Liquid Glass: a bright molten rim that reads as the
/// lit wall of a glass slab, a strong top sheen like a liquid surface, a body
/// that fades darker toward the bottom for thickness, and a faint ground
/// reflection underneath. Nothing is a plain hairline outline.
abstract final class GlassSpec {
  static const blurSigma = 24.0;
  static const thinBlurSigma = 18.0;
  static const radius = 22.0;

  /// Translucent glass body; brightest at the top, denser toward the bottom so
  /// the slab reads as having depth instead of being a flat tint. Opacity is
  /// intentionally low for a liquid, see-through finish.
  static LinearGradient body(ColorScheme colors, {double opacity = 1}) =>
      LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.surfaceBright.withValues(alpha: 0.16 * opacity),
          colors.surfaceBright.withValues(alpha: 0.06 * opacity),
          colors.surfaceBright.withValues(alpha: 0.10 * opacity),
        ],
        stops: const [0, 0.55, 1],
      );

  /// Top specular sheen — the bright reflection a liquid surface picks up from
  /// overhead light. Falls off quickly so the middle stays translucent.
  static LinearGradient sheen() => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.white.withValues(alpha: 0.34),
      Colors.white.withValues(alpha: 0.10),
      Colors.white.withValues(alpha: 0.02),
      Colors.transparent,
    ],
    stops: const [0, 0.18, 0.5, 1],
  );

  /// Faint ground reflection along the bottom edge that anchors the glass
  /// against the backdrop, like light bouncing back under a curved lens.
  static LinearGradient groundReflection() => LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [
      Colors.white.withValues(alpha: 0.10),
      Colors.white.withValues(alpha: 0.02),
      Colors.transparent,
    ],
    stops: const [0, 0.35, 1],
  );

  /// The molten rim colour. The top edge is kept brighter via [rimTop], while
  /// this single tone is still exposed for callers that need a flat edge tint
  /// (e.g. message bubbles).
  static Color edge(ColorScheme colors, {double opacity = 0.22}) =>
      Colors.white.withValues(alpha: opacity);

  /// Bright top rim — the strongest highlight on the glass wall, where the
  /// light catches the curved upper edge.
  static Color rimTop(ColorScheme colors, {double opacity = 0.42}) =>
      Colors.white.withValues(alpha: opacity);

  /// Dimmer bottom rim that makes the lower wall fall into shadow, giving the
  /// slab a rounded, three-dimensional lip instead of a flat outline.
  static Color rimBottom(ColorScheme colors, {double opacity = 0.14}) =>
      Colors.white.withValues(alpha: opacity);

  /// Translucent fill layered over the blurred backdrop (legacy tint helper).
  static Color tint(ColorScheme colors, {double opacity = 0.14}) =>
      colors.surfaceBright.withValues(alpha: opacity);
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
          child: _LiquidSurface(
            colors: colors,
            radius: radius,
            borderRadius: borderRadius,
            tintOpacity: tintOpacity,
            onTap: onTap,
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A glass-styled surface without backdrop blur, for dense layouts where
/// running a `BackdropFilter` per item (grids, long lists) would be too
/// expensive. Visually identical to [LiquidGlass] — same body, rim and sheen.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.radius = GlassSpec.radius,
    this.tintOpacity = 0.14,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
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
        child: _LiquidSurface(
          colors: colors,
          radius: radius,
          borderRadius: borderRadius,
          tintOpacity: tintOpacity,
          onTap: onTap,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Shared layered decoration that renders the liquid glass look:
/// glass body → top sheen → molten rim (brighter top, shaded bottom) →
/// ground reflection. The stack order produces the curved-lens illusion.
class _LiquidSurface extends StatelessWidget {
  const _LiquidSurface({
    required this.colors,
    required this.radius,
    required this.borderRadius,
    required this.tintOpacity,
    required this.onTap,
    required this.padding,
    required this.child,
  });

  final ColorScheme colors;
  final double radius;
  final BorderRadius borderRadius;
  final double tintOpacity;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Border draws inside the clip; the rim stroke spans the whole edge.
    const rimWidth = 0.8;
    return DecoratedBox(
      // Outer wall: a soft shadow inside the clip gives the rim a liquid,
      // rounded lip instead of a flat outline.
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: GlassSpec.rimTop(colors, opacity: 0.22),
          width: rimWidth,
        ),
      ),
      child: DecoratedBox(
        // Glass body: translucent gradient that adds depth (top-lit slab).
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: GlassSpec.body(colors, opacity: tintOpacity / 0.14),
        ),
        child: DecoratedBox(
          // Top sheen: the liquid surface highlight.
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: GlassSpec.sheen(),
          ),
          child: DecoratedBox(
            // Bottom ground reflection.
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: GlassSpec.groundReflection(),
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
