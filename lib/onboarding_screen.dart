import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController medicalHistoryController = TextEditingController();

  String? gender;

  void saveUserData() async {
    if (_formKey.currentState!.validate() && gender != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = {
          "name": nameController.text.trim(),
          "age": int.parse(ageController.text.trim()),
          "gender": gender,
          "weight": double.tryParse(weightController.text.trim()) ?? 0,
          "height": double.tryParse(heightController.text.trim()) ?? 0,
          "medicalHistory": medicalHistoryController.text.trim(),
          "createdAt": FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(userData);

        // ✅ Set onboarding complete
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('seenOnboard', true);

        // Navigate to Dashboard after saving
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } else if (gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a gender')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your name' : null,
                ),
                TextFormField(
                  controller: ageController,
                  decoration: const InputDecoration(labelText: 'Age'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your age';
                    final age = int.tryParse(value);
                    if (age == null || age <= 0) return 'Enter a valid age';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Gender:'),
                    const SizedBox(width: 20),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: gender,
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            gender = value;
                          });
                        },
                        validator: (value) =>
                        value == null ? 'Please select your gender' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: weightController,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                TextFormField(
                  controller: heightController,
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                TextFormField(
                  controller: medicalHistoryController,
                  decoration: const InputDecoration(labelText: 'Medical History'),
                  maxLines: 3,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: saveUserData,
                  child: const Text('Save & Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
