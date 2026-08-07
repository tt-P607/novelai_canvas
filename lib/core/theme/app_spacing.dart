/// Spacing tokens shared by every page so vertical rhythm stays consistent
/// across the app instead of drifting into arbitrary pixel values.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Horizontal gutter for scrollable page content.
  static const pageHorizontal = lg;

  /// Bottom padding reserved for the floating navigation bar. Sized generously
  /// so the floating pill (72px + safe-area inset + margins) never overlaps the
  /// last card on devices with gesture navigation.
  static const navBarBottom = 180.0;
}
