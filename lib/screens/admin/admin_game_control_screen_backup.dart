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
      
      // After calling number, check if any player has won
      _checkForAutoWinners(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to call number: ${e.toString()}"), backgroundColor: Colors.red),
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
      
      // Check each player for winning patterns
      for (final playerId in players) {
        // Get player's cards
        final cardsMap = gameData['${playerId}_cards'] as Map<String, dynamic>? ?? {};
        final List<List<int>> playerCards = [];
        
        final cardKeys = cardsMap.keys.where((key) => key.contains('_card')).toList();
        cardKeys.sort();
        
        for (final cardKey in cardKeys) {
          final cardString = cardsMap[cardKey] as String? ?? '';
          if (cardString.isNotEmpty) {
            final numbers = cardString.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
            if (numbers.length == 25) {
              playerCards.add(numbers);
            }
          }
        }
        
        if (playerCards.isEmpty) continue;
        
        // Check if any card has winning pattern
        for (final card in playerCards) {
          if (_checkWinningPattern(card, calledNumbers, winningPattern)) {
            winners.add({
              'playerId': playerId,
              'timestamp': DateTime.now().toIso8601String(),
              'pattern': winningPattern,
            });
            break;
          }
        }
      }
      
      // If winners found, update game and announce
      if (winners.isNotEmpty) {
        await FirebaseFirestore.instance.collection('games').doc(gameId).update({
          'status': 'completed',
          'winners': winners,
        });
        
        // Show winner announcement to all players
        _showAutoWinnerAnnouncement(context, winners);
      }
    } catch (e) {
      print('Error checking winners: $e');
    }
  }
  
  void _showAutoWinnerAnnouncement(BuildContext context, List<Map<String, dynamic>> winners) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 BINGO WINNER! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Winner Announcement:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...winners.map((winner) => Card(
              color: Colors.green.shade100,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Text(
                    (winner['playerId'] as String? ?? '').substring(0, 2).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: PlayerNameWidget(playerId: winner['playerId'] as String? ?? ''),
                subtitle: Text(
                  'ID: ${(winner['playerId'] as String? ?? '').substring(0, 8)}...',
                  style: const TextStyle(color: Colors.black87),
                ),
                trailing: const Icon(Icons.star, color: Colors.amber),
              ),
            )).toList(),
          ],
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
  
  // Check if a card has a winning pattern
  bool _checkWinningPattern(List<int> card, List<int> calledNumbers, String pattern) {
    // Convert card to 5x5 grid
    final grid = List.generate(5, (i) => card.sublist(i * 5, (i + 1) * 5));
    
    switch (pattern.toLowerCase()) {
      case 'any_line':
        // Check any horizontal line
        for (int row = 0; row < 5; row++) {
          if (_checkLine(grid[row], calledNumbers)) return true;
        }
        // Check any vertical line
        for (int col = 0; col < 5; col++) {
          final column = [grid[0][col], grid[1][col], grid[2][col], grid[3][col], grid[4][col]];
          if (_checkLine(column, calledNumbers)) return true;
        }
        // Check diagonals
        final diagonal1 = [grid[0][0], grid[1][1], grid[2][2], grid[3][3], grid[4][4]];
        final diagonal2 = [grid[0][4], grid[1][3], grid[2][2], grid[3][1], grid[4][0]];
        if (_checkLine(diagonal1, calledNumbers)) return true;
        if (_checkLine(diagonal2, calledNumbers)) return true;
        break;
        
      case 'full_house':
        // All numbers must be called
        for (int i = 0; i < 25; i++) {
          if (card[i] != 0 && !calledNumbers.contains(card[i])) return false;
        }
        return true;
        
      case 'four_corners':
        final corners = [card[0], card[4], card[20], card[24]];
        return corners.every((num) => num == 0 || calledNumbers.contains(num));
        
      default:
        return false;
    }
    
    return false;
  }
  
  // Check if all numbers in a line are called
  bool _checkLine(List<int> line, List<int> calledNumbers) {
    return line.every((num) => num == 0 || calledNumbers.contains(num));
  }

  Future<void> _callSpecificNumber(BuildContext context, int number) async {
    try {
      await _firebaseService.callSpecificNumber(gameId, number);
      
      // After calling number, check if any player has won
      _checkForAutoWinners(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to call number: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _verifyWinner(BuildContext context) async {
    final playerIdController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Winner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter player ID to verify if they have bingo:'),
            const SizedBox(height: 16),
            TextField(
              controller: playerIdController,
              decoration: const InputDecoration(
                labelText: 'Player ID',
                hintText: 'Enter the player\'s user ID',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final playerId = playerIdController.text.trim();
              if (playerId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a player ID'), backgroundColor: Colors.red),
                );
                return;
              }
              
              Navigator.pop(context);
              
              try {
                final bool hasWin = await _firebaseService.claimWin(
                  gameId: gameId,
                  playerId: playerId,
                );
                
                if (hasWin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎉 $playerId has a valid BINGO!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ This player does not have a winning pattern'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
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
                        child: Center(child: Text(number.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
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
          onPressed: () => _verifyWinner(context),
          icon: const Icon(Icons.verified, color: Colors.white),
          label: const Text('Verify Winner'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
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
          child: Text('Joined Players (${players.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(height: 8),
        if (players.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('No players have joined yet.', style: TextStyle(color: Colors.white70))),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: players.length,
              itemBuilder: (context, index) {
                final playerId = players[index];
                return Card(
                  color: const Color(0xFF1C1C3A),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple,
                      radius: 20,
                      child: Text(
                        playerId.substring(0, 2).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    title: PlayerNameWidget(playerId: playerId),
                    subtitle: Text(
                      'ID: ${playerId.substring(0, 8)}...',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'JOINED',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
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
