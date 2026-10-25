import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../services/report_service.dart';
import '../../utils/screen_util.dart';

// ==================== REPORT PAGE (single widget, 4 steps + success) ====================
class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final ReportService _reportService = ReportService();
  final ImagePicker picker = ImagePicker();
  final TextEditingController descriptionController = TextEditingController();

  // ===== STEP STATE =====
  int step = 0;
  static const stepTitles = ['Category', 'Details', 'Location', 'Review'];

  // Step 1: category
  String selectedCategory = '';

  // Step 2: details
  Uint8List? imageBytes;
  String? imageName;

  // Step 3: location
  Position? position;
  bool loadingLocation = false;

  // Step 4: review / submit
  bool submitting = false;

  // Success
  bool submitted = false;
  String reportId = '';

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  // ===== NAVIGATION =====
  void goBack() {
    if (step == 0) return;
    FocusScope.of(context).unfocus();
    setState(() {
      step--;
    });
  }

  void goNext() {
    FocusScope.of(context).unfocus();

    switch (step) {
      case 0:
        if (selectedCategory.isEmpty) return;
        setState(() {
          step = 1;
        });
        break;

      case 1:
        final description = descriptionController.text.trim();

        if (description.isEmpty) {
          showMessage('Please describe the issue.');
          return;
        }

        if (imageBytes == null) {
          showMessage('Please upload a photo of the issue.');
          return;
        }

        setState(() {
          step = 2;
        });

        // Fetch the location when reaching this step.
        if (position == null) getLocation();
        break;

      case 2:
        if (position == null) {
          showMessage('Please get your current location first.');
          return;
        }
        setState(() {
          step = 3;
        });
        break;
    }
  }

  // ===== PHOTO =====
  Future<void> selectPhoto() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        imageBytes = bytes;
        imageName = image.name;
      });
    } catch (e) {
      showMessage('Unable to select photo: $e');
    }
  }

  Future<void> takePhoto() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        imageBytes = bytes;
        imageName = image.name;
      });
    } catch (e) {
      showMessage('Camera is not available: $e');
    }
  }

  void showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Add Photo',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                _sheetOption(
                  icon: Icons.photo_library,
                  label: 'Choose from Gallery',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    selectPhoto();
                  },
                ),
                _sheetOption(
                  icon: Icons.camera_alt,
                  label: 'Take Photo',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    takePhoto();
                  },
                ),
                if (imageBytes != null)
                  _sheetOption(
                    icon: Icons.delete,
                    label: 'Remove Photo',
                    color: AppColors.error,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      setState(() {
                        imageBytes = null;
                        imageName = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.primary,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42.w,
        height: 42.w,
        decoration: BoxDecoration(
          color: color.withAlpha(31),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, size: 22.w, color: color),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          color: color == AppColors.error ? color : AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  // ===== LOCATION =====
  Future<void> getLocation() async {
    setState(() {
      loadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        showMessage('Please enable Location Services.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        showMessage('Location permission was denied.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        showMessage(
          'Location permission is permanently denied. '
          'Please enable it in device settings.',
        );
        return;
      }

      final result = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        position = result;
      });
    } catch (e) {
      showMessage('Unable to get location: $e');
    } finally {
      if (mounted) {
        setState(() {
          loadingLocation = false;
        });
      }
    }
  }

  // ===== SUBMIT =====
  Future<void> submit() async {
    setState(() {
      submitting = true;
    });

    try {
      final id = await _reportService.submitReport(
        category: selectedCategory,
        description: descriptionController.text.trim(),
        latitude: position!.latitude,
        longitude: position!.longitude,
        imageBytes: imageBytes!,
        imageName: imageName,
      );

      if (!mounted) return;

      setState(() {
        reportId = id;
        submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
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

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'road damage':
        return Icons.aod;
      case 'flooding':
        return Icons.water;
      case 'garbage':
        return Icons.delete_outline;
      case 'streetlight':
        return Icons.lightbulb_outline;
      case 'traffic':
        return Icons.traffic;
      case 'crime':
        return Icons.security;
      case 'noise':
        return Icons.volume_up;
      default:
        return Icons.error_outline;
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    final appBarTitle = step == 3
        ? 'Review Report'
        : step == 2
            ? 'Set Location'
            : 'Report Issue';

    return PopScope(
      // Back goes to the previous step; it only leaves the flow from step 1.
      canPop: !submitted && !submitting && step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || submitted || submitting) return;
        goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: submitted
            ? null
            : AppBar(
                title: Text(
                  appBarTitle,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
        body: submitted ? buildSuccess() : buildFlow(),
      ),
    );
  }

  Widget buildFlow() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ScreenUtil.maxContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
            child: Column(
              children: [
                buildStepIndicator(),
                SizedBox(height: 20.h),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey(step),
                      child: buildCurrentStep(),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                buildBottomButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildStepIndicator() {
    final circleSize = 30.w;

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
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
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
                          spreadRadius: 4.w,
                        ),
                      ]
                    : null,
              ),
              child: done
                  ? Icon(Icons.check, size: 16.w, color: AppColors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 13.sp,
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
                fontSize: 11.sp,
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
        return buildCategoryStep();
      case 1:
        return buildDetailsStep();
      case 2:
        return buildLocationStep();
      default:
        return buildReviewStep();
    }
  }

  Widget buildBottomButton() {
    switch (step) {
      case 0:
        return primaryButton(
          'NEXT',
          selectedCategory.isEmpty ? null : goNext,
        );
      case 1:
        return primaryButton('NEXT', goNext);
      case 2:
        return primaryButton(
          'REVIEW REPORT',
          position == null || loadingLocation ? null : goNext,
        );
      default:
        return primaryButton(
          submitting ? 'SUBMITTING...' : 'SUBMIT REPORT',
          submitting ? null : submit,
          loading: submitting,
        );
    }
  }

  // ----- STEP 1: CATEGORY -----
  Widget buildCategoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stepHeader(
          'Select Issue Category',
          'What problem would you like to report?',
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('categories')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load categories.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No categories available.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['name']?.toString() ?? docs[index].id;

                  return categoryTile(name);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget categoryTile(String name) {
    final selected = selectedCategory == name;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedCategory = name;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12.r,
                offset: Offset(0, 4.h),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  _getIconForCategory(name),
                  size: 22.w,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 24.w,
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- STEP 2: DETAILS -----
  Widget buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stepHeader(selectedCategory, 'Provide details about the issue'),
        SizedBox(height: 16.h),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(18.w),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: descriptionController,
                    maxLines: 5,
                    style: TextStyle(fontSize: 15.sp),
                    decoration: descriptionDecoration(),
                  ),
                  SizedBox(height: 16.h),
                  GestureDetector(
                    onTap: showPhotoOptions,
                    child: Container(
                      width: double.infinity,
                      height: 180.h,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: imageBytes == null
                              ? AppColors.primary
                              : AppColors.success,
                          width: 1.6,
                        ),
                      ),
                      child: imageBytes == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 44.w,
                                  color: AppColors.primary,
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  'Upload Photo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Tap here to choose a photo',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14.r),
                                  child: Image.memory(
                                    imageBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 10.h,
                                  right: 10.w,
                                  child: Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: const BoxDecoration(
                                      color: AppColors.textSecondary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      color: AppColors.white,
                                      size: 18.w,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (imageBytes != null) ...[
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(31),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: AppColors.success.withAlpha(90),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 16.w,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              imageName ?? 'Photo selected',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration descriptionDecoration() {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: 'Description',
      hintText: 'Describe the issue in detail...',
      alignLabelWithHint: true,
      labelStyle: TextStyle(
        fontSize: 14.sp,
        color: AppColors.textSecondary,
      ),
      hintStyle: TextStyle(
        fontSize: 14.sp,
        color: AppColors.textSecondary,
      ),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(AppColors.primary, 1.6),
    );
  }

  // ----- STEP 3: LOCATION -----
  Widget buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stepHeader(
          'Your Location',
          'We need your current location to send help',
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: cardDecoration(),
                child:
                    position == null ? buildLocationEmpty() : buildLocationReady(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildLocationEmpty() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconBadge(Icons.location_off, AppColors.error),
        SizedBox(height: 16.h),
        Text(
          'Location not selected',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Get your current GPS location.',
          style: TextStyle(
            fontSize: 14.sp,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 20.h),
        if (loadingLocation)
          const CircularProgressIndicator()
        else
          ElevatedButton.icon(
            onPressed: getLocation,
            icon: Icon(Icons.my_location, size: 20.w),
            label: Text(
              'Get Location',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildLocationReady() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconBadge(Icons.check_circle, AppColors.success),
        SizedBox(height: 16.h),
        Text(
          'Location Selected',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.success,
          ),
        ),
        SizedBox(height: 18.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            children: [
              coordinateRow(
                'Latitude: ${position!.latitude.toStringAsFixed(6)}',
              ),
              SizedBox(height: 10.h),
              coordinateRow(
                'Longitude: ${position!.longitude.toStringAsFixed(6)}',
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        if (loadingLocation)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: const CircularProgressIndicator(),
          )
        else
          TextButton.icon(
            onPressed: getLocation,
            icon: Icon(Icons.refresh, size: 20.w),
            label: Text(
              'Refresh Location',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget coordinateRow(String text) {
    return Row(
      children: [
        Icon(Icons.location_on, color: AppColors.primary, size: 20.w),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget iconBadge(IconData icon, Color color) {
    return Container(
      width: 80.w,
      height: 80.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(31),
      ),
      child: Icon(icon, size: 42.w, color: color),
    );
  }

  // ----- STEP 4: REVIEW -----
  Widget buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stepHeader(
          'Review Your Report',
          'Please verify all information before submitting',
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(20.w),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Details',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  reviewRow(
                    'Category',
                    selectedCategory,
                    Icons.category,
                  ),
                  reviewRow(
                    'Description',
                    descriptionController.text.trim(),
                    Icons.description,
                  ),
                  reviewRow(
                    'Location',
                    '${position!.latitude.toStringAsFixed(6)}, '
                        '${position!.longitude.toStringAsFixed(6)}',
                    Icons.location_on,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.photo, size: 18.w, color: AppColors.primary),
                      SizedBox(width: 8.w),
                      Text(
                        'Photo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: Image.memory(
                      imageBytes!,
                      width: double.infinity,
                      height: 220.h,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (imageName != null) ...[
                    SizedBox(height: 8.h),
                    Text(
                      '📷 $imageName',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                  SizedBox(height: 14.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 20.w,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'Your report will be reviewed by our team. '
                            'You will be notified of updates.',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget reviewRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18.w, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----- SUCCESS -----
  Widget buildSuccess() {
    return SafeArea(
      child: ResponsiveBody(
        child: Container(
          padding: EdgeInsets.all(28.w),
          decoration: cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 88.w,
                  height: 88.w,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: AppColors.white,
                    size: 50.w,
                  ),
                ),
              ),
              SizedBox(height: 22.h),
              Text(
                'Report Submitted!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Your report has been submitted successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15.sp,
                ),
              ),
              SizedBox(height: 18.h),
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: [
                    Text(
                      'Reference Number:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '#${reportId.substring(0, 8).toUpperCase()}',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Our team will review your report and take action.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 26.h),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50.h,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/home',
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'GO HOME',
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
  }

  // ===== SMALL HELPERS =====
  Widget stepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14.sp,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20.r),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 24.r,
          offset: Offset(0, 8.h),
        ),
      ],
    );
  }

  Widget primaryButton(
    String text,
    VoidCallback? onPressed, {
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: loading ? AppColors.primary : null,
          disabledForegroundColor: loading ? AppColors.white : null,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2.5,
                ),
              ),
              SizedBox(width: 12.w),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}