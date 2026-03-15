import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/models/player.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:intl/intl.dart';

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
        .snapshots()
        .map((snapshot) {
          var players = snapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();
          if (_searchQuery.isNotEmpty) {
            final queryLower = _searchQuery.toLowerCase();
            players = players.where((player) {
              return player.name.toLowerCase().contains(queryLower) || 
                     player.phoneNumber.contains(queryLower);
            }).toList();
          }
          players.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          final totalBalance = players.fold(0.0, (sum, player) => sum + player.balance);
          return PlayerData(players: players, totalBalance: totalBalance);
        });
  }

  void _showPlayerHistory(Player player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.history, color: Colors.amber, size: 40),
                  const SizedBox(height: 8),
                  Text('${player.name}\'s History', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('ID: ${player.id.substring(0, 10)}...', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('players')
                    .doc(player.id)
                    .collection('transactions')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No transaction history.', style: TextStyle(color: Colors.white24)));

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final tx = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                      final date = (tx['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                      final isPlus = amount > 0;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: Icon(isPlus ? Icons.arrow_upward : Icons.arrow_downward, color: isPlus ? Colors.greenAccent : Colors.redAccent),
                          title: Text(tx['reason'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(date), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          trailing: Text('${isPlus ? "+" : ""}${amount.toStringAsFixed(2)} ETB', style: TextStyle(color: isPlus ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
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

  void _showAddCashDialog(Player player) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Cash: ${player.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
          TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final amt = double.tryParse(amountController.text) ?? 0;
            if (amt > 0) {
              await _firebaseService.addCashToPlayer(playerId: player.id, amount: amt, reason: reasonController.text);
              Navigator.pop(context);
            }
          }, child: const Text('Add'))
        ],
      ),
    );
  }

  void _showDeductCashDialog(Player player) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deduct Cash: ${player.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
          TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final amt = double.tryParse(amountController.text) ?? 0;
            if (amt > 0) {
              await _firebaseService.deductCashFromPlayer(playerId: player.id, amount: amt, reason: reasonController.text);
              Navigator.pop(context);
            }
          }, child: const Text('Deduct'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(title: const Text('PLAYER MANAGEMENT'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name or phone',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF1C1C3A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<PlayerData>(
                stream: _getPlayersStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final players = snapshot.data!.players;
                  return ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final p = players[index];
                      return Card(
                        color: const Color(0xFF1C1C3A),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => _showPlayerHistory(p), // SHOW HISTORY ON TAP
                          leading: CircleAvatar(backgroundColor: Colors.purple, child: Text(p.name.substring(0, 1).toUpperCase())),
                          title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('${p.balance.toStringAsFixed(2)} ETB', style: const TextStyle(color: Colors.greenAccent)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _showAddCashDialog(p)),
                            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange), onPressed: () => _showDeductCashDialog(p)),
                          ]),
                        ),
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
