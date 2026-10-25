import 'package:flutter/material.dart';

/// Central color palette for CitiFix Manila.
/// Values are the same ones already used in the login/register screens.
class AppColors {
  AppColors._();

  // ===== BRAND =====
  static const Color primary = Colors.blue;
  static const Color background = Color(0xFFE8EEF7);
  static const Color white = Colors.white;

  // ===== TEXT =====
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;

  // ===== NEUTRALS =====
  static const Color disabledFill = Color(0xFFEEEEEE);
  static const Color border = Color(0xFFBDBDBD);

  // ===== FEEDBACK =====
  static const Color success = Colors.green;
  static const Color error = Colors.red;
  static const Color warning = Colors.orange;

  // ===== OPACITY VARIANTS =====
  /// primary @ 10%
  static const Color primarySoft = Color(0x1A2196F3);

  /// primary @ 20%
  static const Color primaryRing = Color(0x332196F3);

  /// black @ 10% – card/logo shadows
  static const Color shadow = Color(0x1A000000);
}