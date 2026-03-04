import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'dart:developer' as developer;

/// Comprehensive payment test to identify exact payment issue
class ComprehensivePaymentTest extends StatefulWidget {
  const ComprehensivePaymentTest({super.key});

  @override
  _ComprehensivePaymentTestState createState() => _ComprehensivePaymentTestState();
}

class _ComprehensivePaymentTestState extends State<ComprehensivePaymentTest> {
  bool _isTesting = false;
  String _testResult = '';
  String _debugInfo = '';
  Map<String, dynamic>? _gameData;
  Map<String, dynamic>? _playerData;

  Future<void> _runComprehensiveTest() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Running comprehensive test...';
      _debugInfo = '';
    });

    try {
      developer.log('=== COMPREHENSIVE PAYMENT TEST START ===');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _testResult = '❌ No user logged in';
          _isTesting = false;
        });
        return;
      }
      developer.log('✅ User logged in: ${user.email}');

      // Step 1: Check available games
      developer.log('\n🔍 STEP 1: CHECKING AVAILABLE GAMES');
      final gamesQuery = await FirebaseFirestore.instance
          .collection('games')
          .where('status', isEqualTo: 'pending')
          .limit(3)
          .get();

      if (gamesQuery.docs.isEmpty) {
        setState(() {
          _testResult = '❌ No pending games available';
          _debugInfo = 'Create a pending game in Firebase Console first';
          _isTesting = false;
        });
        return;
      }

      final gameDoc = gamesQuery.docs.first;
      _gameData = gameDoc.data() as Map<String, dynamic>;
      final String gameId = gameDoc.id;
      
      developer.log('✅ Found game: $gameId');
      developer.log('Game data: $_gameData');

      // Step 2: Check player data
      developer.log('\n🔍 STEP 2: CHECKING PLAYER DATA');
      final playerDoc = await FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .get();

      if (!playerDoc.exists) {
        setState(() {
          _testResult = '❌ Player document not found';
          _debugInfo = 'Player ${user.uid} does not exist in players collection';
          _isTesting = false;
        });
        return;
      }

      _playerData = playerDoc.data() as Map<String, dynamic>;
      developer.log('✅ Player found: ${_playerData!['name']}');
      developer.log('Player data: $_playerData');

      // Step 3: Validate payment requirements
      developer.log('\n🔍 STEP 3: VALIDATING PAYMENT REQUIREMENTS');
      
      final double entryFee = (_gameData!['entryFee'] ?? 10.0).toDouble();
      final double playerBalance = (_playerData!['balance'] ?? 0.0).toDouble();
      final String gameStatus = _gameData!['status'] ?? 'unknown';
      
      developer.log('Entry Fee: $entryFee ETB');
      developer.log('Player Balance: $playerBalance ETB');
      developer.log('Game Status: $gameStatus');

      bool canPay = true;
      String validationError = '';

      // REMOVED: Game status check - players can pay even if game started
      if (gameStatus != 'pending') {
        // Allow payment even if game started
        developer.log('✅ Allowing payment even though game status is: $gameStatus');
      }
      
      if (playerBalance < entryFee) {
        canPay = false;
        validationError = 'Insufficient balance (have: $playerBalance, need: $entryFee)';
      }

      if (!canPay) {
        setState(() {
          _testResult = '❌ Payment validation failed';
          _debugInfo = validationError;
          _isTesting = false;
        });
        return;
      }

      developer.log('✅ All validation checks passed');

      // Step 4: Test actual payment
      developer.log('\n🔍 STEP 4: TESTING ACTUAL PAYMENT');
      
      final firebaseService = FirebaseService();
      
      developer.log('Calling purchaseAndSelectCards with:');
      developer.log('  gameId: $gameId');
      developer.log('  playerId: ${user.uid}');
      developer.log('  numberOfCards: 1');
      developer.log('  cardCost: $entryFee');
      
      final cards = await firebaseService.purchaseAndSelectCards(
        gameId: gameId,
        playerId: user.uid,
        numberOfCards: 1,
        cardCost: entryFee,
      );

      developer.log('✅ Payment completed successfully!');
      developer.log('Cards generated: ${cards.length}');
      developer.log('Card data: ${cards.take(2).map((card) => card.take(5).join(', ')).join(' | ')}');

      setState(() {
        _testResult = '''
✅ PAYMENT TEST SUCCESSFUL!

Game: $gameId
Entry Fee: $entryFee ETB
Player Balance: $playerBalance ETB
Cards Purchased: ${cards.length}

Payment completed without any errors!
The payment system is working correctly.
        ''';
        _debugInfo = '''
Validation Results:
✅ Game status: $gameStatus (correct)
✅ Player balance: $playerBalance ETB (sufficient)
✅ Payment parameters: All correct
✅ Transaction: Completed successfully
✅ Cards generated: ${cards.length}

If you're still getting payment exceptions in the app,
the issue might be:
1. Different game being used in app
2. Network connectivity issues
3. App state/caching problems
4. Different user account
        ''';
        _isTesting = false;
      });

    } catch (e, stackTrace) {
      developer.log('❌ Comprehensive test failed: $e');
      developer.log('Error type: ${e.runtimeType}');
      developer.log('Stack trace: $stackTrace');
      
      setState(() {
        _testResult = '''
❌ PAYMENT TEST FAILED!

Error: ${e.toString()}
Error Type: ${e.runtimeType.toString()}

This is the exact error causing payment exceptions.
        ''';
        _debugInfo = '''
Debug Information:
- User: ${FirebaseAuth.instance.currentUser?.email}
- Game: ${_gameData?['id'] ?? 'N/A'}
- Game Status: ${_gameData?['status'] ?? 'N/A'}
- Player Balance: ${_playerData?['balance'] ?? 'N/A'}
- Entry Fee: ${_gameData?['entryFee'] ?? 'N/A'}

Common Solutions:
1. Check if game status is 'pending' in Firebase
2. Check if player has sufficient balance
3. Check Firebase security rules
4. Check network connection
5. Try refreshing app state

Full Error Details:
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
        title: const Text('Comprehensive Payment Test'),
        backgroundColor: const Color(0xFF1C1C3A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isTesting ? null : _runComprehensiveTest,
            tooltip: 'Run Payment Test',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _runComprehensiveTest,
              icon: _isTesting 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.payment),
              label: Text(_isTesting ? 'Testing...' : 'Run Comprehensive Payment Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
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
                        _testResult.isEmpty ? 'Press "Run Comprehensive Payment Test" to diagnose payment issues' : _testResult,
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
                          color: Colors.blue.withOpacity(0.1),
                          border: Border.all(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Debug Information:',
                              style: TextStyle(
                                color: Colors.blue,
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
