import 'package:flutter/material.dart';

/// Shows a small floating notification that never covers image metadata or the
/// bottom navigation bar.
void showCompactSnackBar(
  BuildContext context, {
  required IconData icon,
  required String message,
  Duration duration = const Duration(milliseconds: 1600),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: duration,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
      ),
    );
}
