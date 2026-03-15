import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/config/game_config.dart';
import 'package:mygame/widgets/player_name_widget.dart';

class CompletedGamesScreen extends StatelessWidget {
  const CompletedGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not logged in.'));

    // BROAD FILTER: Get all games the user played in
    final Stream<QuerySnapshot> gamesStream = FirebaseFirestore.instance
        .collection('games')
        .where('players', arrayContains: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('MATCH HISTORY'), 
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: gamesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final allDocs = snapshot.data?.docs ?? [];
          
          // ROBUST CLIENT-SIDE FILTERING
          final games = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status']?.toString().toLowerCase() ?? '';
            final hiddenBy = List<String>.from(data['hiddenBy'] ?? []);
            
            // Only show completed games that aren't hidden by this player
            return status == 'completed' && !hiddenBy.contains(user.uid);
          }).toList();

          if (games.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: Colors.white10, size: 64),
                  SizedBox(height: 16),
                  Text('No match history found.', style: TextStyle(color: Colors.white24, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final docId = games[index].id;
              final game = games[index].data() as Map<String, dynamic>;
              
              // Determine Winner Details
              final winners = List<dynamic>.from(game['winners'] ?? []);
              final winner = winners.isNotEmpty ? winners.first as Map<String, dynamic> : null;
              final isYou = winner?['playerId'] == user.uid;

              // Calculate Prize
              final totalCards = (game['totalCardsSold'] as num? ?? 0).toDouble();
              final cardCost = (game['cardCost'] as num? ?? 0).toDouble();
              final totalPool = totalCards * cardCost;
              final prize = isYou ? GameConfig.calculatePrizePerWinner(totalPool, winners.length) : 0.0;
              
              final createdAt = (game['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

              return Card(
                color: const Color(0xFF1C1C3A),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15), 
                  side: BorderSide(color: isYou ? Colors.green.withOpacity(0.3) : Colors.white10)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(game['gameName'] ?? 'Bingo Match', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              Text('${createdAt.day}/${createdAt.month}/${createdAt.year} • Match ID: ${docId.substring(0,5)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep, color: Colors.white24, size: 20), 
                            onPressed: () => _hide(docId, user.uid)
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Colors.white10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MATCH WINNER', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12, 
                                    backgroundColor: Colors.purple, 
                                    child: Text(winner?['nickname'] ?? '?', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))
                                  ),
                                  const SizedBox(width: 10),
                                  if (winner != null) 
                                    PlayerNameWidget(playerId: winner['playerId'], textStyle: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(isYou ? 'EARNINGS' : 'RESULT', style: TextStyle(color: isYou ? Colors.greenAccent : Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(
                                isYou ? '+${prize.toStringAsFixed(2)} ETB' : 'LOST', 
                                style: TextStyle(
                                  color: isYou ? Colors.greenAccent : Colors.white24, 
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold
                                )
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Future<void> _hide(String id, String uid) async {
    await FirebaseFirestore.instance.collection('games').doc(id).update({
      'hiddenBy': FieldValue.arrayUnion([uid])
    });
  }
}
