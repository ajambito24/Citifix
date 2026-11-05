import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../constants/app_colors.dart';
import '../../constants/sampaloc_barangays.dart';
import '../../constants/sampaloc_boundary.dart';
import '../../services/report_service.dart';
import '../../utils/geo_util.dart';
import '../../utils/screen_util.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/barangay_sheet.dart';

/// How the report location was set.
enum LocationMode { auto, pin }

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
  final TextEditingController streetController = TextEditingController();
  final TextEditingController barangayController = TextEditingController();
  final MapController mapController = MapController();

  // ===== STEP STATE =====
  int step = 0;
  static const stepTitles = ['Category', 'Details', 'Location', 'Review'];

  // Step 1: category
  // Always shown as the last choice, even if it isn't in Firestore.
  static const String othersCategory = 'Others';
  String selectedCategory = '';

  // Step 2: details
  Uint8List? imageBytes;
  String? imageName;

  // Step 3: location (address + GPS / map pin)
  // Display only. Same wording as the register screen.
  static const String cityName = 'District 4, City of Manila';
  static const String cityHelper = 'Sampaloc, Barangays 395 to 586';

  // Errors under the address fields only show after the user tried to continue.
  bool addressTried = false;

  // The one location that gets submitted. Always inside Sampaloc.
  LatLng? selectedPoint;
  LocationMode pointSource = LocationMode.auto;

  // Which tab of the location card is showing.
  LocationMode locationMode = LocationMode.auto;

  // Latest raw GPS reading (used for the blue dot on the pin map).
  Position? gpsPosition;
  bool gpsOutside = false;
  bool loadingLocation = false;

  // Step 4: review / submit
  bool submitting = false;

  // Success
  bool submitted = false;
  String reportId = '';

  @override
  void dispose() {
    descriptionController.dispose();
    streetController.dispose();
    barangayController.dispose();
    mapController.dispose();
    super.dispose();
  }

  // ===== VALIDATORS (same rules as register) =====
  String? validateStreet(String value) {
    if (value.trim().isEmpty) return 'Street address is required.';
    return null;
  }

  String? validateBarangay(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Please select your barangay.';
    if (!sampalocBarangays.contains(v)) {
      return 'Select a barangay from the list.';
    }
    return null;
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

        // Try auto locate when reaching this step.
        if (selectedPoint == null) getLocation();
        break;

      case 2:
        setState(() {
          addressTried = true;
        });

        if (validateStreet(streetController.text) != null ||
            validateBarangay(barangayController.text) != null) {
          return;
        }

        if (selectedPoint == null) {
          showMessage('Please set the location of the issue first.');
          return;
        }
        setState(() {
          step = 3;
        });
        break;
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

  // ===== LOCATION: AUTO (GPS) =====
  Future<void> getLocation() async {
    setState(() {
      loadingLocation = true;
      gpsOutside = false;
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

      final point = LatLng(result.latitude, result.longitude);
      final inside = isPointInPolygon(point, sampalocBoundary);

      setState(() {
        gpsPosition = result;
        gpsOutside = !inside;

        // Only a reading inside Sampaloc is accepted.
        if (inside) {
          selectedPoint = point;
          pointSource = LocationMode.auto;
        }
      });

      if (!inside) {
        showMessage(
          'Your GPS location is outside Sampaloc. '
          'Use "Pin on Map" to choose a spot inside Sampaloc.',
        );
      }
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

  // ===== LOCATION: MANUAL PIN =====
  void onMapTap(LatLng point) {
    if (!isPointInPolygon(point, sampalocBoundary)) {
      showMessage('Please pin a location inside Sampaloc.');
      return;
    }

    setState(() {
      selectedPoint = point;
      pointSource = LocationMode.pin;
    });
  }

  CameraFit sampalocFit() {
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(sampalocBoundary),
      padding: EdgeInsets.all(24.w),
    );
  }

  void recenterMap() {
    try {
      mapController.fitCamera(sampalocFit());
    } catch (_) {
      // Map not ready yet; ignore.
    }
  }

  void setLocationMode(LocationMode mode) {
    if (locationMode == mode) return;
    FocusScope.of(context).unfocus();
    setState(() {
      locationMode = mode;
    });
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
        streetAddress: streetController.text.trim(),
        barangay: barangayController.text.trim(),
        latitude: selectedPoint!.latitude,
        longitude: selectedPoint!.longitude,
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
      case 'others':
        return Icons.more_horiz;
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
          selectedPoint == null || loadingLocation ? null : goNext,
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

              // Categories from Firestore, without any "Others" of its own:
              // "Others" is always added once, as the last choice.
              final names = <String>[];
              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name']?.toString() ?? doc.id;
                if (name.trim().toLowerCase() == othersCategory.toLowerCase()) {
                  continue;
                }
                names.add(name);
              }
              names.add(othersCategory);

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: names.length,
                itemBuilder: (context, index) => categoryTile(names[index]),
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

  // ----- STEP 3: LOCATION (address + GPS / map pin) -----
  Widget buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stepHeader(
          'Your Location',
          'Enter the address and set where the issue is',
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildAddressCard(),
                SizedBox(height: 16.h),
                buildGpsCard(),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget cardTitle(IconData icon, String title) {
    return Row(
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
    );
  }

  Widget buildAddressCard() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cardTitle(Icons.location_on_outlined, 'Address'),
          SizedBox(height: 18.h),
          TextField(
            controller: streetController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (addressTried) setState(() {});
            },
            style: TextStyle(fontSize: 15.sp),
            decoration: appFieldDecoration('Street Address', Icons.home)
                .copyWith(
              errorText:
                  addressTried ? validateStreet(streetController.text) : null,
            ),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: barangayController,
            readOnly: true,
            showCursor: false,
            onTap: pickBarangay,
            style: TextStyle(fontSize: 15.sp),
            decoration:
                appFieldDecoration('Barangay', Icons.location_on).copyWith(
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
              errorText: addressTried
                  ? validateBarangay(barangayController.text)
                  : null,
            ),
          ),
          SizedBox(height: 16.h),
          InputDecorator(
            decoration:
                appFieldDecoration('City', Icons.location_city, locked: true)
                    .copyWith(
              helperText: cityHelper,
              helperStyle: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
            child: Text(
              cityName,
              style: TextStyle(
                fontSize: 15.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildGpsCard() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cardTitle(Icons.my_location, 'Issue Location'),
          SizedBox(height: 14.h),
          buildModeToggle(),
          SizedBox(height: 18.h),
          locationMode == LocationMode.auto
              ? (selectedPoint == null
                  ? buildLocationEmpty()
                  : buildLocationReady())
              : buildPinMapSection(),
        ],
      ),
    );
  }

  // ----- Mode toggle -----
  Widget buildModeToggle() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: modeButton(
              'Auto Locate',
              Icons.my_location,
              LocationMode.auto,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: modeButton(
              'Pin on Map',
              Icons.push_pin,
              LocationMode.pin,
            ),
          ),
        ],
      ),
    );
  }

  Widget modeButton(String label, IconData icon, LocationMode mode) {
    final active = locationMode == mode;

    return GestureDetector(
      onTap: () => setLocationMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18.w,
              color: active ? AppColors.white : AppColors.textSecondary,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: active ? AppColors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----- Auto locate views -----
  Widget buildLocationEmpty() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconBadge(Icons.location_off, AppColors.error, size: 64),
        SizedBox(height: 14.h),
        Text(
          gpsOutside ? 'Outside Sampaloc' : 'Location not selected',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          gpsOutside
              ? 'Your GPS location is outside Sampaloc. '
                  'Try again or switch to Pin on Map.'
              : 'Get your current GPS location.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 18.h),
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
    final point = selectedPoint!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconBadge(Icons.check_circle, AppColors.success, size: 64),
        SizedBox(height: 14.h),
        Text(
          'Location Selected',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.success,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          pointSource == LocationMode.pin
              ? 'Pinned on the map'
              : 'From your GPS',
          style: TextStyle(
            fontSize: 13.sp,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 16.h),
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
                'Latitude: ${point.latitude.toStringAsFixed(6)}',
              ),
              SizedBox(height: 10.h),
              coordinateRow(
                'Longitude: ${point.longitude.toStringAsFixed(6)}',
              ),
            ],
          ),
        ),
        if (gpsOutside) ...[
          SizedBox(height: 10.h),
          Text(
            'Your latest GPS reading was outside Sampaloc, '
            'so the previous location was kept.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.warning,
            ),
          ),
        ],
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

  // ----- Pin on map view -----
  Widget buildPinMapSection() {
    final point = selectedPoint;
    final gps = gpsPosition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tap inside the blue Sampaloc border to drop a pin.',
          style: TextStyle(
            fontSize: 13.sp,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: 300.h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCameraFit: sampalocFit(),
                    minZoom: 12,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: (tapPosition, latLng) => onMapTap(latLng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      // Match this to your Android applicationId.
                      userAgentPackageName: 'com.example.citifix_manila',
                    ),
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: sampalocBoundary,
                          color: AppColors.primarySoft,
                          borderColor: AppColors.primary,
                          borderStrokeWidth: 3,
                        ),
                      ],
                    ),
                    // GPS dot for reference, if the user already fetched it.
                    if (gps != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(gps.latitude, gps.longitude),
                            width: 22.w,
                            height: 22.w,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                                border: Border.all(
                                  color: AppColors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.shadow,
                                    blurRadius: 6.r,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    // The pin. The tip sits on the chosen point.
                    if (point != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 40.w,
                            height: 40.w,
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.location_on,
                              size: 40.w,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    // Required by OpenStreetMap's tile usage policy.
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 10.h,
                  right: 10.w,
                  child: GestureDetector(
                    onTap: recenterMap,
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 10.r,
                            offset: Offset(0, 3.h),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.fit_screen,
                        size: 20.w,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: point == null
              ? Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20.w,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'No pin yet. Tap the map to set the location.',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    coordinateRow(
                      'Latitude: ${point.latitude.toStringAsFixed(6)}',
                    ),
                    SizedBox(height: 10.h),
                    coordinateRow(
                      'Longitude: ${point.longitude.toStringAsFixed(6)}',
                    ),
                  ],
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

  Widget iconBadge(IconData icon, Color color, {double size = 80}) {
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(31),
      ),
      child: Icon(icon, size: (size * 0.52).w, color: color),
    );
  }

  // ----- STEP 4: REVIEW -----
  Widget buildReviewStep() {
    final point = selectedPoint!;

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
                    'Street',
                    streetController.text.trim(),
                    Icons.home,
                  ),
                  reviewRow(
                    'Barangay',
                    barangayController.text.trim(),
                    Icons.location_city,
                  ),
                  reviewRow(
                    pointSource == LocationMode.pin
                        ? 'Location (Pinned)'
                        : 'Location (GPS)',
                    '${point.latitude.toStringAsFixed(6)}, '
                        '${point.longitude.toStringAsFixed(6)}',
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