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
          debugPrint('📋 PLAYERS STREAM: Received ${snapshot.docs.length} documents from Firestore');
          var players = snapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();
          
          // Don't filter here - let the widget handle filtering
          players.sort((a, b) => (a.name.isEmpty ? '' : a.name.toLowerCase()).compareTo(b.name.isEmpty ? '' : b.name.toLowerCase()));
          final totalBalance = players.fold(0.0, (sum, player) => sum + player.balance);
          debugPrint('💰 PLAYERS STREAM: Total balance: $totalBalance');
          
          return PlayerData(players: players, totalBalance: totalBalance);
        });
  }

  // UPDATED: More robust history view with clear empty states
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
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Icon(Icons.account_balance_wallet, color: Colors.amber, size: 40),
                  const SizedBox(height: 12),
                  Text(player.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const Text('MATCH & PAYMENT HISTORY', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
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
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, color: Colors.white.withOpacity(0.05), size: 80),
                          const SizedBox(height: 16),
                          const Text('No transactions yet.', style: TextStyle(color: Colors.white24, fontSize: 16)),
                          const Text('Activity will appear after the first game.', style: TextStyle(color: Colors.white10, fontSize: 12)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final tx = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                      final date = (tx['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                      final isPlus = amount > 0;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C3A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05))
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPlus ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            child: Icon(isPlus ? Icons.add : Icons.remove, color: isPlus ? Colors.greenAccent : Colors.redAccent, size: 18),
                          ),
                          title: Text(tx['reason'] ?? 'Game Match', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(DateFormat('MMM dd, yyyy • HH:mm').format(date), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          trailing: Text(
                            '${isPlus ? "+" : ""}${amount.toStringAsFixed(2)}', 
                            style: TextStyle(color: isPlus ? Colors.greenAccent : Colors.white70, fontWeight: FontWeight.bold, fontSize: 15)
                          ),
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
        backgroundColor: const Color(0xFF1C1C3A),
        title: Text('ADD CASH: ${player.name}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amountController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Amount (ETB)', labelStyle: TextStyle(color: Colors.white38)), keyboardType: TextInputType.number),
          TextField(controller: reasonController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Reason', labelStyle: TextStyle(color: Colors.white38))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.white38))),
          ElevatedButton(onPressed: () async {
            final amt = double.tryParse(amountController.text) ?? 0;
            if (amt > 0) {
              await _firebaseService.addCashToPlayer(playerId: player.id, amount: amt, reason: reasonController.text.isEmpty ? 'Manual Deposit' : reasonController.text);
              Navigator.pop(context);
            }
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('ADD FUNDS'))
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
        backgroundColor: const Color(0xFF1C1C3A),
        title: Text('DEDUCT CASH: ${player.name}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amountController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Amount (ETB)', labelStyle: TextStyle(color: Colors.white38)), keyboardType: TextInputType.number),
          TextField(controller: reasonController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Reason', labelStyle: TextStyle(color: Colors.white38))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.white38))),
          ElevatedButton(onPressed: () async {
            final amt = double.tryParse(amountController.text) ?? 0;
            if (amt > 0) {
              await _firebaseService.deductCashFromPlayer(playerId: player.id, amount: amt, reason: reasonController.text.isEmpty ? 'Manual Withdrawal' : reasonController.text);
              Navigator.pop(context);
            }
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('DEDUCT FUNDS'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(title: const Text('PLAYER MANAGEMENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)), backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search player name or phone...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
                filled: true,
                fillColor: const Color(0xFF1C1C3A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<PlayerData>(
                stream: _getPlayersStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                  final allPlayers = snapshot.data!.players;
                  
                  // Apply search filter here
                  List<Player> filteredPlayers = allPlayers;
                  if (_searchQuery.isNotEmpty) {
                    final queryLower = _searchQuery.toLowerCase();
                    filteredPlayers = allPlayers.where((player) {
                      return (player.name.isNotEmpty && player.name.toLowerCase().contains(queryLower)) || 
                             (player.phoneNumber.isNotEmpty && player.phoneNumber.contains(queryLower));
                    }).toList();
                  }
                  
                  debugPrint('🔍 PLAYERS SCREEN: Total players: ${allPlayers.length}, Filtered: ${filteredPlayers.length}');
                  
                  if (filteredPlayers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline, 
                            color: Colors.white24, 
                            size: 64
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty ? 'No players found for "$_searchQuery"' : 'No players found.', 
                            style: const TextStyle(color: Colors.white24, fontSize: 16)
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty 
                              ? 'Try a different search term'
                              : 'Players will appear here when they register.', 
                            style: const TextStyle(color: Colors.white10, fontSize: 12)
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredPlayers.length,
                    itemBuilder: (context, index) {
                      final p = filteredPlayers[index];
                      return Card(
                        color: const Color(0xFF1C1C3A),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          onTap: () => _showPlayerHistory(p),
                          leading: CircleAvatar(
                            backgroundColor: Colors.purpleAccent.withOpacity(0.2), 
                            child: Text(p.name.isNotEmpty ? p.name.substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold))
                          ),
                          title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('${p.balance.toStringAsFixed(2)} ETB', style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w500)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 28), onPressed: () => _showAddCashDialog(p)),
                            const SizedBox(width: 4),
                            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange, size: 28), onPressed: () => _showDeductCashDialog(p)),
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
