import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/screens/player/player_card_selection_screen.dart';
import 'package:mygame/screens/player/player_game_lobby_screen.dart';
import 'package:mygame/screens/player/player_game_board_screen.dart';

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
      setState(() { _isLoading = true; });

      final user = _auth.currentUser;
      if (user == null) return;

      try {
        final gameQuery = await FirebaseFirestore.instance
            .collection('games')
            .where('gameCode', isEqualTo: _gameCodeController.text)
            .limit(1)
            .get();

        if (gameQuery.docs.isEmpty) {
          throw Exception('Incorrect game code.');
        }

        final gameDoc = gameQuery.docs.first;
        final gameId = gameDoc.id;
        final gameData = gameDoc.data();
        print('🎮 JOIN SCREEN: Found game ID: $gameId for player ${user.uid}');
        
        // 1. Join Game Logic
        await _firebaseService.joinGameLobby(gameId: gameId, playerId: user.uid);
        print('🎮 JOIN SCREEN: Successfully joined game lobby');

        if (mounted) {
          // 2. Journey Step: Check if player already paid and selected flags
          final hasPaid = gameData.containsKey('${user.uid}_paymentStatus') && gameData['${user.uid}_paymentStatus'] == 'paid';
          final hasFlags = gameData.containsKey('${user.uid}_selectedFlags') && (gameData['${user.uid}_selectedFlags'] as List).isNotEmpty;
          final gameStatus = gameData['status'] as String? ?? 'pending';

          if (hasPaid && hasFlags) {
            // Player already paid and selected flags, move to waiting room or game board
            if (gameStatus == 'ongoing') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => PlayerGameBoardScreen(gameId: gameId, playerId: user.uid)),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => PlayerGameLobbyScreen(gameId: gameId)),
              );
            }
          } else {
            // Player hasn't finished the process, go to Card Selection
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => CardSelectionScreen(gameId: gameId)),
            );
          }
        }
      } catch (e) {
        print('🎮 JOIN SCREEN ERROR: Failed to join - $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
          );
        }
      } finally {
        if (mounted) setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(title: const Text('Join Match'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_scanner, size: 80, color: Colors.purpleAccent),
              const SizedBox(height: 32),
              TextFormField(
                controller: _gameCodeController,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24),
                decoration: InputDecoration(
                  hintText: 'ENTER GAME CODE',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1C1C3A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _joinGame,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                  child: _isLoading ? const CircularProgressIndicator() : const Text('CONTINUE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
