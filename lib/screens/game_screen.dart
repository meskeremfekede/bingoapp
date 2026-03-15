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

  Future<void> _deleteGame(String gameId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game?'),
        content: const Text('Are you sure you want to permanently remove this game record? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('games').doc(gameId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game deleted successfully.'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getGamesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No games found. Create one to get started!', style: TextStyle(color: Colors.white70)));
          }

          final allGames = snapshot.data!.docs;
          
          // FLEXIBLE FILTERING: Handles both lowercase and uppercase statuses
          final ongoingGames = allGames.where((doc) {
            final status = (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() ?? '';
            return status == 'ongoing';
          }).toList();

          final pendingGames = allGames.where((doc) {
            final status = (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() ?? '';
            return status == 'pending';
          }).toList();

          final completedGames = allGames.where((doc) {
            final status = (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() ?? '';
            return status == 'completed';
          }).toList();

          // Catch-all for games with no status or unknown status
          final otherGames = allGames.where((doc) {
            final status = (doc.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() ?? '';
            return status != 'ongoing' && status != 'pending' && status != 'completed';
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (ongoingGames.isNotEmpty) _buildGameSection('Ongoing Matches', ongoingGames),
              if (pendingGames.isNotEmpty) _buildGameSection('Pending Lobby', pendingGames),
              if (completedGames.isNotEmpty) _buildGameSection('Match History', completedGames),
              if (otherGames.isNotEmpty) _buildGameSection('Unknown/Legacy Status', otherGames),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGame,
        tooltip: 'Create Game',
        backgroundColor: Colors.yellow.shade700,
        child: const Icon(Icons.add, color: Colors.black87),
      ),
    );
  }

  Widget _buildGameSection(String title, List<DocumentSnapshot> games) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            return GameCard(
              game: game, 
              onTap: () => _navigateToGameControl(game.id),
              onDelete: () => _deleteGame(game.id),
            );
          },
        ),
        const Divider(height: 32, color: Colors.white10),
      ],
    );
  }
}

class GameCard extends StatelessWidget {
  final DocumentSnapshot game;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const GameCard({super.key, required this.game, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final data = game.data() as Map<String, dynamic>? ?? {};
    final String gameName = data['gameName'] as String? ?? 'Untitled Game';
    final String status = data['status']?.toString().toLowerCase() ?? 'unknown';
    final int playerCount = (data['players'] as List<dynamic>? ?? []).length;

    Color statusColor;
    switch (status) {
      case 'completed': statusColor = Colors.greenAccent; break;
      case 'ongoing': statusColor = Colors.yellow.shade700; break;
      case 'pending': statusColor = Colors.blueAccent; break;
      default: statusColor = Colors.white24;
    }

    return Card(
      color: const Color(0xFF1C1C3A),
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16.0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(gameName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
            Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text('$playerCount Players • ID: ${game.id.substring(0,5)}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white10),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
