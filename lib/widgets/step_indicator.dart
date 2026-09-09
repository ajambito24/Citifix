import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;

  const StepIndicator({
    super.key,
    required this.currentStep,
  });

  final List<String> steps = const [
    'Category',
    'Details',
    'Location',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        steps.length,
        (index) {
          final active = index <= currentStep;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index != 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index <= currentStep
                              ? Colors.blue
                              : Colors.grey.shade300,
                        ),
                      ),

                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? Colors.blue
                            : Colors.white,
                        border: Border.all(
                          color: active
                              ? Colors.blue
                              : Colors.grey,
                        ),
                      ),
                      child: active
                          ? const Icon(
                              Icons.check,
                              size: 13,
                              color: Colors.white,
                            )
                          : null,
                    ),

                    if (index != steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < currentStep
                              ? Colors.blue
                              : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: active
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}