import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/sampaloc_barangays.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../utils/screen_util.dart';
import '../widgets/barangay_sheet.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final authService = AuthService();

  // ===== STEP STATE =====
  int step = 0;
  static const stepTitles = ['Personal', 'Address', 'Security'];

  final personalFormKey = GlobalKey<FormState>();
  final addressFormKey = GlobalKey<FormState>();
  final securityFormKey = GlobalKey<FormState>();

  // ===== CONTROLLERS =====
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final mobileController = TextEditingController();
  final emailController = TextEditingController();

  final streetController = TextEditingController();
  final barangayController = TextEditingController();

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // ===== TERMS =====
  bool agreedToTerms = false;

  bool obscurePassword = true;
  bool obscureConfirm = true;
  bool loading = false;

  // Display only. The backend sets the saved city value by itself.
  static const String cityName = 'District 4, City of Manila';
  static const String cityHelper = 'Sampaloc, Barangays 395 to 586';

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    mobileController.dispose();
    emailController.dispose();
    streetController.dispose();
    barangayController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // ===== TERMS MODAL =====
  Future<void> openTerms() async {
    FocusScope.of(context).unfocus();

    final agreed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TermsSheet(
        terms: mockTerms,
        alreadyAgreed: agreedToTerms,
      ),
    );

    if (agreed == true && mounted) {
      setState(() {
        agreedToTerms = true;
      });
    }
  }

  void onTermsCheckboxTap() {
    if (agreedToTerms) {
      // Unticking never needs the modal.
      setState(() {
        agreedToTerms = false;
      });
    } else {
      openTerms();
    }
  }

  // ===== BARANGAY PICKER =====
  Future<void> pickBarangay() async {
    FocusScope.of(context).unfocus();

    final picked = await showBarangayPicker(
      context,
      selected: barangayController.text,
    );

    if (picked != null && mounted) {
      setState(() {
        barangayController.text = picked;
      });
    }
  }

  // ===== NAVIGATION =====
  void nextStep() {
    final key = step == 0 ? personalFormKey : addressFormKey;
    if (!(key.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      step++;
    });
  }

  void previousStep() {
    FocusScope.of(context).unfocus();
    setState(() {
      step--;
    });
  }

  // ===== SUBMIT =====
  Future<void> register() async {
    if (!(securityFormKey.currentState?.validate() ?? false)) return;

    if (!agreedToTerms) {
      showMessage('Please read and agree to the Terms and Conditions.');
      return;
    }

    setState(() {
      loading = true;
    });

    final error = await authService.registerResidentFull(
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      phone: mobileController.text.trim(),
      email: emailController.text.trim(),
      streetAddress: streetController.text.trim(),
      barangay: barangayController.text.trim(),
      password: passwordController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      loading = false;
    });

    if (error != null) {
      showMessage(error);
      return;
    }

    // Cache the session so the new user stays logged in.
    await SessionService.saveSession(
      uid: authService.currentUser?.uid ?? '',
      role: 'resident',
      firstName: firstNameController.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registration successful!'),
        backgroundColor: AppColors.success,
      ),
    );

    // Splash greets the new user, then routes to /home.
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/splash',
      (route) => false,
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  // ===== VALIDATORS =====
  String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  // 09XXXXXXXXX (11 digits) or 639XXXXXXXXX (12 digits), digits only.
  String? validateMobile(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Mobile number is required.';

    final valid = RegExp(r'^(09\d{9}|639\d{9})$').hasMatch(v);
    if (!valid) {
      return 'Use 09XXXXXXXXX (11 digits) or 639XXXXXXXXX (12 digits).';
    }
    return null;
  }

  String? validateBarangay(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please select your barangay.';
    if (!sampalocBarangays.contains(v)) {
      return 'Select a barangay from the list.';
    }
    return null;
  }

  String? validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email address is required.';

    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    if (!valid) return 'Enter a valid email address.';
    return null;
  }

  String? validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  String? validateConfirm(String? value) {
    if ((value ?? '').isEmpty) return 'Please confirm your password.';
    if (value != passwordController.text) return 'Passwords do not match.';
    return null;
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Create Account',
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildStepIndicator(),
              SizedBox(height: 20.h),
              Container(
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(step),
                    child: buildCurrentStep(),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
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
  }

  Widget buildStepIndicator() {
    final circleSize = 34.w;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(stepTitles.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineIndex = i ~/ 2;
          return Expanded(
            child: SizedBox(
              height: circleSize,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 3.h,
                  margin: EdgeInsets.symmetric(horizontal: 6.w),
                  decoration: BoxDecoration(
                    color: lineIndex < step
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            ),
          );
        }

        final index = i ~/ 2;
        final done = index < step;
        final active = index == step;

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: circleSize,
              height: circleSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active ? AppColors.primary : AppColors.white,
                border: Border.all(
                  color: done || active ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.primaryRing,
                          spreadRadius: 5.w,
                        ),
                      ]
                    : null,
              ),
              child: done
                  ? Icon(Icons.check, size: 18.w, color: AppColors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color:
                            active ? AppColors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            SizedBox(height: 8.h),
            Text(
              stepTitles[index],
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget buildCurrentStep() {
    switch (step) {
      case 0:
        return buildPersonalStep();
      case 1:
        return buildAddressStep();
      default:
        return buildSecurityStep();
    }
  }

  // ----- STEP 1 -----
  Widget buildPersonalStep() {
    return Form(
      key: personalFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Personal Information'),
          TextFormField(
            controller: firstNameController,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(fontSize: 15.sp),
            decoration: fieldDecoration('First Name', Icons.person),
            validator: (v) => requiredField(v, 'First name'),
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: lastNameController,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(fontSize: 15.sp),
            decoration: fieldDecoration('Last Name', Icons.person_outline),
            validator: (v) => requiredField(v, 'Last name'),
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: mobileController,
            keyboardType: TextInputType.number,
            inputFormatters: [_PhoneFormatter()],
            style: TextStyle(fontSize: 15.sp),
            decoration: fieldDecoration('Mobile Number', Icons.phone).copyWith(
              hintText: '09XXXXXXXXX or 639XXXXXXXXX',
              hintStyle: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
              ),
            ),
            validator: validateMobile,
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontSize: 15.sp),
            decoration: fieldDecoration('Email Address', Icons.email),
            validator: validateEmail,
          ),
          SizedBox(height: 26.h),
          primaryButton('NEXT', nextStep),
        ],
      ),
    );
  }

  // ----- STEP 2 -----
  Widget buildAddressStep() {
    return Form(
      key: addressFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Address Information'),
          TextFormField(
            controller: streetController,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(fontSize: 15.sp),
            decoration: fieldDecoration('Street Address', Icons.home),
            validator: (v) => requiredField(v, 'Street address'),
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: barangayController,
            readOnly: true,
            showCursor: false,
            onTap: pickBarangay,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: TextStyle(fontSize: 15.sp),
            decoration: fieldDecoration('Barangay', Icons.location_on).copyWith(
              hintText: 'Select your barangay',
              hintStyle: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
              ),
              suffixIcon: Icon(
                Icons.arrow_drop_down,
                size: 28.w,
                color: AppColors.textSecondary,
              ),
            ),
            validator: validateBarangay,
          ),
          SizedBox(height: 16.h),
          InputDecorator(
            decoration: fieldDecoration('City', Icons.location_city).copyWith(
              fillColor: AppColors.disabledFill,
              helperText: cityHelper,
              helperStyle: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
            child: Text(
              cityName,
              style: TextStyle(fontSize: 15.sp),
            ),
          ),
          SizedBox(height: 26.h),
          Row(
            children: [
              Expanded(child: outlineButton('BACK', previousStep)),
              SizedBox(width: 12.w),
              Expanded(child: primaryButton('NEXT', nextStep)),
            ],
          ),
        ],
      ),
    );
  }

  // ----- STEP 3 -----
  Widget buildSecurityStep() {
    return Form(
      key: securityFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('Security & Terms and Conditions'),
          TextFormField(
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
            validator: validatePassword,
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: confirmPasswordController,
            obscureText: obscureConfirm,
            style: TextStyle(fontSize: 15.sp),
            decoration:
                fieldDecoration('Confirm Password', Icons.lock_outline)
                    .copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  obscureConfirm ? Icons.visibility : Icons.visibility_off,
                  size: 22.w,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    obscureConfirm = !obscureConfirm;
                  });
                },
              ),
            ),
            validator: validateConfirm,
          ),
          SizedBox(height: 20.h),
          buildTermsCheckbox(),
          SizedBox(height: 22.h),
          Row(
            children: [
              Expanded(
                child: outlineButton('BACK', loading ? null : previousStep),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: (loading || !agreedToTerms) ? null : register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor:
                          loading ? AppColors.primary : null,
                      disabledForegroundColor:
                          loading ? AppColors.white : null,
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
                            'CREATE ACCOUNT',
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
    );
  }

  // ===== TERMS CHECKBOX ROW =====
  Widget buildTermsCheckbox() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: agreedToTerms ? AppColors.success : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24.w,
            height: 24.w,
            child: Checkbox(
              value: agreedToTerms,
              onChanged: (_) => onTermsCheckboxTap(),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.r),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: InkWell(
              onTap: openTerms,
              borderRadius: BorderRadius.circular(8.r),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Text.rich(
                  TextSpan(
                    text: 'I agree to the ',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: 'Terms and Conditions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== SMALL HELPERS =====
  Widget sectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
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

  Widget primaryButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
        ),
      ),
    );
  }

  Widget outlineButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      height: 50.h,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(
            color: onPressed == null ? AppColors.border : AppColors.primary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
        ),
      ),
    );
  }
}

