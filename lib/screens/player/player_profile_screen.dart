import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/screens/login_screen.dart';

class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({super.key});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<DocumentSnapshot> _getProfileStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection('players').doc(user.uid).snapshots();
  }

  // Function to show Change Password Dialog for Player
  void _showChangePasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
                validator: (value) {
                  if (value != passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await FirebaseAuth.instance.currentUser?.updatePassword(passwordController.text);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _getProfileStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Player profile not found.', style: TextStyle(color: Colors.white)));
          }

          final playerData = snapshot.data!.data()! as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Center(
                child: Column(
                  children: [
                    const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
                    const SizedBox(height: 16),
                    Text(playerData['name'] ?? 'Player', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Chip(label: Text('Rank: ${playerData['rank'] ?? 'Bronze'}', style: const TextStyle(color: Colors.black)), backgroundColor: Colors.amber),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white70),
                title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
                onTap: () { /* TODO: Implement Edit Profile */ },
              ),
              ListTile(
                leading: const Icon(Icons.lock, color: Colors.white70),
                title: const Text('Change Password', style: TextStyle(color: Colors.white)),
                onTap: () => _showChangePasswordDialog(context), // Implemented the change password dialog
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  await _auth.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (Route<dynamic> route) => false,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
