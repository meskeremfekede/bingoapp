import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameStatusChecker extends StatefulWidget {
  const GameStatusChecker({super.key});

  @override
  State<GameStatusChecker> createState() => _GameStatusCheckerState();
}

class _GameStatusCheckerState extends State<GameStatusChecker> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _games = [];
  String _error = '';

  Future<void> _checkGameStatus() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Please login first';
          _isLoading = false;
        });
        return;
      }

      print('🔍 Checking game status for user: ${user.uid}');

      // Get all games
      final gamesSnapshot = await FirebaseFirestore.instance
          .collection('games')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> games = [];
      
      for (var doc in gamesSnapshot.docs) {
        final gameData = doc.data();
        final status = gameData['status'] as String? ?? 'unknown';
        final createdAt = gameData['createdAt'] as Timestamp?;
        final maxCards = gameData['maxCards'] as int? ?? 0;
        final cardCost = gameData['cardCost'] as num? ?? 0;
        
        // Check if player already has cards
        bool hasCards = false;
        try {
          final playerDataDoc = await FirebaseFirestore.instance
              .collection('games')
              .doc(doc.id)
              .collection('playerData')
              .doc(user.uid)
              .get();
          
          hasCards = playerDataDoc.exists && 
                   playerDataDoc.data() != null &&
                   (playerDataDoc.data()!['cards'] as List?)?.isNotEmpty == true;
        } catch (e) {
          print('Error checking player cards: $e');
        }

        games.add({
          'id': doc.id,
          'name': gameData['name'] as String? ?? 'No Name',
          'status': status,
          'statusColor': _getStatusColor(status),
          'createdAt': createdAt?.toDate(),
          'maxCards': maxCards,
          'cardCost': cardCost.toDouble(),
          'hasCards': hasCards,
          'canJoin': status == 'pending' && !hasCards,
        });
      }

      setState(() {
        _games = games;
        _isLoading = false;
      });

    } catch (e) {
      print('❌ Error checking game status: $e');
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.green;
      case 'ongoing':
        return Colors.orange;
      case 'completed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('Game Status Checker'),
        backgroundColor: const Color(0xFF0A0A1A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _checkGameStatus,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_isLoading ? 'Checking...' : 'Check Game Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            if (_games.isNotEmpty) ...[
              const Text(
                'Games Status:',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _games.length,
                  itemBuilder: (context, index) {
                    final game = _games[index];
                    return Card(
                      color: const Color(0xFF1C1C3A),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    game['name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: game['statusColor'],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    game['status'].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Game ID: ${game['id']}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            if (game['createdAt'] != null)
                              Text(
                                'Created: ${game['createdAt'].toString().substring(0, 19)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Cards: ${game['maxCards']} | Cost: ${game['cardCost'].toStringAsFixed(2)} ETB',
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  game['hasCards'] ? Icons.check_circle : Icons.circle,
                                  color: game['hasCards'] ? Colors.green : Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  game['hasCards'] ? 'You have cards' : 'No cards purchased',
                                  style: TextStyle(
                                    color: game['hasCards'] ? Colors.green : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  game['canJoin'] ? Icons.check_circle : Icons.cancel,
                                  color: game['canJoin'] ? Colors.green : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  game['canJoin'] ? 'Can join' : 'Cannot join',
                                  style: TextStyle(
                                    color: game['canJoin'] ? Colors.green : Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
