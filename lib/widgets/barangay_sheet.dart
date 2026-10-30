import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/sampaloc_barangays.dart';
import '../utils/screen_util.dart';

/// Opens the barangay picker (search box + list).
/// Returns the chosen barangay (for example "Barangay 395"),
/// or null if the sheet was dismissed.
Future<String?> showBarangayPicker(
  BuildContext context, {
  String selected = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BarangaySheet(selected: selected),
  );
}

// ===== BARANGAY BOTTOM SHEET =====
// Pops the chosen barangay (for example "Barangay 395").
class BarangaySheet extends StatefulWidget {
  const BarangaySheet({super.key, required this.selected});

  final String selected;

  @override
  State<BarangaySheet> createState() => _BarangaySheetState();
}

class _BarangaySheetState extends State<BarangaySheet> {
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