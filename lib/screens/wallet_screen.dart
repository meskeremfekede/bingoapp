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

  // Robust check for "Today"
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('ADMIN WALLET', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          return Future.delayed(const Duration(seconds: 1));
        },
        child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 24),
          const Text('ANALYTICS & PROFIT', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _buildDetailedProfitSummary(),
          const SizedBox(height: 24),
          const Text('RECENT TRANSACTIONS', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          _buildTransactionList(),
        ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _balanceStream(),
      builder: (context, snapshot) {
        // PERMANENCE: Keep showing old data while loading new
        final balance = (snapshot.data?.data() as Map<String, dynamic>?)?['balance'] ?? 0.0;
        debugPrint('💰 WALLET: Reading balance: $balance from snapshot: ${snapshot.data?.data()}');
        return Card(
          color: const Color(0xFF1C1C3A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
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
      key: const ValueKey('admin_analytics_stream'),
      stream: _transactionsStream(),
      builder: (context, snapshot) {
        // If we have NO data yet and it's loading, show spinner
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final now = DateTime.now();
        double dailyTotal = 0;
        Map<String, double> weekDays = {};
        Map<int, double> monthWeeks = {1: 0, 2: 0, 3: 0, 4: 0};

        final docs = snapshot.data?.docs ?? [];
        debugPrint('🔍 WALLET: Processing ${docs.length} transactions');
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          debugPrint('📋 WALLET: Transaction type: ${data['type']}, amount: ${data['amount']}, date: ${data['date']}');
          // TEMP: Show all transactions for debugging
          // if (data['type'] != 'admin_profit') {
          //   debugPrint('⏭️ WALLET: Skipping non-admin transaction');
          //   continue;
          // }
          
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final date = (data['date'] as Timestamp?)?.toDate();
          if (date == null) {
            debugPrint('❌ WALLET: No date found for transaction');
            continue;
          }

          debugPrint('📅 WALLET: Processing transaction: $amount from $date');

          // 1. Daily Calculation (only for admin_profit)
          if (data['type'] == 'admin_profit' && _isToday(date)) {
            dailyTotal += amount;
            debugPrint('✅ WALLET: Added $amount to daily total (now $dailyTotal)');
          }

          // 2. Weekly breakdown (Last 7 days - only admin_profit)
          if (data['type'] == 'admin_profit' && date.isAfter(now.subtract(const Duration(days: 7)))) {
            String dayName = DateFormat('EEEE').format(date);
            weekDays[dayName] = (weekDays[dayName] ?? 0) + amount;
          }

          // 3. Monthly breakdown (This Month only - only admin_profit)
          if (data['type'] == 'admin_profit' && date.year == now.year && date.month == now.month) {
            int weekNum = ((date.day - 1) ~/ 7) + 1;
            if (weekNum > 4) weekNum = 4;
            monthWeeks[weekNum] = (monthWeeks[weekNum] ?? 0) + amount;
          }
        }

        double weeklyTotal = weekDays.values.fold(0, (a, b) => a + b);
        double monthlyTotal = monthWeeks.values.fold(0, (a, b) => a + b);

        debugPrint('💰 WALLET: Final totals - Daily: $dailyTotal, Weekly: $weeklyTotal, Monthly: $monthlyTotal');

        return Column(
          children: [
            _buildStatRow('Today\'s Profit', dailyTotal),
            _buildExpandableStat('Weekly Breakdown', weeklyTotal, weekDays.entries.map((e) => _buildSubRow(e.key, e.value)).toList()),
            _buildExpandableStat('Monthly Breakdown', monthlyTotal, monthWeeks.entries.map((e) => _buildSubRow('Week ${e.key}', e.value)).toList()),
          ],
        );
      },
    );
  }

  Widget _buildStatRow(String title, double amount) {
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
            child: Column(children: children.isEmpty ? [const Text('No earnings found for this period.', style: TextStyle(color: Colors.white24, fontSize: 12))] : children),
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
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
          return const Center(child: Text('No activity found.', style: TextStyle(color: Colors.white10)));
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
            final isPlus = amount > 0;

            return Card(
              color: const Color(0xFF1C1C3A),
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                leading: Icon(isPlus ? Icons.add_circle_outline : Icons.remove_circle_outline, color: isPlus ? Colors.greenAccent : Colors.redAccent, size: 20),
                title: Text(data['reason'] ?? 'Match Transaction', style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(DateFormat('dd MMM, HH:mm').format(date), style: const TextStyle(color: Colors.white24, fontSize: 11)),
                trailing: Text('${isPlus ? "+" : ""}${amount.toStringAsFixed(2)}', style: TextStyle(color: isPlus ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }
}
