import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/screens/create_game_screen.dart';
import 'package:mygame/screens/admin/admin_game_control_screen.dart';
import 'package:mygame/widgets/player_name_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Stream<QuerySnapshot> _getGamesStream() {
    return FirebaseFirestore.instance.collection('games').orderBy('createdAt', descending: true).snapshots();
  }

  void _navigateToCreateGame() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateGameScreen()));
  }

  void _navigateToGameControl(String gameId) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AdminGameControlScreen(gameId: gameId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A), // Dark Theme
      body: StreamBuilder<QuerySnapshot>(
        stream: _getGamesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No games found. Create one to get started!', style: TextStyle(color: Colors.white70)));
          }

          final allGames = snapshot.data!.docs;
          final ongoingGames = allGames.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'ongoing').toList();
          final pendingGames = allGames.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'pending').toList();
          final completedGames = allGames.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'completed').toList();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (ongoingGames.isNotEmpty)
                _buildGameSection('Ongoing Games', ongoingGames),
              if (pendingGames.isNotEmpty)
                _buildGameSection('Available to Join', pendingGames),
              if (completedGames.isNotEmpty)
                _buildGameSection('Completed Games', completedGames),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGame,
        tooltip: 'Create Game',
        child: const Icon(Icons.add, color: Colors.black87),
        backgroundColor: Colors.yellow.shade700, // Yellow Accent
      ),
    );
  }

  Widget _buildGameSection(String title, List<DocumentSnapshot> games) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            return GameCard(game: game, onTap: () => _navigateToGameControl(game.id));
          },
        ),
        const Divider(height: 32, color: Colors.white24),
      ],
    );
  }
}

class GameCard extends StatelessWidget {
  final DocumentSnapshot game;
  final VoidCallback onTap;
  const GameCard({super.key, required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = game.data() as Map<String, dynamic>? ?? {};

    final String gameName = data['gameName'] as String? ?? 'Untitled Game';
    final String winningPattern = data['winningPattern'] as String? ?? 'N/A'; // Fixed spelling
    final String status = data['status'] as String? ?? 'UNKNOWN';
    final int playerCount = (data['players'] as List<dynamic>? ?? []).length;

    String? firstWinnerId;
    final List<dynamic> winners = data['winners'] as List<dynamic>? ?? [];
    if (winners.isNotEmpty) {
      final firstWinnerMap = winners.first as Map<String, dynamic>?;
      if (firstWinnerMap != null) {
        firstWinnerId = firstWinnerMap['playerId'] as String?;
      }
    }

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = Colors.greenAccent;
        break;
      case 'ongoing':
        statusColor = Colors.yellow.shade700;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      color: const Color(0xFF1C1C3A), // Dark Card Color
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(gameName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people, size: 16, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text('$playerCount Players', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(width: 16),
                  const Icon(Icons.emoji_events, size: 16, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(winningPattern, style: const TextStyle(color: Colors.white70)),
                ],
              ),
              if (status == 'completed')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Text('Winner: ', style: TextStyle(color: Colors.white70)),
                      if (firstWinnerId != null)
                        PlayerNameWidget(playerId: firstWinnerId)
                      else
                        const Text('N/A', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
