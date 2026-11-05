import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Your Cloudinary credentials
  final String cloudName = 'e7d4ahld';
  final String uploadPreset = 'Citifix'; 

  // Submit a new report with Cloudinary image upload
  Future<String> submitReport({
    required String category,
    required String description,
    required String streetAddress,
    required String barangay,
    required double latitude,
    required double longitude,
    required Uint8List imageBytes,
    String? imageName,
  }) async {
    try {
      // Get current user
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to submit a report');
      }

      // Get user data from Firestore
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

      // Prepare report data
      final reportData = {
        'userId': user.uid,
        'userEmail': user.email,
        'userFullName': fullName,
        'category': category,
        'description': description,
        'streetAddress': streetAddress,
        'barangay': barangay,
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

      // Create the document reference first (the ID is generated locally,
      // no network call) so the reference number can be built from it.
      final docRef = _firestore.collection('reports').doc();
      final referenceNumber = docRef.id.substring(0, 8).toUpperCase();

      // Add report to Firestore, saving the reference number with it
      await docRef.set({
        ...reportData,
        'referenceNumber': referenceNumber,
      });

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

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      );
      
      // Add upload preset and other parameters
      request.fields['upload_preset'] = uploadPreset;
      request.fields['public_id'] = 'reports/${DateTime.now().millisecondsSinceEpoch}';
      request.fields['folder'] = 'reports';
      
      // Add the image file
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: imageName,
        ),
      );
      
      // Send request
      print('📸 Sending request to Cloudinary...');
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);
      
      if (response.statusCode != 200) {
        print('❌ Cloudinary error: $responseData');
        throw Exception('Cloudinary upload failed: ${jsonResponse['error']?['message'] ?? responseData}');
      }
      
      // Get the secure URL from Cloudinary response
      final imageUrl = jsonResponse['secure_url'];
      print('✅ Image uploaded to Cloudinary: $imageUrl');
      
      return imageUrl;
    } catch (e) {
      print('❌ Cloudinary upload error: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Get all reports for the current user
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

  // Get all reports (for admin)
  Stream<QuerySnapshot> getAllReports() {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get reports by status (for admin filtering)
  Stream<QuerySnapshot> getReportsByStatus(String status) {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Update report status (admin only). Writes statusHistory in the same
  // format as update_status.php: {status, at, by}.
  Future<void> updateReportStatus({
    required String reportId,
    required String status, // 'pending' | 'in progress' | 'resolved' | 'rejected'
    String? adminNotes,
  }) async {
    try {
      final normalized = status.trim().toLowerCase();
      final isResolved = normalized == 'resolved';

      final updateData = <String, dynamic>{
        'status': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
        'resolvedAt': isResolved ? FieldValue.serverTimestamp() : null,
        'isResolved': isResolved,
        // serverTimestamp() isn't allowed inside arrays, so use the device time here.
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': normalized,
            'at': Timestamp.now(),
            'by': _auth.currentUser?.email,
          }
        ]),
        if (adminNotes != null) 'adminNotes': adminNotes,
      };

      await _firestore.collection('reports').doc(reportId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update report: $e');
    }
  }

  // Delete a report
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

  // Get a single report
  Future<DocumentSnapshot> getReport(String reportId) async {
    return await _firestore
        .collection('reports')
        .doc(reportId)
        .get();
  }

  // Get report statistics for dashboard
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