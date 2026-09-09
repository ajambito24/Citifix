import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/step_indicator.dart';
import 'submit_success.dart';

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

  Future<void> submit() async {
    setState(() {
      submitting = true;
    });

    try {
      final reportId =
          await ReportService().submitReport(
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
          content: Text(
            'Failed to submit report: $e',
          ),
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const StepIndicator(currentStep: 3),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review Report',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _info(
                          'Category',
                          widget.category,
                        ),
                        _info(
                          'Description',
                          widget.description,
                        ),
                        _info(
                          'Latitude',
                          widget.latitude
                              .toStringAsFixed(6),
                        ),
                        _info(
                          'Longitude',
                          widget.longitude
                              .toStringAsFixed(6),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Photo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(10),
                          child: Image.memory(
                            widget.imageBytes,
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
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
              text: submitting
                  ? 'Submitting...'
                  : 'Submit Report',
              onPressed: submitting ? null : submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String title, String value) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: Text(value),
          ),
        ],
      ),
    );
  }
}