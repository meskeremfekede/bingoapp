import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/screens/player/player_game_board_screen.dart';

class PlayerGameLobbyScreen extends StatelessWidget {
  final String gameId;

  const PlayerGameLobbyScreen({super.key, required this.gameId});

  Stream<DocumentSnapshot> _getGameStream() {
    return FirebaseFirestore.instance.collection('games').doc(gameId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: _getGameStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final gameData = snapshot.data!.data()! as Map<String, dynamic>;
          final status = gameData['status'] as String? ?? 'pending';

          // JOURNEY STEP: If admin starts the game, move immediately to Game Board
          // because the player has already paid and selected flags.
          if (status == 'ongoing') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerGameBoardScreen(
                    gameId: gameId,
                    playerId: user?.uid ?? '',
                  ),
                ),
              );
            });
          }
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A1A),
          appBar: AppBar(
            title: const Text('WAITING ROOM'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
          ),
          body: _buildLobbyContent(snapshot),
        );
      },
    );
  }

  Widget _buildLobbyContent(AsyncSnapshot<DocumentSnapshot> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!snapshot.hasData || !snapshot.data!.exists) {
      return const Center(child: Text('Game not found.', style: TextStyle(color: Colors.white)));
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_empty, size: 80, color: Colors.amber),
          const SizedBox(height: 32),
          const Text(
            'YOU ARE READY!',
            style: TextStyle(color: Colors.greenAccent, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Payment Confirmed • Identity Selected',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 48),
          const CircularProgressIndicator(color: Colors.purpleAccent),
          const SizedBox(height: 24),
          const Text(
            'Waiting for the admin to start the match...',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 16, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 48),
          _buildRequirementChip('Join Code', true),
          _buildRequirementChip('Card Selection', true),
          _buildRequirementChip('Payment', true),
          _buildRequirementChip('Identity (Flags)', true),
        ],
      ),
    );
  }

  Widget _buildRequirementChip(String label, bool isDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: isDone ? Colors.green : Colors.grey, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: isDone ? Colors.white : Colors.white24, fontSize: 16)),
        ],
      ),
    );
  }
}
