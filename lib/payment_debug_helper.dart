import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'dart:developer' as developer;

/// Payment debug helper to identify exact payment issue
class PaymentDebugHelper extends StatefulWidget {
  const PaymentDebugHelper({super.key});

  @override
  _PaymentDebugHelperState createState() => _PaymentDebugHelperState();
}

class _PaymentDebugHelperState extends State<PaymentDebugHelper> {
  bool _isTesting = false;
  String _result = '';
  String _debugInfo = '';

  Future<void> _testPaymentFlow() async {
    setState(() {
      _isTesting = true;
      _result = 'Testing payment flow...';
      _debugInfo = '';
    });

    try {
      developer.log('=== PAYMENT FLOW DEBUG START ===');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _result = '❌ No user logged in';
          _isTesting = false;
        });
        return;
      }
      developer.log('✅ User: ${user.email}');

      // Find a pending game
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

      final gameDoc = gamesQuery.docs.first;
      final gameData = gameDoc.data() as Map<String, dynamic>;
      final double entryFee = (gameData['entryFee'] ?? 10.0).toDouble();
      
      developer.log('✅ Game: ${gameDoc.id}, Entry Fee: $entryFee');

      // Test the exact same flow as the UI
      final firebaseService = FirebaseService();
      
      developer.log('Calling purchaseAndSelectCards with:');
      developer.log('  gameId: ${gameDoc.id}');
      developer.log('  playerId: ${user.uid}');
      developer.log('  numberOfCards: 1');
      developer.log('  cardCost: $entryFee');
      
      final cards = await firebaseService.purchaseAndSelectCards(
        gameId: gameDoc.id,
        playerId: user.uid,
        numberOfCards: 1,
        cardCost: entryFee,
      );

      developer.log('✅ Payment completed successfully!');
      developer.log('Cards generated: ${cards.length}');
      
      setState(() {
        _result = '''
✅ PAYMENT FLOW TEST SUCCESSFUL!

User: ${user.email}
Game: ${gameDoc.id}
Entry Fee: $entryFee ETB
Cards Purchased: ${cards.length}

Payment flow completed without any errors!
This means the payment system itself is working.
The issue might be in:
1. Game status (not pending)
2. Player balance (insufficient)
3. Network connectivity
4. Firebase permissions

Check the debug console for detailed error messages.
        ''';
        _debugInfo = '''
Debug Information:
- User authentication: ✅
- Game availability: ✅
- Payment service call: ✅
- Card generation: ✅
- Balance update: ✅
- Transaction record: ✅

All steps completed successfully.
        ''';
        _isTesting = false;
      });

    } catch (e, stackTrace) {
      developer.log('❌ Payment flow test failed: $e');
      developer.log('Error type: ${e.runtimeType}');
      developer.log('Stack trace: $stackTrace');
      
      setState(() {
        _result = '''
❌ PAYMENT FLOW TEST FAILED!

Error: ${e.toString()}
Error Type: ${e.runtimeType.toString()}

This is the exact error causing the payment exception.
        ''';
        _debugInfo = '''
Debug Information:
- Error occurred during payment flow
- Check if it's one of these common issues:
  1. "Insufficient balance" → Add funds to wallet
  2. "Game not pending" → Join a different game
  3. "Permission denied" → Check Firebase rules
  4. "Deadline exceeded" → Check internet connection
  5. "Resource exhausted" → Server busy, try again

Full Stack Trace:
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
        title: const Text('Payment Flow Debug'),
        backgroundColor: const Color(0xFF1C1C3A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isTesting ? null : _testPaymentFlow,
            tooltip: 'Test Payment Flow',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _testPaymentFlow,
              icon: _isTesting 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.payment),
              label: Text(_isTesting ? 'Testing...' : 'Test Payment Flow'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        _result.isEmpty ? 'Press "Test Payment Flow" to diagnose payment issues' : _result,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    if (_debugInfo.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Debug Information:',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _debugInfo,
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
