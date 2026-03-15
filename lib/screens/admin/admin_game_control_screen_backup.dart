import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/config/game_config.dart';
import 'package:mygame/widgets/player_name_widget.dart';

class AdminGameControlScreenBackup extends StatelessWidget {
  final String gameId;
  final FirebaseService _firebaseService = FirebaseService();

  AdminGameControlScreenBackup({super.key, required this.gameId});

  Stream<DocumentSnapshot> _getGameStream() {
    return FirebaseFirestore.instance.collection('games').doc(gameId).snapshots();
  }

  Future<void> _startGame(BuildContext context) async {
    try {
      await _firebaseService.startGame(gameId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game started!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _callRandomNumber(BuildContext context) async {
    try {
      await _firebaseService.callRandomNumber(gameId);
      await _checkForAutoWinners(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }
  
  Future<void> _checkForAutoWinners(BuildContext context) async {
    try {
      final gameDoc = await FirebaseFirestore.instance.collection('games').doc(gameId).get();
      final gameData = gameDoc.data() as Map<String, dynamic>? ?? {};
      final players = List<String>.from(gameData['players'] ?? []);
      final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);
      final winningPattern = gameData['winningPattern'] as String? ?? 'any_line';
      
      List<Map<String, dynamic>> winners = [];
      for (final playerId in players) {
        final List<List<int>> playerCards = [];
        final cardCount = gameData['${playerId}_cardCount'] ?? 0;
        for (int i = 0; i < cardCount; i++) {
          final cardStr = gameData['${playerId}_card$i'] as String? ?? '';
          if (cardStr.isNotEmpty) {
            final numbers = cardStr.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
            if (numbers.length == 25) playerCards.add(numbers);
          }
        }
        
        for (final card in playerCards) {
          if (_checkWinningPattern(card, calledNumbers, winningPattern)) {
            winners.add({'playerId': playerId, 'timestamp': DateTime.now().toIso8601String()});
            break;
          }
        }
      }
      
      if (winners.isNotEmpty) {
        await FirebaseFirestore.instance.collection('games').doc(gameId).update({
          'status': 'completed',
          'winners': winners,
        });
        _showAutoWinnerAnnouncement(context, winners);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }
  
  void _showAutoWinnerAnnouncement(BuildContext context, List<Map<String, dynamic>> winners) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 BINGO WINNER! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: winners.map((winner) => ListTile(
            title: PlayerNameWidget(playerId: winner['playerId'] as String),
            trailing: const Icon(Icons.star, color: Colors.amber),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
  
  bool _checkWinningPattern(List<int> card, List<int> calledNumbers, String pattern) {
    final grid = List.generate(5, (i) => card.sublist(i * 5, (i + 1) * 5));
    final Set<int> active = {...calledNumbers, 0};
    final p = pattern.toLowerCase();

    if (p == 'horizontal' || p == 'any line') {
      for (int i = 0; i < 5; i++) { if (grid[i].every((n) => active.contains(n))) return true; }
    }
    if (p == 'vertical' || p == 'any line') {
      for (int i = 0; i < 5; i++) {
        if ([grid[0][i], grid[1][i], grid[2][i], grid[3][i], grid[4][i]].every((n) => active.contains(n))) return true;
      }
    }
    return false;
  }

  Future<void> _callSpecificNumber(BuildContext context, int number) async {
    try {
      await _firebaseService.callSpecificNumber(gameId, number);
      await _checkForAutoWinners(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _endGameAndDistributePrizes(BuildContext context) async {
    try {
      await _firebaseService.distributePrizes(gameId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prizes paid!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(title: const Text('Game Control Backup')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _getGameStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final gameData = snapshot.data!.data()! as Map<String, dynamic>;
          final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);
          final players = List<String>.from(gameData['players'] ?? []);
          final status = gameData['status'] as String? ?? 'pending';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(gameData['gameName'] ?? 'Match', style: const TextStyle(fontSize: 24, color: Colors.white)),
                    const SizedBox(height: 16),
                    _buildStatusButton(context, status),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Players (${players.length})', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ...players.map((id) => ListTile(title: PlayerNameWidget(playerId: id, textStyle: const TextStyle(color: Colors.white70)))),
                    const Divider(color: Colors.white24),
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Bingo Numbers', style: TextStyle(color: Colors.white70)),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
                      itemCount: 75,
                      itemBuilder: (context, index) {
                        final n = index + 1;
                        final isCalled = calledNumbers.contains(n);
                        return InkWell(
                          onTap: status == 'ongoing' && !isCalled ? () => _callSpecificNumber(context, n) : null,
                          child: Container(
                            decoration: BoxDecoration(color: isCalled ? Colors.purple : Colors.white10),
                            child: Center(child: Text('$n', style: TextStyle(color: isCalled ? Colors.white : Colors.white24))),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusButton(BuildContext context, String status) {
    if (status == 'pending') {
      return ElevatedButton(onPressed: () => _startGame(context), child: const Text('Start Match'));
    }
    return ElevatedButton(onPressed: () => _endGameAndDistributePrizes(context), child: const Text('Distribute Prizes'));
  }
}
