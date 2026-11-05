import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Usage:
///   1. Call `ScreenUtil.init(context)` at the top of each screen's build().
///   2. Use `16.w`, `16.h`, `16.sp`, `16.r` instead of fixed numbers.
///   3. Wrap scrollable screen content in `ResponsiveBody` so it stays
///      centered and capped to a readable width on tablets / web.
class ScreenUtil {
  ScreenUtil._();

  // Design baseline (standard phone artboard).
  static const double designWidth = 375;
  static const double designHeight = 812;

  // Content never stretches wider than this.
  static const double maxContentWidth = 480;

  // Breakpoints.
  static const double tabletBreakpoint = 600;
  static const double wideBreakpoint = 1024;

  static double screenWidth = designWidth;
  static double screenHeight = designHeight;
  static double _scaleW = 1;
  static double _scaleH = 1;

  static void init(BuildContext context) {
    final size = MediaQuery.of(context).size;
    screenWidth = size.width;
    screenHeight = size.height;

    // Scale against the content width (capped), so tablets don't blow up sizes.
    final contentWidth = math.min(screenWidth, maxContentWidth);
    _scaleW = (contentWidth / designWidth).clamp(0.8, 1.3).toDouble();
    _scaleH = (screenHeight / designHeight).clamp(0.75, 1.3).toDouble();
  }

  static bool get isPhone => screenWidth < tabletBreakpoint;
  static bool get isTablet =>
      screenWidth >= tabletBreakpoint && screenWidth < wideBreakpoint;
  static bool get isWide => screenWidth >= wideBreakpoint;

  /// Width-based size (horizontal padding, widths, icon sizes).
  static double w(double value) => value * _scaleW;

  /// Height-based size (vertical spacing, button heights).
  static double h(double value) => value * _scaleH;

  /// Font size (scaled, but kept in a readable range).
  static double sp(double value) =>
      value * _scaleW.clamp(0.85, 1.2).toDouble();

  /// Radius (follows width scale).
  static double r(double value) => value * _scaleW;
}

extension ScreenSize on num {
  double get w => ScreenUtil.w(toDouble());
  double get h => ScreenUtil.h(toDouble());
  double get sp => ScreenUtil.sp(toDouble());
  double get r => ScreenUtil.r(toDouble());
}

/// Scrollable, width-capped screen body.
/// - `Alignment.center` vertically centers short content (login).
/// - `Alignment.topCenter` keeps content at the top (multi-step forms).
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
    this.padding,
  });

  final Widget child;
  final Alignment alignment;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final pad = padding ??
        EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: pad,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0.0, constraints.maxHeight - pad.vertical),
            ),
            child: Align(
              alignment: alignment,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ScreenUtil.maxContentWidth,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}