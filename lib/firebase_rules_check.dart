import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseRulesCheck extends StatefulWidget {
  const FirebaseRulesCheck({super.key});

  @override
  State<FirebaseRulesCheck> createState() => _FirebaseRulesCheckState();
}

class _FirebaseRulesCheckState extends State<FirebaseRulesCheck> {
  bool _isChecking = false;
  List<Map<String, dynamic>> _results = [];
  String _error = '';

  Future<void> _checkFirebaseRules() async {
    setState(() {
      _isChecking = true;
      _results = [];
      _error = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Please login first';
          _isChecking = false;
        });
        return;
      }

      print('🔍 Checking Firebase rules for user: ${user.uid}');

      List<Map<String, dynamic>> results = [];

      // Test 1: Read access to players collection
      try {
        final playerDoc = await FirebaseFirestore.instance
            .collection('players')
            .doc(user.uid)
            .get();
        
        results.add({
          'test': 'Read own player document',
          'status': playerDoc.exists ? '✅ PASS' : '❌ FAIL',
          'details': playerDoc.exists ? 'Can read own data' : 'Cannot read own data',
          'color': playerDoc.exists ? Colors.green : Colors.red,
        });
      } catch (e) {
        results.add({
          'test': 'Read own player document',
          'status': '❌ FAIL',
          'details': 'Error: $e',
          'color': Colors.red,
        });
      }

      // Test 2: Write access to players collection (balance update)
      try {
        // Try to read first to get current balance
        final playerDoc = await FirebaseFirestore.instance
            .collection('players')
            .doc(user.uid)
            .get();
        
        if (playerDoc.exists) {
          final currentBalance = (playerDoc.data()!['balance'] as num?)?.toDouble() ?? 0.0;
          
          // Try to update balance (should succeed)
          await FirebaseFirestore.instance
              .collection('players')
              .doc(user.uid)
              .update({'balance': currentBalance});
          
          results.add({
            'test': 'Update own balance',
            'status': '✅ PASS',
            'details': 'Can update own balance',
            'color': Colors.green,
          });
        } else {
          results.add({
            'test': 'Update own balance',
            'status': '❌ FAIL',
            'details': 'Player document does not exist',
            'color': Colors.red,
          });
        }
      } catch (e) {
        results.add({
          'test': 'Update own balance',
          'status': '❌ FAIL',
          'details': 'Error: $e',
          'color': Colors.red,
        });
      }

      // Test 3: Read access to games collection
      try {
        final gamesQuery = await FirebaseFirestore.instance
            .collection('games')
            .limit(5)
            .get();
        
        results.add({
          'test': 'Read games collection',
          'status': '✅ PASS',
          'details': 'Can read ${gamesQuery.docs.length} games',
          'color': Colors.green,
        });
      } catch (e) {
        results.add({
          'test': 'Read games collection',
          'status': '❌ FAIL',
          'details': 'Error: $e',
          'color': Colors.red,
        });
      }

      // Test 4: Read access to transactions subcollection
      try {
        final transactionsQuery = await FirebaseFirestore.instance
            .collection('players')
            .doc(user.uid)
            .collection('transactions')
            .limit(5)
            .get();
        
        results.add({
          'test': 'Read own transactions',
          'status': '✅ PASS',
          'details': 'Can read ${transactionsQuery.docs.length} transactions',
          'color': Colors.green,
        });
      } catch (e) {
        results.add({
          'test': 'Read own transactions',
          'status': '❌ FAIL',
          'details': 'Error: $e',
          'color': Colors.red,
        });
      }

      // Test 5: Write access to transactions subcollection
      try {
        final testTransaction = {
          'amount': 0.0,
          'type': 'test',
          'reason': 'Firebase rules test',
          'date': FieldValue.serverTimestamp(),
          'test': true,
        };

        await FirebaseFirestore.instance
            .collection('players')
            .doc(user.uid)
            .collection('transactions')
            .add(testTransaction);
        
        results.add({
          'test': 'Create transaction',
          'status': '✅ PASS',
          'details': 'Can create transactions',
          'color': Colors.green,
        });

        // Clean up test transaction
        final transactionsQuery = await FirebaseFirestore.instance
            .collection('players')
            .doc(user.uid)
            .collection('transactions')
            .where('test', isEqualTo: true)
            .get();
        
        for (var doc in transactionsQuery.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        results.add({
          'test': 'Create transaction',
          'status': '❌ FAIL',
          'details': 'Error: $e',
          'color': Colors.red,
        });
      }

      setState(() {
        _results = results;
        _isChecking = false;
      });

    } catch (e) {
      print('❌ Error checking Firebase rules: $e');
      setState(() {
        _error = 'Error: $e';
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('Firebase Rules Check'),
        backgroundColor: const Color(0xFF0A0A1A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isChecking ? null : _checkFirebaseRules,
              icon: _isChecking 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.security),
              label: Text(_isChecking ? 'Checking...' : 'Check Firebase Rules'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            if (_results.isNotEmpty) ...[
              const Text(
                'Firebase Rules Test Results:',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return Card(
                      color: const Color(0xFF1C1C3A),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    result['test'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: result['color'],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    result['status'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              result['details'],
                              style: TextStyle(
                                color: result['color'] == Colors.green ? Colors.green[300] : Colors.red[300],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
