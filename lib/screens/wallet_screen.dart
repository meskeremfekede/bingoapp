import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
      appBar: AppBar(title: const Text('ADMIN WALLET'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 24),
          const Text('PROFIT ANALYTICS', style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          _buildDetailedProfitSummary(),
          const SizedBox(height: 24),
          const Text('RECENT ACTIVITY', style: TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTransactionList(),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _balanceStream(),
      builder: (context, snapshot) {
        final balance = (snapshot.data?.data() as Map<String, dynamic>?)?['balance'] ?? 0.0;
        return Card(
          color: const Color(0xFF1C1C3A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Account Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text('${balance.toStringAsFixed(2)} ETB', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailedProfitSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: _transactionsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        double dailyTotal = 0;
        Map<String, double> weekDays = {};
        Map<int, double> monthWeeks = {1: 0, 2: 0, 3: 0, 4: 0};

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['type'] != 'admin_profit') continue;
          
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final date = (data['date'] as Timestamp?)?.toDate();
          if (date == null) continue;

          // 1. Calculate Today
          if (date.isAfter(today)) dailyTotal += amount;

          // 2. Calculate Last 7 Days Breakdown
          if (date.isAfter(now.subtract(const Duration(days: 7)))) {
            String dayName = DateFormat('EEEE').format(date);
            weekDays[dayName] = (weekDays[dayName] ?? 0) + amount;
          }

          // 3. Calculate Monthly Weeks Breakdown
          if (date.isAfter(DateTime(now.year, now.month, 1))) {
            int weekNum = ((date.day - 1) ~/ 7) + 1;
            if (weekNum > 4) weekNum = 4;
            monthWeeks[weekNum] = (monthWeeks[weekNum] ?? 0) + amount;
          }
        }

        double weeklyTotal = weekDays.values.fold(0, (a, b) => a + b);
        double monthlyTotal = monthWeeks.values.fold(0, (a, b) => a + b);

        return Column(
          children: [
            // Today Card
            _buildStatRow('Today\'s Earnings', dailyTotal, isExpandable: false),
            
            // Weekly Expansion
            _buildExpandableStat('Weekly Profit', weeklyTotal, weekDays.entries.map((e) => _buildSubRow(e.key, e.value)).toList()),
            
            // Monthly Expansion
            _buildExpandableStat('Monthly Profit', monthlyTotal, monthWeeks.entries.map((e) => _buildSubRow('Week ${e.key}', e.value)).toList()),
          ],
        );
      },
    );
  }

  Widget _buildStatRow(String title, double amount, {required bool isExpandable}) {
    return Card(
      color: const Color(0xFF1C1C3A),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        trailing: Text('+${amount.toStringAsFixed(2)} ETB', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildExpandableStat(String title, double total, List<Widget> children) {
    return Card(
      color: const Color(0xFF1C1C3A),
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        trailing: Text('+${total.toStringAsFixed(2)} ETB', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        iconColor: Colors.white38,
        collapsedIconColor: Colors.white38,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(children: children),
          )
        ],
      ),
    );
  }

  Widget _buildSubRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          Text('${amount.toStringAsFixed(2)} ETB', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _transactionsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No activity found.', style: TextStyle(color: Colors.white10)));
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
            return Card(
              color: const Color(0xFF1C1C3A),
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                title: Text(data['reason'] ?? 'Transaction', style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(DateFormat('dd MMM, HH:mm').format(date), style: const TextStyle(color: Colors.white24, fontSize: 11)),
                trailing: Text('${amount > 0 ? "+" : ""}${amount.toStringAsFixed(2)}', style: TextStyle(color: amount > 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }
}
