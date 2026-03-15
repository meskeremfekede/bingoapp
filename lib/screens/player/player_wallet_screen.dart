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

    Query query = FirebaseFirestore.instance
        .collection('players').doc(user.uid).collection('transactions')
        .orderBy('date', descending: true);

    switch (_selectedFilter) {
      case TransactionFilter.WINNINGS:
        query = query.where('type', isEqualTo: 'game_win');
        break;
      case TransactionFilter.FEES:
        query = query.where('type', isEqualTo: 'game_fee'); 
        break;
      case TransactionFilter.ALL:
      default:
        break;
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
          Expanded(child: _buildTransactionList()),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _balanceStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final balance = (snapshot.data!.data() as Map<String, dynamic>?)?['balance'] ?? 0.0;

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
                      setState(() {}); // Trigger rebuild/refresh
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Refreshing balance...'),
                          backgroundColor: Colors.blue,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text('Refresh Balance'),
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
          ChoiceChip(
            label: const Text('All'),
            selected: _selectedFilter == TransactionFilter.ALL,
            onSelected: (selected) {
              if (selected) setState(() => _selectedFilter = TransactionFilter.ALL);
            },
          ),
          ChoiceChip(
            label: const Text('Winnings'),
            selected: _selectedFilter == TransactionFilter.WINNINGS,
            onSelected: (selected) {
              if (selected) setState(() => _selectedFilter = TransactionFilter.WINNINGS);
            },
          ),
          ChoiceChip(
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
      stream: _transactionsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No transactions for this filter.', 
            style: TextStyle(color: Colors.white70)));
        }

        final transactions = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final doc = transactions[index];
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] as num).toDouble();
            final reason = data['reason'] as String? ?? 'N/A';
            final date = (data['date'] as Timestamp?)?.toDate();
            final formattedDate = date != null ? DateFormat.yMd().add_jm().format(date) : 'N/A';

            return Card(
              color: const Color(0xFF1C1C3A),
              margin: const EdgeInsets.only(bottom: 8.0),
              child: ListTile(
                leading: Icon(amount > 0 ? Icons.arrow_upward : Icons.arrow_downward, 
                  color: amount > 0 ? Colors.greenAccent : Colors.redAccent),
                title: Text(reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(formattedDate, style: const TextStyle(color: Colors.white70)),
                trailing: Text('${amount.toStringAsFixed(2)} ETB', 
                  style: TextStyle(color: amount > 0 ? Colors.greenAccent : Colors.redAccent, 
                  fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            );
          },
        );
      },
    );
  }
}
