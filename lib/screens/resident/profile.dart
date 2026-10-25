import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../utils/screen_util.dart';
import '../../widgets/app_widgets.dart';
import 'change_password_page.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Controllers (only used while editing)
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _barangayController = TextEditingController();

  // Saved values (what view mode shows)
  String _firstName = '';
  String _lastName = '';
  String _phone = '';
  String _street = '';
  String _barangay = '';
  String _email = '';
  String _role = 'resident';

  static const String _cityName = 'City of Manila';

  bool _isLoading = true;
  bool _isLoggingOut = false;
  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _barangayController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // LOAD
  // ─────────────────────────────────────────────────────────────
  Future<void> _loadUserData() async {
    try {
      final data = await _authService.getCurrentUserData();
      if (!mounted) return;

      var first = (data?['firstName'] ?? '').toString().trim();
      var last = (data?['lastName'] ?? '').toString().trim();

      // Older accounts only have fullName: split it.
      if (first.isEmpty) {
        final parts = (data?['fullName'] ?? '')
            .toString()
            .trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) {
          first = parts.first;
          last = parts.skip(1).join(' ');
        }
      }

      setState(() {
        _firstName = first;
        _lastName = last;
        _phone = (data?['phone'] ?? '').toString();
        _street = (data?['streetAddress'] ?? '').toString();
        _barangay = (data?['barangay'] ?? '').toString();
        _email = (data?['email'] ?? _authService.currentUser?.email ?? '')
            .toString();
        _role = (data?['role'] ?? 'resident').toString();
        _fillControllers();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  void _fillControllers() {
    _firstNameController.text = _firstName;
    _lastNameController.text = _lastName;
    _phoneController.text = _phone;
    _streetController.text = _street;
    _barangayController.text = _barangay;
  }

  // ─────────────────────────────────────────────────────────────
  // EDIT / CANCEL
  // ─────────────────────────────────────────────────────────────
  void _startEditing() {
    _fillControllers();
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    FocusScope.of(context).unfocus();
    setState(() {
      _fillControllers(); // revert unsaved changes
      _isEditing = false;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // SAVE (with confirmation modal)
  // ─────────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    final confirmed = await showConfirmDialog(
      context,
      title: 'Save changes?',
      message: 'Your profile information will be updated.',
      confirmLabel: 'Save',
      icon: Icons.save_outlined,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);

    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final street = _streetController.text.trim();
    final barangay = _barangayController.text.trim();

    try {
      await _authService.updateUserProfileFull(
        firstName: first,
        lastName: last,
        phone: phone,
        streetAddress: street,
        barangay: barangay,
      );

      // Keep the cached greeting name ("Hello, <name>") in sync.
      final session = await SessionService.getSession();
      if (session != null) {
        await SessionService.saveSession(
          uid: session.uid,
          role: session.role,
          firstName: first,
        );
      }

      if (!mounted) return;

      setState(() {
        _firstName = first;
        _lastName = last;
        _phone = phone;
        _street = street;
        _barangay = barangay;
        _isEditing = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LOGOUT (with confirmation modal)
  // ─────────────────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log out',
      icon: Icons.logout,
      confirmColor: AppColors.error,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isLoggingOut = true);

    try {
      await _authService.logout();
    } catch (_) {
      // ignore — navigate regardless
    }

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // VALIDATORS (same rules as register)
  // ─────────────────────────────────────────────────────────────
  String? _requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  String? _validateMobile(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Mobile number is required.';

    final valid = RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(v);
    if (!valid) return 'Use 09XXXXXXXXX or +639XXXXXXXXX.';
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          if (!_isLoading && !_isEditing)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: TextButton.icon(
                onPressed: _startEditing,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.white,
                ),
                icon: Icon(Icons.edit, size: 18.w),
                label: Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ResponsiveBody(
                alignment: Alignment.topCenter,
                padding:
                    EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      SizedBox(height: 20.h),
                      _buildPersonalCard(),
                      SizedBox(height: 16.h),
                      _buildAddressCard(),
                      SizedBox(height: 24.h),
                      _isEditing ? _buildEditActions() : _buildViewActions(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ===== HEADER =====
  Widget _buildHeader() {
    final fullName = '$_firstName $_lastName'.trim();

    final initials = [_firstName, _lastName]
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase())
        .join();

    final roleLabel = _role.isEmpty
        ? 'Resident'
        : _role[0].toUpperCase() + _role.substring(1);

    return Column(
      children: [
        Container(
          width: 96.w,
          height: 96.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRing,
                spreadRadius: 6.w,
              ),
            ],
          ),
          child: Text(
            initials.isEmpty ? '?' : initials,
            style: TextStyle(
              fontSize: 34.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
        ),
        SizedBox(height: 18.h),
        Text(
          fullName.isEmpty ? 'Unknown' : fullName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),

        
      ],
    );
  }

  // ===== CARDS =====
  Widget _buildPersonalCard() {
    return _card(
      title: 'Personal Information',
      icon: Icons.person_outline,
      children: _isEditing
          ? _spaced([
              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(fontSize: 15.sp),
                decoration: appFieldDecoration('First Name', Icons.person),
                validator: (v) => _requiredField(v, 'First name'),
              ),
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(fontSize: 15.sp),
                decoration:
                    appFieldDecoration('Last Name', Icons.person_outline),
                validator: (v) => _requiredField(v, 'Last name'),
              ),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 15.sp),
                decoration: appFieldDecoration('Mobile Number', Icons.phone),
                validator: _validateMobile,
              ),
              _lockedField('Email Address', Icons.email, _email),
            ], 16.h)
          : _spaced([
              _infoRow(Icons.person, 'First Name', _firstName),
              _infoRow(Icons.person_outline, 'Last Name', _lastName),
              _infoRow(Icons.phone, 'Mobile Number', _phone),
              _infoRow(Icons.email, 'Email Address', _email),
            ], 18.h),
    );
  }

  Widget _buildAddressCard() {
    return _card(
      title: 'Address Information',
      icon: Icons.location_on_outlined,
      children: _isEditing
          ? _spaced([
              TextFormField(
                controller: _streetController,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(fontSize: 15.sp),
                decoration: appFieldDecoration('Street Address', Icons.home),
                validator: (v) => _requiredField(v, 'Street address'),
              ),
              TextFormField(
                controller: _barangayController,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(fontSize: 15.sp),
                decoration:
                    appFieldDecoration('Barangay', Icons.location_on),
                validator: (v) => _requiredField(v, 'Barangay'),
              ),
              _lockedField('City', Icons.location_city, _cityName),
            ], 16.h)
          : _spaced([
              _infoRow(Icons.home, 'Street Address', _street),
              _infoRow(Icons.location_on, 'Barangay', _barangay),
              _infoRow(Icons.location_city, 'City', _cityName),
            ], 18.h),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(20.w),
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
          Row(
            children: [
              Icon(icon, size: 22.w, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          ...children,
        ],
      ),
    );
  }

  // Read-only row (view mode)
  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, size: 20.w, color: AppColors.primary),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value.isEmpty ? '—' : value,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Locked field (edit mode): email and city
  Widget _lockedField(String label, IconData icon, String value) {
    return TextFormField(
      initialValue: value,
      enabled: false,
      style: TextStyle(fontSize: 15.sp, color: AppColors.textSecondary),
      decoration: appFieldDecoration(label, icon, locked: true),
    );
  }

  List<Widget> _spaced(List<Widget> items, double gap) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(SizedBox(height: gap));
      out.add(items[i]);
    }
    return out;
  }

  // ===== ACTIONS =====
  Widget _buildViewActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 50.h,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordPage(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            icon: Icon(Icons.lock_reset, size: 22.w),
            label: Text(
              'Change Password',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 50.h,
          child: ElevatedButton.icon(
            onPressed: _isLoggingOut ? null : _handleLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            icon: _isLoggingOut
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Icon(Icons.logout, size: 22.w),
            label: Text(
              _isLoggingOut ? 'Logging out…' : 'Log Out',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50.h,
            child: OutlinedButton(
              onPressed: _isSaving ? null : _cancelEditing,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: _isSaving ? AppColors.border : AppColors.primary,
                ),
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
              onPressed: _isSaving ? null : _saveProfile,
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
              child: _isSaving
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'SAVE CHANGES',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}