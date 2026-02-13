import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/models/transaction.dart' as my_transaction; // Alias added

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<DocumentSnapshot> _balanceStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection('players').doc(user.uid).snapshots();
  }

  Stream<QuerySnapshot> _transactionsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore
        .collection('players')
        .doc(user.uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 24),
          _buildProfitSummary(),
          const SizedBox(height: 24),
          const Text('Transaction History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTransactionList(),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _balanceStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const Text('No balance data.', style: TextStyle(color: Colors.white70));
        }
        final balance = (snapshot.data!.data() as Map<String, dynamic>?)?['balance'] ?? 0.0;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1C1C3A).withOpacity(0.8),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet, color: Colors.amber, size: 40),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 16)),
                Text('${balance.toStringAsFixed(2)} ETB', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildProfitSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: _transactionsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final transactions = snapshot.data!.docs
            .map((doc) => my_transaction.Transaction.fromFirestore(doc)) // Alias used here
            .toList();
        final adminTransactions = transactions.where((t) => t.reason != null && t.reason!.startsWith('Admin profit')).toList();

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        final startOfMonth = DateTime(now.year, now.month, 1);

        final dailyProfit = adminTransactions
            .where((t) => t.date.isAfter(today))
            .fold(0.0, (sum, t) => sum + t.amount);

        final weeklyProfit = adminTransactions
            .where((t) => t.date.isAfter(startOfWeek))
            .fold(0.0, (sum, t) => sum + t.amount);

        final monthlyProfit = adminTransactions
            .where((t) => t.date.isAfter(startOfMonth))
            .fold(0.0, (sum, t) => sum + t.amount);

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1C1C3A).withOpacity(0.8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profit Summary', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildProfitRow('Today', dailyProfit),
                _buildProfitRow('This Week', weeklyProfit),
                _buildProfitRow('This Month', monthlyProfit),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfitRow(String title, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Text('${amount.toStringAsFixed(2)} ETB', style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
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
          return const Center(child: Text('No transactions yet.', style: TextStyle(color: Colors.white70)));
        }

        final transactions = snapshot.data!.docs
            .map((doc) => my_transaction.Transaction.fromFirestore(doc)) // Alias used here
            .toList();

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            final historicalBalance = (snapshot.data!.docs[index].data() as Map<String, dynamic>?)?['balance_after_transaction'] ?? 0.0;

            return _buildTransactionItem(transaction, index: index, isLast: index == transactions.length - 1, historicalBalance: historicalBalance);
          },
        );
      },
    );
  }

  Widget _buildTransactionItem(my_transaction.Transaction transaction, {required int index, required bool isLast, required double historicalBalance}) {
    final isProfit = transaction.amount >= 0;
    final amountText = '${isProfit ? '+' : ''}${transaction.amount.toStringAsFixed(2)} ETB';

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(mainAxisAlignment: MainAxisAlignment.start, children: [
          if (index != 0) Expanded(child: Container(width: 2, color: Colors.white24)) else const Expanded(child: SizedBox()),
          const Icon(Icons.circle, color: Colors.white24, size: 12),
          if (!isLast) Expanded(child: Container(width: 2, color: Colors.white24)) else const Expanded(child: SizedBox()),
        ]),
        const SizedBox(width: 16),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                transaction.type == my_transaction.TransactionType.game ? 'Game ${transaction.gameId ?? ''} ${isProfit ? 'profit' : 'fee'}' : transaction.reason ?? 'Manual Transaction',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text('${transaction.amount.toStringAsFixed(2)} Birr', style: const TextStyle(color: Colors.white70)),
              Text('${transaction.date.day}/${transaction.date.month}/${transaction.date.year}, ${transaction.date.hour}:${transaction.date.minute}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(amountText, style: TextStyle(color: isProfit ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Balance: ${historicalBalance.toStringAsFixed(2)} ETB', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ])
          ]),
        )),
      ]),
    );
  }
}
