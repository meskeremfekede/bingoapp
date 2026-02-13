import 'dart:math';
import 'package:flutter/material.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  // State for Registration Code
  String _registrationCode = 'BINGO123';
  final int _registrationNumber = 15; // Mock number

  // State for Password Change
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _generateNewCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  void _changeRegistrationCode() {
    // In a real app, this might open a dialog to let the admin type a new code.
    // For this example, we'll just generate a new random one.
    setState(() {
      _registrationCode = _generateNewCode();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registration code has been changed!')),
    );
  }

  void _changePassword() {
    if (_formKey.currentState!.validate()) {
      // TODO: Implement password change logic
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully!')),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Registration Code Section
            const Text(
              'Game Registration',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              elevation: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Current Registration Code', style: TextStyle(color: Colors.black54)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(_registrationCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                    ),
                    Text('Number: $_registrationNumber', style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _changeRegistrationCode,
                      icon: const Icon(Icons.edit),
                      label: const Text('Change Registration Code'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            // Change Password Section
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Change Password',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  _buildTextFormField(
                    controller: _currentPasswordController,
                    labelText: 'Current Password',
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your current password';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextFormField(
                    controller: _newPasswordController,
                    labelText: 'New Password',
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter a new password';
                      if (value.length < 6) return 'Password must be at least 6 characters long';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextFormField(
                    controller: _confirmPasswordController,
                    labelText: 'Confirm New Password',
                    validator: (value) {
                      if (value != _newPasswordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _changePassword,
                    icon: const Icon(Icons.check),
                    label: const Text('Apply Change'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({required TextEditingController controller, required String labelText, required FormFieldValidator<String> validator}) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
      validator: validator,
    );
  }
}
