import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_colors.dart';
import '../services/session_service.dart';
import '../utils/screen_util.dart';

class OpeningSplash extends StatefulWidget {
  const OpeningSplash({super.key});

  @override
  State<OpeningSplash> createState() => _OpeningSplashState();
}

class _OpeningSplashState extends State<OpeningSplash> {
  static const _minDisplay = Duration(milliseconds: 2600);
  static const _fadeOut = Duration(milliseconds: 350);

  String firstName = '';
  bool signedIn = false;
  bool leaving = false;
  int ringCount = 0;

  @override
  void initState() {
    super.initState();

    // Ripple rings appear after the logo has popped in.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => ringCount = 1);
    });
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => ringCount = 2);
    });

    _start();
  }

  Future<void> _start() async {
    final minDelay = Future.delayed(_minDisplay);
    String next = '/login';

    try {
      // Waits for Firebase to restore the persisted user.
      final user = await FirebaseAuth.instance.authStateChanges().first;

      if (user == null) {
        await SessionService.clearSession();
      } else {
        var session = await SessionService.getSession();

        if (session == null || session.uid != user.uid) {
          session = await SessionService.restoreFromFirebase(user);
        }

        final s = session;
        if (s != null) {
          next = s.role == 'admin' ? '/admin' : '/home';
          if (mounted) {
            setState(() {
              firstName = s.firstName;
              signedIn = true;
            });
          }
        }
      }
    } catch (_) {
      next = '/login';
    }

    await minDelay;
    if (!mounted) return;

    setState(() => leaving = true);
    await Future.delayed(_fadeOut);
    if (!mounted) return;

    Navigator.pushReplacementNamed(context, next);
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    final logoSize = 150.w;

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
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: logoSize,
                    height: logoSize,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        if (ringCount >= 1)
                          _ring(logoSize, const ValueKey('ring1')),
                        if (ringCount >= 2)
                          _ring(logoSize, const ValueKey('ring2')),
                        Image.asset(
                          'assets/logo.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.location_city,
                              size: logoSize * 0.6,
                              color: AppColors.primary,
                            );
                          },
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
                  ),
                  SizedBox(height: 28.h),

                  // CITIFIX: slides up while the letter spacing tightens.
                  Text(
                    'CITIFIX',
                    style: _wordmarkStyle(2),
                  )
                      .animate(delay: 700.ms)
                      .fadeIn(duration: 600.ms)
                      .slideY(
                        begin: 0.5,
                        end: 0,
                        duration: 700.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .custom(
                        duration: 700.ms,
                        curve: Curves.easeOutCubic,
                        begin: 14,
                        end: 2,
                        builder: (context, value, child) => Text(
                          'CITIFIX',
                          style: _wordmarkStyle(value),
                        ),
                      ),

                  Text(
                    'MANILA',
                    style: TextStyle(
                      fontSize: 16.sp,
                      letterSpacing: 4,
                      color: AppColors.textPrimary,
                    ),
                  )
                      .animate(delay: 1100.ms)
                      .fadeIn(duration: 600.ms)
                      .slideY(
                        begin: 0.6,
                        end: 0,
                        duration: 600.ms,
                        curve: Curves.easeOutCubic,
                      ),

                  // Reserved space so the layout doesn't jump when the
                  // greeting appears for signed-in users.
                  SizedBox(
                    height: 56.h,
                    child: signedIn ? _greeting() : null,
                  ),
                ],
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

  TextStyle _wordmarkStyle(double letterSpacing) {
    return TextStyle(
      fontSize: 36.sp,
      fontWeight: FontWeight.bold,
      color: AppColors.primary,
      letterSpacing: letterSpacing,
    );
  }

  Widget _greeting() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: firstName.isEmpty ? 'Hello!' : 'Hello, ',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            if (firstName.isNotEmpty)
              TextSpan(
                text: firstName,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      )
          .animate()
          .fadeIn(duration: 500.ms)
          .slideY(begin: 0.4, end: 0, duration: 500.ms),
    );
  }

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

  Widget _ring(double size, Key key) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
    )
        .animate(key: key, onPlay: (c) => c.repeat())
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.9, 1.9),
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
                  .animate(delay: 600.ms)
                  .scaleX(
                    begin: 0,
                    end: 1,
                    alignment: Alignment.centerLeft,
                    duration: 1900.ms,
                    curve: Curves.easeInOut,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}