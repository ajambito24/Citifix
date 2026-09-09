import 'package:flutter/material.dart';

import '../../widgets/primary_button.dart';
import '../../widgets/step_indicator.dart';
import 'review_submit.dart';

class MapPage extends StatelessWidget {
  final String category;
  final String description;
  final dynamic imageBytes;
  final String imageName;
  final double latitude;
  final double longitude;

  const MapPage({
    super.key,
    required this.category,
    required this.description,
    this.imageBytes,
    this.imageName = '',
    this.latitude = 14.5995,
    this.longitude = 120.9842,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasReportData =
        category.isNotEmpty && description.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF7),
      appBar: AppBar(
        title: const Text(
          'Location',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (hasReportData) ...[
              const StepIndicator(currentStep: 2),
              const SizedBox(height: 20),
            ],

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        size: 65,
                        color: Colors.red,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'CitiFix Location',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'GPS location captured',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 25),

                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 25,
                      ),
                      padding: const EdgeInsets.all(15),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEF7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.my_location,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Coordinates',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Text(
                            'Latitude: ${latitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            'Longitude: ${longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 30,
                      ),
                      child: Text(
                        'Your current location will be attached to this report.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (hasReportData) ...[
              const SizedBox(height: 15),

              PrimaryButton(
                text: 'Continue to Review',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewSubmit(
                        category: category,
                        description: description,
                        imageBytes: imageBytes,
                        imageName: imageName,
                        latitude: latitude,
                        longitude: longitude,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}