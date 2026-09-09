import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../widgets/primary_button.dart';
import '../../widgets/step_indicator.dart';

// ==================== REPORT SERVICE (CLOUDINARY ONLY) ====================
class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Cloudinary credentials
  final String cloudName = 'e7d4ahld';
  final String uploadPreset = 'Citifix';

  Future<String> submitReport({
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    required Uint8List imageBytes,
    String? imageName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to submit a report');
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      String fullName = 'Unknown User';
      if (userDoc.exists) {
        fullName = userDoc.data()?['fullName'] ?? 'Unknown User';
      }

      // Upload image to Cloudinary
      String imageUrl = await _uploadImageToCloudinary(
        imageBytes: imageBytes,
        imageName: imageName ?? 'report_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final reportData = {
        'userId': user.uid,
        'userEmail': user.email,
        'userFullName': fullName,
        'category': category,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'imageUrl': imageUrl,  // Cloudinary URL
        'imageName': imageName ?? 'photo.jpg',
        'status': 'pending',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'adminNotes': '',
        'resolvedAt': null,
        'assignedTo': null,
        'isResolved': false,
      };

      final docRef = await _firestore
          .collection('reports')
          .add(reportData);

      print('✅ Report submitted with Cloudinary image!');
      return docRef.id;
    } catch (e) {
      print('❌ Error submitting report: $e');
      throw Exception('Failed to submit report: $e');
    }
  }

  // Upload image to Cloudinary
  Future<String> _uploadImageToCloudinary({
    required Uint8List imageBytes,
    required String imageName,
  }) async {
    try {
      print('📸 Uploading image to Cloudinary...');
      print('📸 Image size: ${imageBytes.length} bytes');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      );
      
      request.fields['upload_preset'] = uploadPreset;
      request.fields['public_id'] = 'reports/${DateTime.now().millisecondsSinceEpoch}';
      request.fields['folder'] = 'reports';
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: imageName,
        ),
      );
      
      print('📸 Sending request to Cloudinary...');
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);
      
      if (response.statusCode != 200) {
        print('❌ Cloudinary error: $responseData');
        throw Exception('Cloudinary upload failed: ${jsonResponse['error']?['message'] ?? responseData}');
      }
      
      final imageUrl = jsonResponse['secure_url'];
      print('✅ Image uploaded to Cloudinary: $imageUrl');
      
      return imageUrl;
    } catch (e) {
      print('❌ Cloudinary upload error: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  Stream<QuerySnapshot> getMyReports() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return _firestore
        .collection('reports')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getAllReports() {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteReport(String reportId) async {
    try {
      await _firestore
          .collection('reports')
          .doc(reportId)
          .delete();
      print('✅ Report deleted successfully');
    } catch (e) {
      throw Exception('Failed to delete report: $e');
    }
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? adminNotes,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (adminNotes != null) 'adminNotes': adminNotes,
        if (status == 'resolved') 'resolvedAt': FieldValue.serverTimestamp(),
        if (status == 'resolved') 'isResolved': true,
      };

      await _firestore
          .collection('reports')
          .doc(reportId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update report: $e');
    }
  }

  Future<DocumentSnapshot> getReport(String reportId) async {
    return await _firestore
        .collection('reports')
        .doc(reportId)
        .get();
  }

  Future<Map<String, dynamic>> getReportStats() async {
    try {
      final allReports = await _firestore.collection('reports').get();
      final pending = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .get();
      final resolved = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'resolved')
          .get();

      return {
        'total': allReports.docs.length,
        'pending': pending.docs.length,
        'resolved': resolved.docs.length,
      };
    } catch (e) {
      throw Exception('Failed to get report stats: $e');
    }
  }
}

// ==================== REPORT CATEGORY SCREEN ====================
class ReportCategory extends StatefulWidget {
  const ReportCategory({super.key});

  @override
  State<ReportCategory> createState() => _ReportCategoryState();
}

class _ReportCategoryState extends State<ReportCategory> {
  String selectedCategory = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF7),
      appBar: AppBar(
        title: const Text('Report Issue'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const StepIndicator(currentStep: 0),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Issue Category',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'What problem would you like to report?',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 15),
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
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No categories available.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final name = data['name']?.toString() ?? docs[index].id;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: selectedCategory == name ? 4 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: selectedCategory == name
                                ? Colors.blue
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: name,
                          groupValue: selectedCategory,
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          secondary: Icon(
                            _getIconForCategory(name),
                            color: Colors.blue,
                          ),
                          activeColor: Colors.blue,
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value ?? '';
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            PrimaryButton(
              text: 'Next',
              onPressed: selectedCategory.isEmpty
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportDetails(
                            category: selectedCategory,
                          ),
                        ),
                      );
                    },
            ),
          ],
        ),
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
}

// ==================== REPORT DETAILS SCREEN ====================
class ReportDetails extends StatefulWidget {
  final String category;

  const ReportDetails({
    super.key,
    required this.category,
  });

  @override
  State<ReportDetails> createState() => _ReportDetailsState();
}

