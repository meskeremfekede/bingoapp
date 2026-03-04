import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/screens/player/player_card_selection_screen.dart';
import 'package:mygame/screens/player/player_game_board_screen.dart';
import 'package:mygame/screens/player/player_flag_selection_screen.dart';

class ActiveGame {
  final String id;
  final String gameName;
  final String gameCode;
  final int maxPlayers;
  final int joinedPlayers;
  final double entryFee;
  final int maxCardsPerPlayer;
  final String winningPattern;

  ActiveGame.fromFirestore(DocumentSnapshot doc) :
    id = doc.id,
    gameName = (doc.data() as Map<String, dynamic>)?['gameName'] ?? 'N/A',
    gameCode = (doc.data() as Map<String, dynamic>)?['gameCode'] ?? '',
    maxPlayers = (doc.data() as Map<String, dynamic>)?['maxPlayers'] ?? 0,
    joinedPlayers = ((doc.data() as Map<String, dynamic>)?['players'] as List?)?.length ?? 0,
    entryFee = ((doc.data() as Map<String, dynamic>)?['cardCost'] as num?)?.toDouble() ?? 0.0,
    maxCardsPerPlayer = (doc.data() as Map<String, dynamic>)?['maxCards'] ?? 0,
    winningPattern = (doc.data() as Map<String, dynamic>)?['winningPattern'] ?? 'N/A'; // Fixed spelling
}

class PlayerGamesScreen extends StatefulWidget {
  const PlayerGamesScreen({super.key});

  @override
  State<PlayerGamesScreen> createState() => _PlayerGamesScreenState();
}

class _PlayerGamesScreenState extends State<PlayerGamesScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<ActiveGame>> _getPendingGames() {
    return FirebaseFirestore.instance
        .collection('games')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ActiveGame.fromFirestore(doc)).toList());
  }

  Stream<List<ActiveGame>> _getOngoingGames() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('games')
        .where('status', isEqualTo: 'ongoing')
        .where('players', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ActiveGame.fromFirestore(doc)).toList());
  }

  void _showJoinGameDialog(ActiveGame game) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join Game: ${game.gameName}'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(labelText: 'Enter Game Code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (codeController.text == game.gameCode) {
                Navigator.of(context).pop();
                _joinGame(game);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect game code.'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinGame(ActiveGame game) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Go directly to card selection instead of lobby
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CardSelectionScreen(gameId: game.id)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to join game: ${e.toString()}")),
      );
    }
  }

  void _rejoinGame(ActiveGame game) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // Go directly to card selection for rejoining too
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CardSelectionScreen(gameId: game.id)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to rejoin game: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildGameSection(
            title: 'Ongoing Games',
            stream: _getOngoingGames(),
            onTap: _rejoinGame,
            buttonText: 'Rejoin',
            emptyMessage: 'No games in progress.',
          ),
          const SizedBox(height: 24),
          _buildGameSection(
            title: 'Available Games',
            stream: _getPendingGames(),
            onTap: _showJoinGameDialog, // Changed to show dialog
            buttonText: 'Join Game',
            emptyMessage: 'No active games available.',
          ),
        ],
      ),
    );
  }

  Widget _buildGameSection({
    required String title,
    required Stream<List<ActiveGame>> stream,
    required void Function(ActiveGame) onTap,
    required String buttonText,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<List<ActiveGame>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text(emptyMessage, style: const TextStyle(color: Colors.white70)));
            }
            final games = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return GameCard(game: game, onJoin: () => onTap(game), buttonText: buttonText);
              },
            );
          },
        ),
      ],
    );
  }
}

class GameCard extends StatelessWidget {
  final ActiveGame game;
  final VoidCallback onJoin;
  final String buttonText;

  const GameCard({super.key, required this.game, required this.onJoin, required this.buttonText});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1C1C3A),
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(game.gameName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white24, height: 20),
            _buildInfoRow('Players:', '${game.joinedPlayers} / ${game.maxPlayers}'),
            _buildInfoRow('Entry Fee:', '${game.entryFee.toStringAsFixed(2)} Birr per card'),
            _buildInfoRow('Max Cards:', '${game.maxCardsPerPlayer}'),
            _buildInfoRow('Pattern:', game.winningPattern),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onJoin,
                child: Text(buttonText),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade300),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
