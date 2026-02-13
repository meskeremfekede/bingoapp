import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

/// Simple payment test to identify the exact issue
class PaymentTestDebug extends StatefulWidget {
  const PaymentTestDebug({super.key});

  @override
  _PaymentTestDebugState createState() => _PaymentTestDebugState();
}

class _PaymentTestDebugState extends State<PaymentTestDebug> {
  bool _isTesting = false;
  String _result = '';
  String _errorDetails = '';

  Future<void> _runPaymentTest() async {
    setState(() {
      _isTesting = true;
      _result = 'Testing payment...';
      _errorDetails = '';
    });

    try {
      developer.log('=== PAYMENT TEST START ===');
      
      // Step 1: Check user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _result = '❌ No user logged in';
          _isTesting = false;
        });
        return;
      }
      developer.log('✅ User logged in: ${user.email}');

      // Step 2: Check player document
      final playerRef = FirebaseFirestore.instance.collection('players').doc(user.uid);
      final playerSnap = await playerRef.get();

      if (!playerSnap.exists) {
        setState(() {
          _result = '❌ Player document does not exist\nUser ID: ${user.uid}';
          _isTesting = false;
        });
        return;
      }
      developer.log('✅ Player document exists');

      final playerData = playerSnap.data() as Map<String, dynamic>;
      final dynamic balance = playerData['balance'];
      developer.log('Player balance: $balance (type: ${balance.runtimeType})');

      // Step 3: Check available games
      final gamesQuery = await FirebaseFirestore.instance
          .collection('games')
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (gamesQuery.docs.isEmpty) {
        setState(() {
          _result = '❌ No pending games available';
          _isTesting = false;
        });
        return;
      }
      developer.log('✅ Found ${gamesQuery.docs.length} pending games');

      final gameDoc = gamesQuery.docs.first;
      final gameData = gameDoc.data() as Map<String, dynamic>;
      final double entryFee = (gameData['entryFee'] ?? 10.0).toDouble();
      developer.log('Game entry fee: $entryFee');

      // Step 4: Test actual payment
      developer.log('Starting payment test...');
      final gameRef = FirebaseFirestore.instance.collection('games').doc(gameDoc.id);
      final playerDataRef = gameRef.collection('playerData').doc(user.uid);
      final transactionRef = playerRef.collection('transactions').doc();

      final double totalCost = entryFee * 1; // Test with 1 card

      developer.log('Payment details:');
      developer.log('Game ID: ${gameDoc.id}');
      developer.log('Player ID: ${user.uid}');
      developer.log('Total Cost: $totalCost');

      // Try to run the payment
      try {
        final result = await FirebaseFirestore.instance.runTransaction((transaction) async {
          developer.log('Transaction started...');
          
          // Get player data
          final playerSnap = await transaction.get(playerRef);
          if (!playerSnap.exists) {
            developer.log('❌ Player not found in transaction');
            throw Exception('Player not found.');
          }
          developer.log('✅ Player found in transaction');

          // Check balance
          final playerData = playerSnap.data() as Map<String, dynamic>?;
          if (playerData == null) {
            developer.log('❌ Player data is null in transaction');
            throw Exception('Player data is null.');
          }

          final dynamic balanceValue = playerData['balance'];
          developer.log('Balance in transaction: $balanceValue (type: ${balanceValue.runtimeType})');
          
          if (balanceValue == null) {
            developer.log('❌ Balance is null in transaction');
            throw Exception('Balance is null.');
          }

          double currentBalance = 0.0;
          if (balanceValue is num) {
            currentBalance = balanceValue.toDouble();
          } else if (balanceValue is String) {
            currentBalance = double.tryParse(balanceValue) ?? 0.0;
          } else {
            developer.log('❌ Invalid balance type in transaction: ${balanceValue.runtimeType}');
            throw Exception('Invalid balance type.');
          }

          developer.log('Current balance: $currentBalance, Required: $totalCost');
          
          if (currentBalance < totalCost) {
            developer.log('❌ Insufficient balance in transaction');
            throw Exception('Insufficient balance.');
          }

          developer.log('✅ Balance check passed in transaction');

          // Update balance
          transaction.update(playerRef, {'balance': FieldValue.increment(-totalCost)});
          developer.log('✅ Balance updated in transaction');

          // Create transaction record
          transaction.set(transactionRef, {
            'amount': -totalCost,
            'type': 'test_payment',
            'reason': 'Test payment',
            'date': FieldValue.serverTimestamp(),
            'gameId': gameDoc.id,
          });
          developer.log('✅ Transaction record created');

          return ['test_card']; // Return dummy card
        }, timeout: const Duration(seconds: 10));

        developer.log('✅ Payment test completed successfully');
        
        setState(() {
          _result = '''
✅ PAYMENT TEST SUCCESSFUL!

User: ${user.email}
Player ID: ${user.uid}
Balance: $balance ETB
Game ID: ${gameDoc.id}
Entry Fee: $entryFee ETB
Total Cost: $totalCost ETB

Payment completed successfully!
Transaction result: $result
          ''';
          _isTesting = false;
        });

      } catch (paymentError, stackTrace) {
        developer.log('❌ Payment test failed: $paymentError');
        developer.log('Stack trace: $stackTrace');
        
        setState(() {
          _result = '''
❌ PAYMENT TEST FAILED!

Error: ${paymentError.toString()}
Error Type: ${paymentError.runtimeType.toString()}

This is the exact error causing the payment exception.
          ''';
          _errorDetails = '''
Stack Trace:
$stackTrace

This shows exactly where the payment is failing.
          ''';
          _isTesting = false;
        });
      }

    } catch (e, stackTrace) {
      developer.log('❌ Test setup failed: $e');
      developer.log('Stack trace: $stackTrace');
      
      setState(() {
        _result = '''
❌ TEST SETUP FAILED!

Error: ${e.toString()}
Error Type: ${e.runtimeType.toString()}

This error occurred before the payment test started.
        ''';
        _errorDetails = '''
Stack Trace:
$stackTrace
        ''';
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('Payment Test Debug'),
        backgroundColor: const Color(0xFF1C1C3A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isTesting ? null : _runPaymentTest,
              child: _isTesting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Run Payment Test'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C3A),
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _result.isEmpty ? 'Press "Run Payment Test" to check payment issues' : _result,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    if (_errorDetails.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Error Details:',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorDetails,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
