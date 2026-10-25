import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/session_service.dart';
import '../utils/screen_util.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter email and password.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Unable to get logged-in user.');
      }

      String role = 'resident';
      Map<String, dynamic>? userData;

      // Find the user's Firestore profile by UID first.
      final uidDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (uidDoc.exists) {
        userData = uidDoc.data();
        role = userData?['role'] ?? 'resident';
      } else {
        // Supports your existing Firestore structure where
        // the document may be named "admin", "resident", etc.
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          userData = query.docs.first.data();
          role = userData['role'] ?? 'resident';
        }
      }

      // Cache the session so the user stays logged in across app restarts.
      await SessionService.saveSession(
        uid: user.uid,
        role: role.toLowerCase(),
        firstName: SessionService.firstNameFrom(userData),
      );

      if (!mounted) return;

      // Splash greets the user, then routes to /admin or /home by role.
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/splash',
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        default:
          message = e.message ?? 'Login failed.';
      }

      showMessage(message);
    } catch (e) {
      showMessage('Something went wrong: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 16.h),
              buildHeader(),
              SizedBox(height: 48.h),
              buildFormCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    // Larger logo that adapts to the screen height (about 190 on a typical phone).
    final logoSize =
        (ScreenUtil.screenHeight * 0.24).clamp(150.0, 230.0).toDouble();

    return Column(
      children: [
        // ===== LOGO =====
        Image.asset(
          'assets/logo.png', // <-- replace with your logo path
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback icon if logo is missing
            return Icon(
              Icons.location_city,
              size: logoSize * 0.5,
              color: AppColors.primary,
            );
          },
        ),
        SizedBox(height: 8.h),
        Text(
          'CITIFIX',
          style: TextStyle(
            fontSize: 32.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            letterSpacing: 1,
          ),
        ),
        Text(
          'MANILA',
          style: TextStyle(
            fontSize: 16.sp,
            letterSpacing: 3,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget buildFormCard() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontSize: 15.sp),
            decoration: fieldDecoration('Email', Icons.email),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            style: TextStyle(fontSize: 15.sp),
            decoration: fieldDecoration('Password', Icons.lock).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility : Icons.visibility_off,
                  size: 22.w,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
              ),
            ),
          ),
          SizedBox(height: 28.h),
          SizedBox(
            height: 52.h,
            child: ElevatedButton(
              onPressed: loading ? null : login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.primary,
                disabledForegroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: loading
                  ? SizedBox(
                      height: 22.w,
                      width: 22.w,
                      child: const CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'LOGIN',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterPage(),
                    ),
                  );
                },
                child: Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration fieldDecoration(String label, IconData icon) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 14.sp,
        color: AppColors.textSecondary,
      ),
      prefixIcon: Icon(icon, size: 22.w, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(AppColors.primary, 1.6),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 1.6),
    );
  }
}