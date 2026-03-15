import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

enum TransactionFilter { ALL, WINNINGS, FEES }

class PlayerWalletScreen extends StatefulWidget {
  const PlayerWalletScreen({super.key});

  @override
  State<PlayerWalletScreen> createState() => _PlayerWalletScreenState();
}

class _PlayerWalletScreenState extends State<PlayerWalletScreen> {
  TransactionFilter _selectedFilter = TransactionFilter.ALL;

  Stream<DocumentSnapshot> _balanceStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    
    return FirebaseFirestore.instance
        .collection('players')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true);
  }

  Stream<QuerySnapshot> _transactionsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    CollectionReference txRef = FirebaseFirestore.instance
        .collection('players').doc(user.uid).collection('transactions');

    Query query;
    if (_selectedFilter == TransactionFilter.WINNINGS) {
      query = txRef.where('type', isEqualTo: 'game_win').orderBy('date', descending: true);
    } else if (_selectedFilter == TransactionFilter.FEES) {
      query = txRef.where('type', isEqualTo: 'game_fee').orderBy('date', descending: true);
    } else {
      query = txRef.orderBy('date', descending: true);
    }
    
    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildBalanceCard(),
          ),
          _buildFilterChips(),
          const SizedBox(height: 24),
          const Text('Transaction History', 
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: _buildTransactionList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _balanceStream(),
      builder: (context, snapshot) {
        // PERMANENCE: Show spinner only on absolute first load with no data
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final balance = (snapshot.data?.data() as Map<String, dynamic>?)?['balance'] ?? 0.0;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1C1C3A).withOpacity(0.8),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.amber, size: 40),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      Text('${balance.toStringAsFixed(2)} ETB', 
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    ]),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {}); 
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Refreshing Wallet...'),
                          backgroundColor: Colors.blue,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text('Refresh Wallet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _selectedFilter == TransactionFilter.ALL,
            onSelected: (selected) {
              if (selected) setState(() => _selectedFilter = TransactionFilter.ALL);
            },
          ),
          FilterChip(
            label: const Text('Winnings'),
            selected: _selectedFilter == TransactionFilter.WINNINGS,
            onSelected: (selected) {
              if (selected) setState(() => _selectedFilter = TransactionFilter.WINNINGS);
            },
          ),
          FilterChip(
            label: const Text('Fees'),
            selected: _selectedFilter == TransactionFilter.FEES,
            onSelected: (selected) {
              if (selected) setState(() => _selectedFilter = TransactionFilter.FEES);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey(_selectedFilter),
      stream: _transactionsStream(),
      builder: (context, snapshot) {
        // PERMANENCE: If we have data from a previous state, keep it visible while loading
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
        }
        
        final docs = snapshot.data?.docs ?? [];
        debugPrint('🔍 PLAYER WALLET: Processing ${docs.length} transactions');
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          debugPrint('📋 PLAYER WALLET: Transaction type: ${data['type']}, amount: ${data['amount']}, reason: ${data['reason']}');
        }
        
        if (docs.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, color: Colors.white10, size: 64),
                const SizedBox(height: 16),
                const Text('No transactions found.', style: TextStyle(color: Colors.white24)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final reason = data['reason'] as String? ?? 'Match Transaction';
            final date = (data['date'] as Timestamp?)?.toDate();
            final formattedDate = date != null ? DateFormat.yMd().add_jm().format(date) : 'Recently';

            return Card(
              color: const Color(0xFF1C1C3A),
              margin: const EdgeInsets.only(bottom: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: amount > 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  child: Icon(
                    amount > 0 ? Icons.add : Icons.remove, 
                    color: amount > 0 ? Colors.greenAccent : Colors.redAccent, 
                    size: 18
                  ),
                ),
                title: Text(reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(formattedDate, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                trailing: Text(
                  '${amount.toStringAsFixed(2)} ETB', 
                  style: TextStyle(
                    color: amount > 0 ? Colors.greenAccent : Colors.white70, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 15
                  )
                ),
              ),
            );
          },
        );
      },
    );
  }
}
