import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/simple_payment_fix.dart';
import 'package:mygame/firebase_rules_check.dart';
import 'package:mygame/game_status_checker.dart';
import 'package:mygame/data_type_debugger_fixed.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import the intl package
// Payment debug/test widgets removed to avoid missing-import build errors

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
    
    // Force refresh to avoid cache issues
    return FirebaseFirestore.instance
        .collection('players')
        .doc(user.uid)
        .snapshots(
          // Add options to ensure real-time updates
          includeMetadataChanges: true,
        );
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

  Future<void> _fixAccountData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first'), backgroundColor: Colors.red),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fixing account data...'), backgroundColor: Colors.orange),
      );

      // Get current player data
      final playerDoc = await FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .get();

      if (!playerDoc.exists) {
        // Create new player document
        await FirebaseFirestore.instance
            .collection('players')
            .doc(user.uid)
            .set({
              'name': user.displayName ?? 'Player',
              'email': user.email ?? '',
              'phoneNumber': '',
              'balance': 500.0, // Default balance
              'joinDate': FieldValue.serverTimestamp(),
            });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Account created with 500 ETB balance'), backgroundColor: Colors.green),
        );
      } else {
        // Fix existing data
        final data = playerDoc.data()!;
        Map<String, dynamic> updates = {};
        
        // Fix balance if missing or invalid
        if (!data.containsKey('balance') || data['balance'] == null) {
          updates['balance'] = 500.0;
        } else if (data['balance'] is int) {
          // Convert int balance to double
          updates['balance'] = (data['balance'] as int).toDouble();
        } else if (data['balance'] is String) {
          // Convert string balance to double
          final parsed = double.tryParse(data['balance'] as String);
          if (parsed != null) {
            updates['balance'] = parsed;
          } else {
            updates['balance'] = 500.0;
          }
        }
        
        // Fix name if missing
        if (!data.containsKey('name') || data['name'] == null) {
          updates['name'] = user.displayName ?? 'Player';
        }
        
        // Fix email if missing
        if (!data.containsKey('email') || data['email'] == null) {
          updates['email'] = user.email ?? '';
        }
        
        // Fix joinDate if missing or wrong type
        if (!data.containsKey('joinDate') || data['joinDate'] == null) {
          updates['joinDate'] = FieldValue.serverTimestamp();
        } else if (data['joinDate'] is String) {
          // Convert string date to timestamp
          updates['joinDate'] = FieldValue.serverTimestamp();
        }
        
        if (updates.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('players')
              .doc(user.uid)
              .update(updates);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Fixed ${updates.length} account issues'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Account data looks good'), backgroundColor: Colors.green),
          );
        }
      }
      
      setState(() {}); // Refresh UI
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error fixing account: $e'), backgroundColor: Colors.red),
      );
    }
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
          const SizedBox(height: 8),
          // Data Type Debugger Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DataTypeDebugger()),
                );
              },
              icon: const Icon(Icons.bug_report),
              label: const Text('Debug Data Types'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Game Status Checker Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GameStatusChecker()),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('Check Game Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Payment debug buttons removed
          const SizedBox(height: 16),
          const Text('Transaction History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
        
        // Check if data is from cache - access metadata on DocumentSnapshot, not AsyncSnapshot
        final isFromCache = snapshot.data!.metadata.isFromCache;
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
                      Text('${balance.toStringAsFixed(2)} ETB', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    ]),
                  ],
                ),
                if (isFromCache)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        const Text('Showing cached data', style: TextStyle(color: Colors.orange, fontSize: 12)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Force refresh by clearing cache and re-fetching
                      await FirebaseFirestore.instance.clearPersistence();
                      setState(() {}); // Trigger rebuild
                      
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
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Fix account data
                      await _fixAccountData();
                    },
                    icon: const Icon(Icons.healing, color: Colors.white),
                    label: const Text('Fix Account Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
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
          return const Center(child: Text('No transactions for this filter.', style: TextStyle(color: Colors.white70)));
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
            // Use the intl package to format the date and time
            final formattedDate = date != null ? DateFormat.yMd().add_jm().format(date) : 'N/A';

            return Card(
              color: const Color(0xFF1C1C3A),
              margin: const EdgeInsets.only(bottom: 8.0),
              child: ListTile(
                leading: Icon(amount > 0 ? Icons.arrow_upward : Icons.arrow_downward, color: amount > 0 ? Colors.greenAccent : Colors.redAccent),
                title: Text(reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(formattedDate, style: const TextStyle(color: Colors.white70)),
                trailing: Text('${amount.toStringAsFixed(2)} ETB', style: TextStyle(color: amount > 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            );
          },
        );
      },
    );
  }
}
