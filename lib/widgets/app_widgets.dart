import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/screen_util.dart';

/// Reusable confirmation modal. Returns true only if the user confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline,
  Color confirmColor = AppColors.primary,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      ScreenUtil.init(ctx);

      return Dialog(
        backgroundColor: AppColors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: confirmColor.withAlpha(31),
                  ),
                  child: Icon(icon, size: 30.w, color: confirmColor),
                ),
                SizedBox(height: 18.h),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48.h,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            cancelLabel,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: SizedBox(
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: confirmColor,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            confirmLabel,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  return result ?? false;
}

/// Shared text field look (same as login/register).
/// `locked: true` greys the field out and adds a lock icon (read-only data).
InputDecoration appFieldDecoration(
  String label,
  IconData icon, {
  bool locked = false,
}) {
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
    prefixIcon: Icon(
      icon,
      size: 22.w,
      color: locked ? AppColors.textSecondary : AppColors.primary,
    ),
    suffixIcon: locked
        ? Icon(
            Icons.lock_outline,
            size: 20.w,
            color: AppColors.textSecondary,
          )
        : null,
    filled: true,
    fillColor: locked ? AppColors.disabledFill : AppColors.background,
    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
    border: border(Colors.transparent),
    enabledBorder: border(Colors.transparent),
    disabledBorder: border(Colors.transparent),
    focusedBorder: border(AppColors.primary, 1.6),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error, 1.6),
  );
}