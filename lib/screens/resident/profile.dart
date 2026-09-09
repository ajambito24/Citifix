import 'package:flutter/material.dart';

import '../../widgets/app_bottom_nav.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF7),

      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(12),
          ),

          child: Column(
            children: [
              // PROFILE ICON
              const CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person,
                  size: 55,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(height: 20),

              // FIRST NAME
              _field(
                label: 'Firstname',
                value: 'Mateo',
              ),

              const SizedBox(height: 10),

              // LAST NAME
              _field(
                label: 'Lastname',
                value: 'Santos',
              ),

              const SizedBox(height: 10),

              // EMAIL
              _field(
                label: 'Email',
                value: 'mateosantos@gmail.com',
              ),

              const SizedBox(height: 10),

              // PHONE
              _field(
                label: 'Phone Number',
                value: '+63 ***********',
              ),

              const SizedBox(height: 15),

              // EDIT BUTTON
              Align(
                alignment: Alignment.centerLeft,

                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Profile editing will be connected to Firebase next.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
            ],
          ),
        ),
      ),

      // BOTTOM NAVIGATION
      bottomNavigationBar: const AppBottomNav(
        currentIndex: 3,
      ),
    );
  }

  Widget _field({
    required String label,
    required String value,
  }) {
    return TextField(
      controller: TextEditingController(
        text: value,
      ),

      readOnly: true,

      decoration: InputDecoration(
        labelText: label,

        filled: true,

        fillColor: Colors.white,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Colors.transparent,
          ),
        ),
      ),
    );
  }
}