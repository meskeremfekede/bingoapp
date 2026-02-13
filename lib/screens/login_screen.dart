import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/main.dart';
import 'package:mygame/screens/player_app_shell.dart';
import 'package:mygame/services/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  String _email = '';
  String _password = '';
  String _fullName = '';
  String _phoneNumber = '';
  String _registrationCode = '';
  bool _isLoading = false;

  // Hardcoded admin email for role distinction
  static const String _adminEmail = 'chatu@gmail.com';

  void _submitAuthForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(email: _email, password: _password);
      } else {
        // Check registration code before creating an account
        final codeDoc = await _firestore.collection('config').doc('app_settings').get();
        final correctCode = codeDoc.data()?['registrationCode'] as String? ?? '';

        if (_registrationCode != correctCode && _email != _adminEmail) {
          throw FirebaseAuthException(code: 'invalid-registration-code', message: 'The registration code is incorrect.');
        }

        final newUser = await _auth.createUserWithEmailAndPassword(email: _email, password: _password);
        // Create a corresponding user document in Firestore
        await FirebaseService().createPlayerDocument(newUser.user!.uid, _fullName, _email, _phoneNumber, 0.0);
      }
      // Navigate after successful login/signup
      _navigateUser();
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication failed.'), backgroundColor: Colors.red),
      );
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateUser() {
    final user = _auth.currentUser;
    if (user != null) {
      if (user.email == _adminEmail) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AppShell()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PlayerAppShell()));
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Enter your email'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty) {
                try {
                  await _auth.sendPasswordResetEmail(email: emailController.text);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_isLogin ? 'Login' : 'Create Account', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                if (!_isLogin)
                  TextFormField(
                    key: const ValueKey('fullName'),
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (v) => v!.isEmpty ? 'Please enter your name' : null,
                    onSaved: (v) => _fullName = v!,
                  ),
                if (!_isLogin)
                  TextFormField(
                    key: const ValueKey('phoneNumber'),
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    validator: (v) => v!.isEmpty ? 'Please enter your phone number' : null,
                    onSaved: (v) => _phoneNumber = v!,
                  ),
                TextFormField(
                  key: const ValueKey('email'),
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => !(v?.contains('@') ?? false) ? 'Please enter a valid email' : null,
                  onSaved: (v) => _email = v!,
                ),
                TextFormField(
                  key: const ValueKey('password'),
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => (v?.length ?? 0) < 6 ? 'Password must be at least 6 characters' : null,
                  onSaved: (v) => _password = v!,
                ),
                if (!_isLogin && _email != _adminEmail) // Admin doesn't need a registration code
                  TextFormField(
                    key: const ValueKey('regCode'),
                    decoration: const InputDecoration(labelText: 'Registration Code'),
                    validator: (v) => v!.isEmpty ? 'Please enter the registration code' : null,
                    onSaved: (v) => _registrationCode = v!,
                  ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: _submitAuthForm,
                    child: Text(_isLogin ? 'Login' : 'Create Account'),
                  ),
                if (!_isLoading)
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? 'Create a new account' : 'I already have an account'),
                  ),
                if (_isLogin)
                  TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text('Forgot Password?'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
