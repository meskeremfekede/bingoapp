import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/models/player.dart';
import 'package:mygame/services/firebase_service.dart';

class PlayerData {
  final List<Player> players;
  final double totalBalance;

  PlayerData({required this.players, required this.totalBalance});
}

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _searchQuery = '';

  Stream<PlayerData> _getPlayersStream() {
    return FirebaseFirestore.instance
        .collection('players')
        .snapshots(
          // Add real-time sync options
          includeMetadataChanges: true,
        )
        .map((snapshot) {
          var players = snapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();
          if (_searchQuery.isNotEmpty) {
            players = players.where((player) {
              final nameLower = player.name.toLowerCase();
              final queryLower = _searchQuery.toLowerCase();
              return nameLower.contains(queryLower) || player.phoneNumber.contains(queryLower);
            }).toList();
          }
          players.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          final totalBalance = players.fold(0.0, (sum, player) => sum + player.balance);
          return PlayerData(players: players, totalBalance: totalBalance);
        });
  }

  // Simplified dialog for adding cash
  void _showAddCashDialog(Player player) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Cash to ${player.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
            TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason (e.g., Deposit)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                try {
                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(width: 16),
                          Text('Adding cash...'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 10),
                    ),
                  );
                  
                  await _firebaseService.addCashToPlayer(
                    playerId: player.id, 
                    amount: amount, 
                    reason: reasonController.text
                  );
                  
                  // Clear loading and show success
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Successfully added ${amount.toStringAsFixed(2)} ETB to ${player.name}'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  
                  // Force refresh the player list to show updated balance
                  setState(() {});
                  
                  Navigator.of(context).pop();
                } catch (e) {
                  // Clear loading and show error
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add cash: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            child: const Text('Add'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  // Simplified dialog for deducting cash
  void _showDeductCashDialog(Player player) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deduct Cash from ${player.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
            TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason (e.g., Withdrawal)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                await _firebaseService.deductCashFromPlayer(playerId: player.id, amount: amount, reason: reasonController.text);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Deduct'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _showDeletePlayerDialog(Player player) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete ${player.name}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _firebaseService.deletePlayer(player.id);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Players Management'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // Force refresh all player data
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing player data...'),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Refresh Player List',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(labelText: 'Search by name or phone', prefixIcon: const Icon(Icons.search)),
            ),
            const SizedBox(height: 16),
            StreamBuilder<PlayerData>(
              stream: _getPlayersStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Total Players: ${snapshot.data!.players.length}'),
                        const SizedBox(width: 16),
                        Text('Total Balance: ${snapshot.data!.totalBalance.toStringAsFixed(2)} ETB', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Player balances update in real-time. If you don\'t see updates, try the refresh button.',
                              style: TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<PlayerData>(
                stream: _getPlayersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.players.isEmpty) return const Center(child: Text('No players found.'));
                  
                  final players = snapshot.data!.players;
                  return ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      return PlayerCard(
                        player: player, 
                        onAdd: () => _showAddCashDialog(player),
                        onDeduct: () => _showDeductCashDialog(player),
                        onDelete: () => _showDeletePlayerDialog(player),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerCard extends StatelessWidget {
  final Player player;
  final VoidCallback onAdd;
  final VoidCallback onDeduct;
  final VoidCallback onDelete;

  const PlayerCard({super.key, required this.player, required this.onAdd, required this.onDeduct, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          leading: CircleAvatar(child: Text(player.name.substring(0, 1))),
          title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(player.phoneNumber),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${player.balance.toStringAsFixed(2)} ETB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: onAdd, tooltip: 'Add Cash'),
              IconButton(icon: const Icon(Icons.remove_circle, color: Colors.orange), onPressed: onDeduct, tooltip: 'Deduct Cash'),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: onDelete, tooltip: 'Delete Player'),
            ],
          ),
        ),
      ),
    );
  }
}
