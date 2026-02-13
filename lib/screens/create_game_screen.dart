import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateGameScreen extends StatefulWidget {
  const CreateGameScreen({super.key});

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  final _formKey = GlobalKey<FormState>();

  final _gameNameController = TextEditingController();
  final _gameCodeController = TextEditingController();
  final _maxPlayersController = TextEditingController();
  final _maxCardsController = TextEditingController();
  final _cardCostController = TextEditingController();

  String? _winningPattern; // Fixed spelling
  bool _isSaving = false;

  final List<String> _winningPatterns = [ // Fixed spelling
    'Any Line',
    'Horizontal',
    'Vertical',
    'Diagonal',
    'Four Corners',
    'Full House',
  ];

  @override
  void initState() {
    super.initState();
    _winningPattern = _winningPatterns.first;
    _gameCodeController.text = _generateGameCode();
  }

  String _generateGameCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  void _saveGame() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final adminId = FirebaseAuth.instance.currentUser?.uid;
      if (adminId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Admin user not found. Please log in again.'), backgroundColor: Colors.red),
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      try {
        await FirebaseFirestore.instance.collection('games').add({
          'gameName': _gameNameController.text,
          'gameCode': _gameCodeController.text,
          'maxPlayers': int.tryParse(_maxPlayersController.text) ?? 0,
          'maxCards': int.tryParse(_maxCardsController.text) ?? 0,
          'cardCost': double.tryParse(_cardCostController.text) ?? 0.0,
          'winningPattern': _winningPattern,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'adminId': adminId, // Save the admin's ID
          'totalCardsSold': 0, // Initialize the card counter
          'calledNumbers': [],
          'winner': null,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Game "${_gameNameController.text}" saved successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save game: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _gameNameController.dispose();
    _gameCodeController.dispose();
    _maxPlayersController.dispose();
    _maxCardsController.dispose();
    _cardCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Game', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              _buildTextFormField(controller: _gameNameController, labelText: 'Game Name'),
              const SizedBox(height: 12),
              _buildTextFormField(controller: _gameCodeController, labelText: 'Game Code', hintText: 'Editable join code for players'),
              const SizedBox(height: 12),
              _buildTextFormField(controller: _maxPlayersController, labelText: 'Max Players', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _buildTextFormField(controller: _maxCardsController, labelText: 'Max Cards per Player', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _buildTextFormField(controller: _cardCostController, labelText: 'Cost per Card (ETB)', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _winningPattern,
                decoration: _inputDecoration('Winning Pattern'),
                items: _winningPatterns.map((String pattern) {
                  return DropdownMenuItem<String>(value: pattern, child: Text(pattern));
                }).toList(),
                onChanged: (newValue) => setState(() => _winningPattern = newValue),
                validator: (value) => value == null ? 'Please select a pattern' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveGame,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Game'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _buildTextFormField({required TextEditingController controller, required String labelText, String? hintText, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(labelText, hintText),
      keyboardType: keyboardType,
      validator: (value) => (value == null || value.isEmpty) ? 'Please enter a $labelText' : null,
    );
  }

  InputDecoration _inputDecoration(String labelText, [String? hintText]) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }
}