class _ReportDetailsState extends State<ReportDetails> {
  final TextEditingController descriptionController = TextEditingController();
  final ImagePicker picker = ImagePicker();
  Uint8List? imageBytes;
  String? imageName;

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> selectPhoto() async {
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Add Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Colors.blue,
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  selectPhoto();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: Colors.blue,
                ),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  takePhoto();
                },
              ),
              if (imageBytes != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      imageBytes = null;
                      imageName = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void next() {
    final description = descriptionController.text.trim();

    if (description.isEmpty) {
      showMessage('Please describe the issue.');
      return;
    }

    if (imageBytes == null) {
      showMessage('Please upload a photo of the issue.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SetLocation(
          category: widget.category,
          description: description,
          imageBytes: imageBytes!,
          imageName: imageName,
        ),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF7),
      appBar: AppBar(
        title: const Text('Report Issue'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const StepIndicator(currentStep: 1),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.category,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Provide details about the issue',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the issue in detail...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: showPhotoOptions,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: imageBytes == null ? Colors.blue : Colors.green,
                    width: 2,
                  ),
                ),
                child: imageBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            size: 45,
                            color: Colors.blue,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Upload Photo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Tap here to choose a photo',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.memory(
                              imageBytes!,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (imageBytes != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      imageName ?? 'Photo selected',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            PrimaryButton(
              text: 'Next',
              onPressed: next,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SET LOCATION SCREEN ====================
class SetLocation extends StatefulWidget {
  final String category;
  final String description;
  final Uint8List imageBytes;
  final String? imageName;

  const SetLocation({
    super.key,
    required this.category,
    required this.description,
    required this.imageBytes,
    this.imageName,
  });

  @override
  State<SetLocation> createState() => _SetLocationState();
}

class _SetLocationState extends State<SetLocation> {
  Position? position;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getLocation();
    });
  }

  Future<void> getLocation() async {
    setState(() {
      loading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        showMessage('Please enable Location Services.');
        setState(() => loading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        showMessage('Location permission was denied.');
        setState(() => loading = false);
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        showMessage(
          'Location permission is permanently denied. '
          'Please enable it in device settings.',
        );
        setState(() => loading = false);
        return;
      }

      final result = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        position = result;
      });
    } catch (e) {
      showMessage('Unable to get location: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void continueToReview() {
    if (position == null) {
      showMessage('Please get your current location first.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSubmit(
          category: widget.category,
          description: widget.description,
          imageBytes: widget.imageBytes,
          imageName: widget.imageName,
          latitude: position!.latitude,
          longitude: position!.longitude,
        ),
      ),
    );
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF7),
      appBar: AppBar(
        title: const Text('Set Location'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const StepIndicator(currentStep: 2),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your Location',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'We need your current location to send help',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: position == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_off,
                            size: 70,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'Location not selected',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Get your current GPS location.',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (loading)
                            const CircularProgressIndicator()
                          else
                            ElevatedButton.icon(
                              onPressed: getLocation,
                              icon: const Icon(Icons.my_location),
                              label: const Text('Get Location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 70,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'Location Selected',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Latitude: ${position!.latitude.toStringAsFixed(6)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Longitude: ${position!.longitude.toStringAsFixed(6)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: getLocation,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Location'),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 15),
            PrimaryButton(
              text: 'Review Report',
              onPressed: position == null || loading ? null : continueToReview,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== REVIEW & SUBMIT SCREEN ====================
class ReviewSubmit extends StatefulWidget {
  final String category;
  final String description;
  final Uint8List imageBytes;
  final String? imageName;
  final double latitude;
  final double longitude;

  const ReviewSubmit({
    super.key,
    required this.category,
    required this.description,
    required this.imageBytes,
    this.imageName,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<ReviewSubmit> createState() => _ReviewSubmitState();
}

class _ReviewSubmitState extends State<ReviewSubmit> {
  bool submitting = false;
  final ReportService _reportService = ReportService();

  Future<void> submit() async {
    setState(() {
      submitting = true;
    });

    try {
      final reportId = await _reportService.submitReport(
        category: widget.category,
        description: widget.description,
        latitude: widget.latitude,
        longitude: widget.longitude,
        imageBytes: widget.imageBytes,
        imageName: widget.imageName,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => SubmitSuccess(
            reportId: reportId,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF7),
      appBar: AppBar(
        title: const Text('Review Report'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const StepIndicator(currentStep: 3),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Review Your Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Please verify all information before submitting',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const Divider(),
                        _buildInfoRow(
                          'Category',
                          widget.category,
                          Icons.category,
                          Colors.orange,
                        ),
                        _buildInfoRow(
                          'Description',
                          widget.description,
                          Icons.description,
                          Colors.blue,
                        ),
                        _buildInfoRow(
                          'Location',
                          '${widget.latitude.toStringAsFixed(6)}, '
                          '${widget.longitude.toStringAsFixed(6)}',
                          Icons.location_on,
                          Colors.red,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Photo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            widget.imageBytes,
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (widget.imageName != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '📷 ${widget.imageName}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Your report will be reviewed by our team. '
                                  'You will be notified of updates.',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
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
            ),
            const SizedBox(height: 15),
            PrimaryButton(
              text: submitting ? 'Submitting...' : 'Submit Report',
              onPressed: submitting ? null : submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== SUBMIT SUCCESS SCREEN ====================
class SubmitSuccess extends StatelessWidget {
  final String reportId;

  const SubmitSuccess({
    super.key,
    required this.reportId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF7),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Report Submitted!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your report has been submitted successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Reference Number:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '#${reportId.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Our team will review your report and take action.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/home',
                              (route) => false,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.blue),
                          ),
                          child: const Text('Go Home'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/reports',
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('My Reports'),
                        ),
                      ),
                    ],
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