import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../constants/sampaloc_barangays.dart';
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

  // Display only. The saved city value is not edited here.
  static const String _cityName = 'District 4, City of Manila';
  static const String _cityHelper = 'Sampaloc, Barangays 395 to 586';

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
    // Digits only, so older "+63..." numbers fit the new phone rules.
    _phoneController.text = _phone.replaceAll(RegExp(r'\D'), '');
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

  Future<void> _pickBarangay() async {
    FocusScope.of(context).unfocus();

    final picked = await _showBarangayPicker(
      context,
      selected: _barangayController.text,
    );

    if (picked != null && mounted) {
      setState(() {
        _barangayController.text = picked;
      });
    }
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
                keyboardType: TextInputType.number,
                inputFormatters: [_PhoneInputFormatter()],
                style: TextStyle(fontSize: 15.sp),
                decoration:
                    appFieldDecoration('Mobile Number', Icons.phone).copyWith(
                  hintText: '09XXXXXXXXX or 639XXXXXXXXX',
                ),
                validator: _validatePhMobile,
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
                readOnly: true,
                showCursor: false,
                onTap: _pickBarangay,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                style: TextStyle(fontSize: 15.sp),
                decoration:
                    appFieldDecoration('Barangay', Icons.location_on).copyWith(
                  hintText: 'Select your barangay',
                  suffixIcon: Icon(
                    Icons.arrow_drop_down,
                    size: 28.w,
                    color: AppColors.textSecondary,
                  ),
                ),
                validator: _validateSampalocBarangay,
              ),
              _lockedField(
                'City',
                Icons.location_city,
                _cityName,
                helper: _cityHelper,
              ),
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
  Widget _lockedField(
    String label,
    IconData icon,
    String value, {
    String? helper,
  }) {
    return TextFormField(
      initialValue: value,
      enabled: false,
      style: TextStyle(fontSize: 15.sp, color: AppColors.textSecondary),
      decoration: appFieldDecoration(label, icon, locked: true).copyWith(
        helperText: helper,
      ),
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

// ─────────────────────────────────────────────────────────────
// PHONE RULES (same as register)
// ─────────────────────────────────────────────────────────────
/// Digits only. Must start with 09 (max 11 digits) or 639 (max 12 digits).
class _PhoneInputFormatter extends TextInputFormatter {
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

/// 09XXXXXXXXX (11 digits) or 639XXXXXXXXX (12 digits), digits only.
String? _validatePhMobile(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Mobile number is required.';

  final valid = RegExp(r'^(09\d{9}|639\d{9})$').hasMatch(v);
  if (!valid) {
    return 'Use 09XXXXXXXXX (11 digits) or 639XXXXXXXXX (12 digits).';
  }
  return null;
}

// ─────────────────────────────────────────────────────────────
// BARANGAY PICKER (District 4, same as register)
// ─────────────────────────────────────────────────────────────
/// Opens the searchable District 4 barangay list.
/// Returns the chosen barangay (for example "Barangay 395"), or null.
Future<String?> _showBarangayPicker(
  BuildContext context, {
  String selected = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BarangaySheet(selected: selected),
  );
}

/// Validator for the barangay field: must be one of the District 4 barangays.
String? _validateSampalocBarangay(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Please select your barangay.';
  if (!sampalocBarangays.contains(v)) {
    return 'Select a barangay from the list.';
  }
  return null;
}

class _BarangaySheet extends StatefulWidget {
  const _BarangaySheet({required this.selected});

  final String selected;

  @override
  State<_BarangaySheet> createState() => _BarangaySheetState();
}

class _BarangaySheetState extends State<_BarangaySheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final sheetHeight = (media.size.height - keyboard) * 0.85;

    final results = _query.isEmpty
        ? sampalocBarangays
        : sampalocBarangays.where((b) => b.contains(_query)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: ScreenUtil.maxContentWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
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
                          Icons.location_on,
                          size: 22.w,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Barangay',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'District 4, Sampaloc',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(fontSize: 15.sp),
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Type a barangay number',
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 22.w,
                        color: AppColors.primary,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(Icons.close, size: 20.w),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: Text(
                              'No barangay found in District 4.',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, i) {
                              final name = results[i];
                              final isSelected = name == widget.selected;

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 20.w,
                                        color: AppColors.primary,
                                      )
                                    : null,
                                onTap: () => Navigator.pop(context, name),
                              );
                            },
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
}