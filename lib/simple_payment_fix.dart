import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'dart:developer' as developer;

class SimplePaymentFix extends StatefulWidget {
  const SimplePaymentFix({super.key});

  @override
  State<SimplePaymentFix> createState() => _SimplePaymentFixState();
}

class _SimplePaymentFixState extends State<SimplePaymentFix> {
  bool _isTesting = false;
  String _result = '';
  String _error = '';

  Future<void> _testSimplePayment() async {
    setState(() {
      _isTesting = true;
      _result = '';
      _error = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Please login first';
          _isTesting = false;
        });
        return;
      }

      developer.log('🔍 Starting simple payment test for user: ${user.uid}');

      // Step 1: Find a pending game
      developer.log('\n🔍 Step 1: Finding a pending game...');
      final gamesQuery = await FirebaseFirestore.instance
          .collection('games')
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (gamesQuery.docs.isEmpty) {
        setState(() {
          _error = 'No pending games found. Please create a game first.';
          _isTesting = false;
        });
        return;
      }

      final gameDoc = gamesQuery.docs.first;
      final gameId = gameDoc.id;
      final gameData = gameDoc.data();
      
      developer.log('✅ Found game: $gameId');
      developer.log('Game data: $gameData');

      final cardCost = (gameData['cardCost'] as num?)?.toDouble() ?? 50.0;
      final maxCards = gameData['maxCards'] as int? ?? 1;

      developer.log('Card cost: $cardCost ETB');
      developer.log('Max cards: $maxCards');

      // Step 2: Check player balance
      developer.log('\n🔍 Step 2: Checking player balance...');
      final playerDoc = await FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .get();

      if (!playerDoc.exists) {
        setState(() {
          _error = 'Player document not found.';
          _isTesting = false;
        });
        return;
      }

      final playerData = playerDoc.data()!;
      final balance = (playerData['balance'] as num?)?.toDouble() ?? 0.0;

      developer.log('Current balance: $balance ETB');

      if (balance < cardCost) {
        setState(() {
          _error = 'Insufficient balance. Current: $balance ETB, Required: $cardCost ETB';
          _isTesting = false;
        });
        return;
      }

      // Step 3: Test payment
      developer.log('\n🔍 Step 3: Testing payment...');
      final firebaseService = FirebaseService();
      
      try {
        final cards = await firebaseService.purchaseAndSelectCards(
          gameId: gameId,
          playerId: user.uid,
          numberOfCards: 1,
          cardCost: cardCost,
        );

        developer.log('✅ Payment successful!');
        developer.log('Generated cards: ${cards.length}');

        setState(() {
          _result = '''
✅ PAYMENT SUCCESSFUL!

Game: ${gameData['name'] ?? 'No Name'}
Game ID: $gameId
Entry Fee: $cardCost ETB
Player Balance: $balance ETB
Cards Generated: ${cards.length}
Payment completed without any errors!

Your bingo cards are ready to play.
          ''';
          _isTesting = false;
        });

      } catch (paymentError) {
        developer.log('❌ Payment failed: $paymentError');
        developer.log('Error type: ${paymentError.runtimeType}');
        
        setState(() {
          _error = 'Payment failed: ${paymentError.toString()}';
          _isTesting = false;
        });
      }

    } catch (e) {
      developer.log('❌ Test failed: $e');
      setState(() {
        _error = 'Test failed: $e';
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('Simple Payment Fix'),
        backgroundColor: const Color(0xFF0A0A1A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simple Payment Test',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This test will:\n'
              '1. Find a pending game\n'
              '2. Check your balance\n'
              '3. Test payment with 1 card\n'
              '4. Show detailed results',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _testSimplePayment,
              icon: _isTesting 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.payment),
              label: Text(_isTesting ? 'Testing...' : 'Test Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
            const SizedBox(height: 32),
            if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Error',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            if (_result.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Success',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _result,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
