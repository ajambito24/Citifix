import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../utils/screen_util.dart';
import '../../widgets/app_widgets.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final authService = AuthService();
  final formKey = GlobalKey<FormState>();

  final currentController = TextEditingController();
  final newController = TextEditingController();
  final confirmController = TextEditingController();

  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirm = true;
  bool loading = false;

  @override
  void dispose() {
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  // ===== VALIDATORS =====
  String? validateCurrent(String? value) {
    if ((value ?? '').isEmpty) return 'Current password is required.';
    return null;
  }

  String? validateNew(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'New password is required.';
    if (v.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Include at least one letter and one number.';
    }
    if (v == currentController.text) {
      return 'New password must be different from the current one.';
    }
    return null;
  }

  String? validateConfirm(String? value) {
    if ((value ?? '').isEmpty) return 'Please confirm your new password.';
    if (value != newController.text) return 'Passwords do not match.';
    return null;
  }

  // ===== SUBMIT =====
  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    final confirmed = await showConfirmDialog(
      context,
      title: 'Change password?',
      message: "You'll use your new password the next time you log in.",
      confirmLabel: 'Change',
      icon: Icons.lock_reset,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      loading = true;
    });

    // Trimmed to match how passwords are handled at login/register.
    final error = await authService.changePassword(
      currentPassword: currentController.text.trim(),
      newPassword: newController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      loading = false;
    });

    if (error != null) {
      showMessage(error, isError: true);
      return;
    }

    showMessage('Password changed successfully');
    Navigator.pop(context);
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Change Password',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: SafeArea(
        child: ResponsiveBody(
          alignment: Alignment.topCenter,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Container(
            padding: EdgeInsets.all(22.w),
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
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64.w,
                      height: 64.w,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primarySoft,
                      ),
                      child: Icon(
                        Icons.lock_reset,
                        size: 32.w,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Update your password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Use at least 8 characters with a letter and a number.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  TextFormField(
                    controller: currentController,
                    obscureText: obscureCurrent,
                    style: TextStyle(fontSize: 15.sp),
                    decoration:
                        appFieldDecoration('Current Password', Icons.lock)
                            .copyWith(
                      suffixIcon: eyeToggle(obscureCurrent, () {
                        setState(() {
                          obscureCurrent = !obscureCurrent;
                        });
                      }),
                    ),
                    validator: validateCurrent,
                  ),
                  SizedBox(height: 16.h),
                  TextFormField(
                    controller: newController,
                    obscureText: obscureNew,
                    style: TextStyle(fontSize: 15.sp),
                    decoration:
                        appFieldDecoration('New Password', Icons.lock_outline)
                            .copyWith(
                      suffixIcon: eyeToggle(obscureNew, () {
                        setState(() {
                          obscureNew = !obscureNew;
                        });
                      }),
                    ),
                    validator: validateNew,
                  ),
                  SizedBox(height: 16.h),
                  TextFormField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    style: TextStyle(fontSize: 15.sp),
                    decoration: appFieldDecoration(
                      'Confirm New Password',
                      Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: eyeToggle(obscureConfirm, () {
                        setState(() {
                          obscureConfirm = !obscureConfirm;
                        });
                      }),
                    ),
                    validator: validateConfirm,
                  ),
                  SizedBox(height: 26.h),
                  SizedBox(
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: loading ? null : submit,
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
                              'UPDATE PASSWORD',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget eyeToggle(bool obscured, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(
        obscured ? Icons.visibility : Icons.visibility_off,
        size: 22.w,
        color: AppColors.textSecondary,
      ),
      onPressed: onPressed,
    );
  }
}