import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/config/game_config.dart';
import 'package:mygame/widgets/player_name_widget.dart';

class AdminGameControlScreen extends StatefulWidget {
  final String gameId;
  const AdminGameControlScreen({super.key, required this.gameId});

  @override
  State<AdminGameControlScreen> createState() => _AdminGameControlScreenState();
}

class _AdminGameControlScreenState extends State<AdminGameControlScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isWinnerDialogShown = false;

  Stream<DocumentSnapshot> _getGameStream() {
    return FirebaseFirestore.instance.collection('games').doc(widget.gameId).snapshots();
  }

  Future<void> _startGame() async {
    try {
      await _firebaseService.startGame(widget.gameId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Game started!'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _callRandomNumber() async {
    try {
      await _firebaseService.callRandomNumber(widget.gameId);
      await _checkForAutoWinners();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }
  
  Future<void> _checkForAutoWinners() async {
    try {
      final gameDoc = await FirebaseFirestore.instance.collection('games').doc(widget.gameId).get();
      final gameData = gameDoc.data() as Map<String, dynamic>? ?? {};
      final players = List<String>.from(gameData['players'] ?? []);
      final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);
      final winningPattern = gameData['winningPattern'] as String? ?? 'any_line';
      
      List<Map<String, dynamic>> winners = [];
      for (final playerId in players) {
        final List<List<int>> playerCards = [];
        final List<int> playerFlags = List<int>.from(gameData['${playerId}_selectedFlags'] ?? []);
        final count = gameData['${playerId}_cardCount'] ?? 0;
        
        for (int i = 0; i < count; i++) {
          final String? cardStr = gameData['${playerId}_card$i'];
          if (cardStr != null && cardStr.isNotEmpty) {
            final card = cardStr.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
            if (card.length == 25 && _checkWinningPattern(card, calledNumbers, winningPattern)) {
              final nickname = playerFlags.length > i ? playerFlags[i].toString() : '??';
              winners.add({'playerId': playerId, 'nickname': nickname});
              break; 
            }
          }
        }
      }
      
      if (winners.isNotEmpty) {
        await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
          'status': 'completed',
          'winner': winners.first['playerId'],
          'winnerNickname': winners.first['nickname'],
          'winners': winners,
        });
      }
    } catch (e) {
      debugPrint('Auto-winner check error: $e');
    }
  }
  
  void _showWinnerVibe(BuildContext context, String nickname, String id) {
    if (_isWinnerDialogShown) return;
    setState(() => _isWinnerDialogShown = true);

    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissal by tapping outside
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amber, width: 2)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('🎉 BINGO! 🎉', style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 60),
            const SizedBox(height: 16),
            const Text('Winner Found:', style: TextStyle(color: Colors.white70, fontSize: 14)),
            PlayerNameWidget(playerId: id, textStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), 
            const SizedBox(height: 16),
            const Text('Identity:', style: TextStyle(color: Colors.white38, fontSize: 12)),
            Text('FLAG #$nickname', style: const TextStyle(color: Colors.greenAccent, fontSize: 28, fontWeight: FontWeight.w900)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('DISMISS', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  bool _checkWinningPattern(List<int> card, List<int> calledNumbers, String pattern) {
    final grid = List.generate(5, (i) => card.sublist(i * 5, (i + 1) * 5));
    final Set<int> active = {...calledNumbers, 0};
    final p = pattern.toLowerCase();

    if (p == 'horizontal' || p == 'any line' || p == 'any_line') {
      for (int i = 0; i < 5; i++) { if (grid[i].every((n) => active.contains(n))) return true; }
    }
    if (p == 'vertical' || p == 'any line' || p == 'any_line') {
      for (int i = 0; i < 5; i++) {
        if ([grid[0][i], grid[1][i], grid[2][i], grid[3][i], grid[4][i]].every((n) => active.contains(n))) return true;
      }
    }
    if (p == 'diagonal' || p == 'any line' || p == 'any_line') {
      if ([grid[0][0], grid[1][1], grid[2][2], grid[3][3], grid[4][4]].every((n) => active.contains(n))) return true;
      if ([grid[0][4], grid[1][3], grid[2][2], grid[3][1], grid[4][0]].every((n) => active.contains(n))) return true;
    }
    if (p == 'four corners' || p == 'four_corners') {
      if ([grid[0][0], grid[0][4], grid[4][0], grid[4][4]].every((n) => active.contains(n))) return true;
    }
    if (p == 'full house' || p == 'full_house') {
      return card.every((n) => active.contains(n));
    }
    return false;
  }

  Future<void> _callSpecificNumber(int number) async {
    try {
      await _firebaseService.callSpecificNumber(widget.gameId, number);
      await _checkForAutoWinners();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  Future<void> _manualEndGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Match?'),
        content: const Text('Manually end this match? No prizes will be distributed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('End Game')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({'status': 'completed'});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _endGameAndDistributePrizes() async {
    try {
      await _firebaseService.distributePrizes(widget.gameId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prizes distributed!'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  double _parseSafeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(title: const Text('Game Control'), backgroundColor: const Color(0xFF1C1C3A)),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _getGameStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final gameData = snapshot.data!.data()! as Map<String, dynamic>;
          final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);
          final playersJoined = List<String>.from(gameData['players'] ?? []);
          final status = gameData['status'] as String? ?? 'pending';
          final winners = List<dynamic>.from(gameData['winners'] ?? []);

          final cardCost = _parseSafeDouble(gameData['cardCost']);
          final totalCardsSold = gameData['totalCardsSold'] as int? ?? 0;
          final actualProfit = (totalCardsSold * cardCost) * (30/130);

          if (status == 'completed' && winners.isNotEmpty) {
            final winner = winners.first as Map<String, dynamic>;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showWinnerVibe(context, winner['nickname'] ?? '??', winner['playerId'] ?? '');
            });
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(gameData['gameName'] ?? 'Bingo Match', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              if (status == 'ongoing')
                 Text('Admin Profit: ${actualProfit.toStringAsFixed(2)} ETB', style: const TextStyle(fontSize: 16, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildStatusButton(status, gameData),
              const Divider(height: 32, color: Colors.white24),
              _buildPlayerList(playersJoined),
              const Divider(height: 32, color: Colors.white24),
              const Text('Bingo Caller (1-75)', style: TextStyle(fontSize: 18, color: Colors.white70)),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 4, mainAxisSpacing: 4),
                itemCount: 75,
                itemBuilder: (context, index) {
                  final number = index + 1;
                  final isCalled = calledNumbers.contains(number);
                  return InkWell(
                    onTap: status == 'ongoing' && !isCalled ? () => _callSpecificNumber(number) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCalled ? Colors.purpleAccent : const Color(0xFF1C1C3A),
                        borderRadius: BorderRadius.circular(4)
                      ),
                      child: Center(
                        child: Text(number.toString(), style: TextStyle(color: isCalled ? Colors.white : Colors.white38, fontWeight: isCalled ? FontWeight.bold : FontWeight.normal))
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusButton(String status, Map<String, dynamic> gameData) {
    if (status == 'completed') {
      final bool prizesPaid = gameData['prizeDistributed'] == true;
      return ElevatedButton.icon(
        onPressed: prizesPaid ? null : () => _endGameAndDistributePrizes(),
        icon: const Icon(Icons.payments),
        label: Text(prizesPaid ? 'Prizes Distributed' : 'Pay Winners & Admin'),
        style: ElevatedButton.styleFrom(backgroundColor: prizesPaid ? Colors.grey : Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)),
      );
    }
    if (status == 'pending') {
      return ElevatedButton.icon(
        onPressed: () => _startGame(),
        icon: const Icon(Icons.play_circle_fill),
        label: const Text('Start Match'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(vertical: 16)),
      );
    }
    return Row(
      children: [
        Expanded(child: ElevatedButton(onPressed: () => _callRandomNumber(), child: const Text('Call Random'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange))),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(onPressed: () => _manualEndGame(), child: const Text('End Match'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red))),
      ],
    );
  }

  Widget _buildPlayerList(List<String> players) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Joined Players (${players.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        if (players.isEmpty)
          const Text('No players yet.', style: TextStyle(color: Colors.white38))
        else
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: players.length,
              itemBuilder: (context, index) {
                final id = players[index];
                return Card(
                  color: const Color(0xFF1C1C3A),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(child: PlayerNameWidget(playerId: id, textStyle: const TextStyle(color: Colors.white, fontSize: 12))),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
