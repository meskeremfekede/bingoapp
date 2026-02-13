import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/config/game_config.dart';
import 'package:mygame/widgets/player_name_widget.dart';

class AdminGameControlScreen extends StatelessWidget {
  final String gameId;
  final FirebaseService _firebaseService = FirebaseService();

  AdminGameControlScreen({super.key, required this.gameId});

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
        SnackBar(content: Text("Failed to start game: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _callRandomNumber(BuildContext context) async {
    try {
      await _firebaseService.callRandomNumber(gameId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to call number: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _callSpecificNumber(BuildContext context, int number) async {
    try {
      await _firebaseService.callSpecificNumber(gameId, number);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to call number: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _endGameAndDistributePrizes(BuildContext context) async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Action'),
        content: const Text('Are you sure you want to end this game and distribute prizes? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm & Distribute'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );

    if (shouldEnd == true) {
      try {
        await _firebaseService.distributePrizes(gameId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prizes distributed successfully.'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to distribute prizes: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A), // Dark Theme
      appBar: AppBar(
        title: const Text('Game Control', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1C1C3A),
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _getGameStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final gameData = snapshot.data!.data()! as Map<String, dynamic>;
          final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);
          final playersJoined = List<String>.from(gameData['players'] ?? []);
          final status = gameData['status'] as String? ?? 'pending';

          final maxPlayers = gameData['maxPlayers'] as int? ?? 0;
          final cardCost = (gameData['cardCost'] as num?)?.toDouble() ?? 0.0;
          final totalCardsSold = gameData['totalCardsSold'] as int? ?? 0;
          final adminProfitPercentage = GameConfig.adminShareNumerator / GameConfig.totalShareDenominator;
          final actualProfit = (totalCardsSold * cardCost) * adminProfitPercentage;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gameData['gameName'] ?? 'Game', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    if (status == 'ongoing')
                       Text('Actual Profit So Far: ${actualProfit.toStringAsFixed(2)} ETB', style: TextStyle(fontSize: 16, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildStatusButton(context, status, gameData),
                  ],
                ),
              ),
              const Divider(thickness: 1, color: Colors.white24),
              _buildPlayerList(playersJoined),
              const Divider(thickness: 1, color: Colors.white24),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 4, mainAxisSpacing: 4),
                  itemCount: 75,
                  itemBuilder: (context, index) {
                    final number = index + 1;
                    final isCalled = calledNumbers.contains(number);
                    return InkWell(
                      onTap: status == 'ongoing' && !isCalled ? () => _callSpecificNumber(context, number) : null,
                      child: Container(
                        decoration: BoxDecoration(color: isCalled ? Colors.purple.shade300 : const Color(0xFF1C1C3A), borderRadius: BorderRadius.circular(4)),
                        child: Center(child: Text(number.toString(), style: TextStyle(color: isCalled ? Colors.black : Colors.white, fontWeight: isCalled ? FontWeight.bold : FontWeight.normal))),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusButton(BuildContext context, String status, Map<String, dynamic> gameData) {
    if (status == 'completed') {
      final bool prizesDistributed = gameData['prizeDistributed'] == true;
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: prizesDistributed ? null : () => _endGameAndDistributePrizes(context),
          icon: const Icon(Icons.card_giftcard, color: Colors.black87),
          label: Text(prizesDistributed ? 'Prizes Already Paid' : 'Distribute Prizes'),
          style: ElevatedButton.styleFrom(backgroundColor: prizesDistributed ? Colors.grey : Colors.green, foregroundColor: prizesDistributed ? Colors.white : Colors.black87, padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      );
    }
    if (status == 'pending') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _startGame(context),
          icon: const Icon(Icons.play_arrow, color: Colors.black87),
          label: const Text('Start Game'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade700, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      );
    }
    // status == 'ongoing'
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _callRandomNumber(context),
            icon: const Icon(Icons.psychology, color: Colors.black87),
            label: const Text('Call Random'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => _endGameAndDistributePrizes(context),
          icon: const Icon(Icons.stop_circle, color: Colors.white),
          label: const Text('End Game'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
        ),
      ],
    );
  }

  Widget _buildPlayerList(List<String> players) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
          child: Text('Joined Players', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        SizedBox(
          height: 50,
          child: players.isEmpty
              ? const Center(child: Text('No players have joined yet.', style: TextStyle(color: Colors.white70)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    return Card(
                      color: const Color(0xFF1C1C3A),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 20, color: Colors.white70),
                            const SizedBox(width: 8),
                            PlayerNameWidget(playerId: players[index]),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
