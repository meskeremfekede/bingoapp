import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/config/game_config.dart';

class CompletedGamesScreen extends StatelessWidget {
  const CompletedGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A1A),
        body: Center(child: Text('Please log in to see your game history.', style: TextStyle(color: Colors.white70))),
      );
    }

    final Stream<QuerySnapshot> completedGamesStream = FirebaseFirestore.instance
        .collection('games')
        .where('state', isEqualTo: 'FINISHED')
        .where('playersJoined', arrayContains: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('Completed Games'),
        backgroundColor: const Color(0xFF0A0A1A),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: completedGamesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No completed games found.', style: TextStyle(color: Colors.white70)));
          }

          final games = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index].data() as Map<String, dynamic>;
              final gameId = games[index].id;
              final winners = List<Map<String, dynamic>>.from(game['winners'] ?? []);
              final winnerIds = winners.map((w) => w['playerId'] as String).toList();
              final isWinner = winnerIds.contains(user.uid);

              // Recalculate prize for display purposes
              final totalCards = game['totalCardsSold'] as int? ?? 0;
              final cardCost = (game['cardCost'] as num?)?.toDouble() ?? 0.0;
              final totalPool = totalCards * cardCost;
              final winnerShare = GameConfig.calculateWinnerShare(totalPool);
              final prizePerWinner = GameConfig.calculatePrizePerWinner(totalPool, winners.length);
              
              final createdAt = (game['createdAt'] as Timestamp?)?.toDate();
              final dateString = createdAt != null ? '${createdAt.day}/${createdAt.month}/${createdAt.year}' : 'N/A';

              return Card(
                color: const Color(0xFF1C1C3A),
                margin: const EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game['gameName'] ?? gameId, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const Divider(color: Colors.white24, height: 20),
                      _buildInfoRow('Date:', dateString),
                      _buildInfoRow('Outcome:', isWinner ? 'Won' : 'Lost', color: isWinner ? Colors.greenAccent : Colors.redAccent),
                      _buildInfoRow('Your Prize:', isWinner ? '${prizePerWinner.toStringAsFixed(2)} ETB' : '0.00 ETB'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
