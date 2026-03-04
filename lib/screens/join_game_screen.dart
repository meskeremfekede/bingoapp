import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/screens/player/player_card_selection_screen.dart';

class JoinGameScreen extends StatefulWidget {
  const JoinGameScreen({super.key});

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gameCodeController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _joinGame() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to join a game.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      try {
        final gameQuery = await FirebaseFirestore.instance
            .collection('games')
            .where('gameCode', isEqualTo: _gameCodeController.text)
            .limit(1)
            .get();

        if (gameQuery.docs.isEmpty) {
          throw Exception('No game found with that code. Please check the code and try again.');
        }

        final gameId = gameQuery.docs.first.id;
        final gameData = gameQuery.docs.first.data();
        final gameStatus = gameData['status'] as String? ?? 'pending';

        // Allow joining even if game started, but go to card selection
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CardSelectionScreen(gameId: gameId)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to join game: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Game'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _gameCodeController,
                  decoration: const InputDecoration(labelText: 'Enter Game Code'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a game code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _joinGame,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Join Game'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
