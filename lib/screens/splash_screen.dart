import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_colors.dart';
import '../services/session_service.dart';
import '../utils/screen_util.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _greetingHold = Duration(milliseconds: 2200);
  static const _fadeOut = Duration(milliseconds: 350);

  String firstName = '';
  bool ready = false;
  bool leaving = false;
  bool showRing = false;

  @override
  void initState() {
    super.initState();

    // Ripple ring appears after the logo has popped in.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => showRing = true);
    });

    _start();
  }

  Future<void> _start() async {
    final session = await SessionService.getSession();
    if (!mounted) return;

    if (session == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() {
      firstName = session.firstName;
      ready = true;
    });

    await Future.delayed(_greetingHold);
    if (!mounted) return;

    setState(() => leaving = true);
    await Future.delayed(_fadeOut);
    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      session.role == 'admin' ? '/admin' : '/home',
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    final circleSize = 140.w;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedOpacity(
        opacity: leaving ? 0 : 1,
        duration: _fadeOut,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ===== DRIFTING BACKGROUND BLOBS =====
            _blob(
              top: -80.h,
              left: -100.w,
              size: 300.w,
              from: Offset(-20.w, -10.h),
              to: Offset(30.w, 30.h),
              duration: 3600.ms,
            ),
            _blob(
              bottom: -100.h,
              right: -110.w,
              size: 340.w,
              from: Offset(20.w, 10.h),
              to: Offset(-30.w, -30.h),
              duration: 4200.ms,
            ),

            // ===== CENTER CONTENT =====
            SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(circleSize),
                      SizedBox(height: 24.h),
                      _buildWordmark(),
                      SizedBox(height: 32.h),
                      // Reserved space so nothing jumps when the greeting
                      // appears.
                      SizedBox(
                        height: 84.h,
                        child: ready ? _buildGreeting() : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ===== LOADING BAR =====
            Positioned(
              left: 0,
              right: 0,
              bottom: 56.h,
              child: Center(child: _loadingBar()),
            ),
          ],
        ),
      ),
    );
  }

  // ===== LOGO =====
  Widget _buildLogo(double circleSize) {
    return SizedBox(
      width: circleSize,
      height: circleSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (showRing) _ring(circleSize),
          Container(
            width: circleSize,
            height: circleSize,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 28.r,
                  offset: Offset(0, 10.h),
                ),
              ],
            ),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.location_city,
                  size: 64.w,
                  color: AppColors.primary,
                );
              },
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(
                begin: const Offset(0.4, 0.4),
                end: const Offset(1, 1),
                duration: 900.ms,
                curve: Curves.easeOutBack,
              ),
        ],
      ),
    );
  }

  // ===== WORDMARK =====
  Widget _buildWordmark() {
    return Column(
      children: [
        Text(
          'CITIFIX',
          style: TextStyle(
            fontSize: 26.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 2,
          ),
        )
            .animate(delay: 500.ms)
            .fadeIn(duration: 500.ms)
            .slideY(
              begin: 0.5,
              end: 0,
              duration: 600.ms,
              curve: Curves.easeOutCubic,
            ),
        Text(
          'MANILA',
          style: TextStyle(
            fontSize: 13.sp,
            letterSpacing: 4,
            color: AppColors.textPrimary,
          ),
        )
            .animate(delay: 800.ms)
            .fadeIn(duration: 500.ms)
            .slideY(
              begin: 0.6,
              end: 0,
              duration: 500.ms,
              curve: Curves.easeOutCubic,
            ),
      ],
    );
  }

  // ===== GREETING =====
  Widget _buildGreeting() {
    final hasName = firstName.isNotEmpty;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              hasName ? 'Hello, ' : 'Hello!',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            )
                .animate()
                .fadeIn(duration: 450.ms)
                .slideY(
                  begin: 0.4,
                  end: 0,
                  duration: 450.ms,
                  curve: Curves.easeOutCubic,
                ),
            if (hasName)
              Flexible(
                child: Text(
                  firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                )
                    .animate(delay: 250.ms)
                    .fadeIn(duration: 450.ms)
                    .slideY(
                      begin: 0.4,
                      end: 0,
                      duration: 450.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          'Welcome back to CitiFix Manila',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            color: AppColors.textSecondary,
          ),
        )
            .animate(delay: 600.ms)
            .fadeIn(duration: 450.ms)
            .slideY(
              begin: 0.4,
              end: 0,
              duration: 450.ms,
              curve: Curves.easeOutCubic,
            ),
      ],
    );
  }

  // ===== BACKGROUND BLOB =====
  Widget _blob({
    double? top,
    double? left,
    double? bottom,
    double? right,
    required double size,
    required Offset from,
    required Offset to,
    required Duration duration,
  }) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryRing,
          ),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .move(
            begin: from,
            end: to,
            duration: duration,
            curve: Curves.easeInOut,
          ),
    );
  }

  // ===== RIPPLE RING =====
  Widget _ring(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.8, 1.8),
          duration: 2400.ms,
          curve: Curves.easeOut,
        )
        .fade(
          begin: 0.5,
          end: 0.0,
          duration: 2400.ms,
          curve: Curves.easeOut,
        );
  }

  // ===== LOADING BAR =====
  Widget _loadingBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.r),
      child: SizedBox(
        width: 120.w,
        height: 4.h,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: AppColors.primarySoft),
            ),
            Positioned.fill(
              child: const ColoredBox(color: AppColors.primary)
                  .animate(delay: 400.ms)
                  .scaleX(
                    begin: 0,
                    end: 1,
                    alignment: Alignment.centerLeft,
                    duration: 2200.ms,
                    curve: Curves.easeInOut,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}