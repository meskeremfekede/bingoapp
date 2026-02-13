import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'dart:developer' as developer;

/// Quick payment test to verify the fix
class QuickPaymentTest extends StatefulWidget {
  const QuickPaymentTest({super.key});

  @override
  _QuickPaymentTestState createState() => _QuickPaymentTestState();
}

class _QuickPaymentTestState extends State<QuickPaymentTest> {
  bool _isTesting = false;
  String _result = '';

  Future<void> _runQuickTest() async {
    setState(() {
      _isTesting = true;
      _result = 'Testing payment...';
    });

    try {
      developer.log('=== QUICK PAYMENT TEST START ===');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _result = '❌ No user logged in';
          _isTesting = false;
        });
        return;
      }
      developer.log('✅ User logged in: ${user.email}');

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
      
      developer.log('✅ Found game: ${gameDoc.id}');
      developer.log('Entry fee: $entryFee');

      // Test the payment service
      final firebaseService = FirebaseService();
      
      developer.log('Calling purchaseAndSelectCards...');
      final cards = await firebaseService.purchaseAndSelectCards(
        gameId: gameDoc.id,
        playerId: user.uid,
        numberOfCards: 1,
        cardCost: entryFee,
      );

      developer.log('✅ Payment successful! Cards: ${cards.length}');
      
      setState(() {
        _result = '''
✅ PAYMENT SUCCESS!

User: ${user.email}
Game: ${gameDoc.id}
Entry Fee: $entryFee ETB
Cards Purchased: ${cards.length}

Payment completed successfully!
Cards generated: ${cards.map((card) => card.take(5).join(', ')).join(' | ')}
        ''';
        _isTesting = false;
      });

    } catch (e, stackTrace) {
      developer.log('❌ Payment test failed: $e');
      developer.log('Stack trace: $stackTrace');
      
      setState(() {
        _result = '''
❌ PAYMENT FAILED!

Error: ${e.toString()}
Error Type: ${e.runtimeType.toString()}

This is the exact error causing the payment exception.
Check the console logs for detailed information.
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
        title: const Text('Quick Payment Test'),
        backgroundColor: const Color(0xFF1C1C3A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isTesting ? null : _runQuickTest,
              child: _isTesting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Test Payment'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C3A),
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _result.isEmpty ? 'Press "Test Payment" to verify the payment fix' : _result,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