// ===== PHONE INPUT FORMATTER =====
// Digits only. Must start with 09 (max 11 digits) or 63 (max 12 digits).
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.isNotEmpty && digits[0] != '0' && digits[0] != '6') {
      return oldValue;
    }
    if (digits.length > 1) {
      final prefix = digits.substring(0, 2);
      if (prefix != '09' && prefix != '63') return oldValue;
    }
    // 63 must be followed by 9 (639XXXXXXXXX), same as the validator.
    if (digits.startsWith('63') && digits.length > 2 && digits[2] != '9') {
      return oldValue;
    }

    final maxLength = digits.startsWith('63') ? 12 : 11;
    if (digits.length > maxLength) {
      digits = digits.substring(0, maxLength);
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

// ===== TERMS BOTTOM SHEET =====
// Pops true when the user taps I AGREE after scrolling to the bottom.
class _TermsSheet extends StatefulWidget {
  const _TermsSheet({
    required this.terms,
    required this.alreadyAgreed,
  });

  final String terms;
  final bool alreadyAgreed;

  @override
  State<_TermsSheet> createState() => _TermsSheetState();
}

class _TermsSheetState extends State<_TermsSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _reachedEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScroll);

    // If the text is short enough that nothing scrolls, enable right away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reachedEnd) return;
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent <= 0) {
        setState(() {
          _reachedEnd = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (_reachedEnd) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 8) {
      setState(() {
        _reachedEnd = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAgree = _reachedEnd;

    return Container(
      height: ScreenUtil.screenHeight * 0.85,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ScreenUtil.maxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        size: 22.w,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'Terms and Conditions',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.all(16.w),
                        child: Text(
                          widget.terms,
                          style: TextStyle(
                            fontSize: 13.sp,
                            height: 1.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                if (!widget.alreadyAgreed && !canAgree)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_downward,
                          size: 14.w,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            'Scroll to the bottom to enable the I Agree button.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                widget.alreadyAgreed ? _buildCloseOnly() : _buildActions(canAgree),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseOnly() {
    return SizedBox(
      height: 50.h,
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context, false),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          'CLOSE',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildActions(bool canAgree) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50.h,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'CANCEL',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50.h,
            child: ElevatedButton(
              onPressed: canAgree ? () => Navigator.pop(context, true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'I AGREE',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const String mockTerms = '''
CITIFIX MANILA TERMS AND CONDITIONS

Last updated: October 2026

1. Acceptance of Terms
By creating an account on CitiFix Manila, you agree to be bound by these Terms and Conditions. If you do not agree, please do not use the app.

2. Eligibility (District 4 Only)
This app is exclusively for residents of District 4 of the City of Manila, which covers Sampaloc, Barangays 395 to 586. You must provide accurate and complete information when registering, including your name, contact details, and a valid District 4 address. Residents of other districts or cities are not eligible to register or use the app.

3. Purpose of the App
CitiFix Manila lets residents of District 4 report community issues such as damaged roads, broken streetlights, uncollected garbage, and other public concerns so they can be reviewed and addressed by the proper city offices. Reports may only cover issues located within District 4.

4. User Responsibilities
You agree to submit only truthful reports and to give a truthful address. You will not submit false, misleading, offensive, or spam reports. You are responsible for keeping your login details confidential and for all activity under your account.

5. Reports and Content
Photos, locations, and descriptions you submit may be reviewed by city personnel and used to address the reported issue. Do not upload images that show private individuals without their consent or any unlawful content.

6. Location Data
The app may use your device location to pin the exact place of a reported issue. Location data is used only for report handling and is not sold to third parties.

7. Privacy
We collect your personal information, such as name, mobile number, email, and address, to verify your identity and process your reports. Your information is handled in line with the Data Privacy Act of 2012 (Republic Act No. 10173).

8. Account Suspension
Accounts that violate these terms, abuse the reporting system, submit repeated false reports, or were registered with an address outside District 4 may be suspended or removed without prior notice.

9. No Guarantee of Resolution
Submitting a report does not guarantee a specific response time or outcome. Resolution depends on the priorities and resources of the responsible city offices.

10. Changes to These Terms
These terms may be updated from time to time. Continued use of the app after changes means you accept the revised terms.

11. Contact
For questions about these terms, please contact the CitiFix Manila support team through the app.

By tapping I AGREE, you confirm that you have read and understood these Terms and Conditions, including that this app is exclusive to District 4 of Manila.

-- END OF TERMS --
''';