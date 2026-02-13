import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'dart:developer' as developer;

/// Deep payment debug to find exact issue
class DeepPaymentDebug extends StatefulWidget {
  const DeepPaymentDebug({super.key});

  @override
  _DeepPaymentDebugState createState() => _DeepPaymentDebugState();
}

class _DeepPaymentDebugState extends State<DeepPaymentDebug> {
  bool _isTesting = false;
  String _testResult = '';
  String _debugInfo = '';
  Map<String, dynamic>? _gameData;
  Map<String, dynamic>? _playerData;

  Future<void> _runDeepDebug() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Running deep debug analysis...';
      _debugInfo = '';
    });

    try {
      developer.log('=== DEEP PAYMENT DEBUG START ===');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _testResult = '❌ No user logged in';
          _isTesting = false;
        });
        return;
      }
      developer.log('✅ User logged in: ${user.email}');
      developer.log('✅ User ID: ${user.uid}');

      // Step 1: Get ALL games and check each one
      developer.log('\n🔍 STEP 1: CHECKING ALL GAMES');
      final allGamesQuery = await FirebaseFirestore.instance
          .collection('games')
          .get();

      developer.log('✅ Found ${allGamesQuery.docs.length} total games');
      
      for (var doc in allGamesQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        developer.log('Game: ${data['gameName']} (${doc.id}) - Status: "${data['status']}"');
      }

      // Step 2: Find pending games
      final pendingGames = allGamesQuery.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['status'] == 'pending';
      }).toList();

      if (pendingGames.isEmpty) {
        setState(() {
          _testResult = '❌ No pending games found';
          _debugInfo = 'All games are not in "pending" status. Found ${allGamesQuery.docs.length} games, but none are pending.\n\nGame statuses found:\n${allGamesQuery.docs.map((doc) => '- ${doc.data()['gameName']}: "${doc.data()['status']}"').join('\n')}';
          _isTesting = false;
        });
        return;
      }

      developer.log('✅ Found ${pendingGames.length} pending games');
      
      // Use the first pending game
      final gameDoc = pendingGames.first;
      _gameData = gameDoc.data() as Map<String, dynamic>;
      final String gameId = gameDoc.id;
      
      developer.log('✅ Using game: ${_gameData!['gameName']} ($gameId)');
      developer.log('Game data: $_gameData');

      // Step 3: Check player data in detail
      developer.log('\n🔍 STEP 2: DEEP PLAYER DATA CHECK');
      final playerDoc = await FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .get();

      if (!playerDoc.exists) {
        setState(() {
          _testResult = '❌ Player document not found';
          _debugInfo = 'Player ${user.uid} does not exist in players collection.\n\nSolution: Create player document in Firebase Console.';
          _isTesting = false;
        });
        return;
      }

      _playerData = playerDoc.data() as Map<String, dynamic>;
      developer.log('✅ Player document exists');
      developer.log('Player data: $_playerData');

      // Step 4: Check if player already has cards for this game
      developer.log('\n🔍 STEP 3: CHECKING EXISTING PLAYER DATA');
      final playerGameDataDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(gameId)
          .collection('playerData')
          .doc(user.uid)
          .get();

      if (playerGameDataDoc.exists) {
        final playerGameData = playerGameDataDoc.data() as Map<String, dynamic>;
        developer.log('⚠️ Player already has data for this game');
        developer.log('Player game data: $playerGameData');
        
        if (playerGameData.containsKey('cards') && playerGameData['cards'] != null) {
          final cards = playerGameData['cards'] as List;
          if (cards.isNotEmpty) {
            setState(() {
              _testResult = '❌ Player already has cards for this game';
              _debugInfo = 'Player already purchased ${cards.length} cards for this game.\n\nSolution: Delete playerData sub-document for this game in Firebase Console:\ngames/$gameId/playerData/${user.uid}';
              _isTesting = false;
            });
            return;
          }
        }
      } else {
        developer.log('✅ No existing player data for this game');
      }

      // Step 5: Validate all payment requirements
      developer.log('\n🔍 STEP 4: VALIDATING PAYMENT REQUIREMENTS');
      
      final double entryFee = (_gameData!['entryFee'] ?? 10.0).toDouble();
      final double playerBalance = (_playerData!['balance'] ?? 0.0).toDouble();
      final String gameStatus = _gameData!['status'] ?? 'unknown';
      
      developer.log('Entry Fee: $entryFee ETB');
      developer.log('Player Balance: $playerBalance ETB');
      developer.log('Game Status: "$gameStatus"');
      developer.log('Game Max Players: ${_gameData!['maxPlayers']}');
      developer.log('Current Players: ${(_gameData!['players'] as List).length}');

      bool canPay = true;
      String validationError = '';

      if (gameStatus != 'pending') {
        canPay = false;
        validationError = 'Game status is "$gameStatus" (must be "pending")';
      } else if (playerBalance < entryFee) {
        canPay = false;
        validationError = 'Insufficient balance (have: $playerBalance, need: $entryFee)';
      } else if ((_gameData!['players'] as List).length >= (_gameData!['maxPlayers'] ?? 4)) {
        canPay = false;
        validationError = 'Game is full (${(_gameData!['players'] as List).length}/${_gameData!['maxPlayers']} players)';
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

      // Step 6: Test actual payment with detailed logging
      developer.log('\n🔍 STEP 5: TESTING ACTUAL PAYMENT');
      
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

Game: ${_gameData!['gameName']} ($gameId)
Entry Fee: $entryFee ETB
Player Balance: $playerBalance ETB
Cards Purchased: ${cards.length}

Payment completed without any errors!
The payment system is working correctly.
        ''';
        _debugInfo = '''
Complete Validation Results:
✅ Game status: "$gameStatus" (correct)
✅ Player balance: $playerBalance ETB (sufficient)
✅ Game capacity: ${(_gameData!['players'] as List).length}/${_gameData!['maxPlayers']} (space available)
✅ No existing cards: Clean slate
✅ Payment parameters: All correct
✅ Transaction: Completed successfully
✅ Cards generated: ${cards.length}

Everything is working perfectly!
        ''';
        _isTesting = false;
      });

    } catch (e, stackTrace) {
      developer.log('❌ Deep debug failed: $e');
      developer.log('Error type: ${e.runtimeType}');
      developer.log('Stack trace: $stackTrace');
      
      setState(() {
        _testResult = '''
❌ PAYMENT TEST FAILED!

Error: ${e.toString()}
Error Type: ${e.runtimeType.toString()}

This is the exact error causing payment failures.
        ''';
        _debugInfo = '''
Complete Debug Information:
- User: ${FirebaseAuth.instance.currentUser?.email}
- User ID: ${FirebaseAuth.instance.currentUser?.uid}
- Game: ${_gameData?['gameName']} ($gameId)
- Game Status: ${_gameData?['status'] ?? 'N/A'}
- Player Balance: ${_playerData?['balance'] ?? 'N/A'}
- Entry Fee: ${_gameData?['entryFee'] ?? 'N/A'}
- Game Players: ${_gameData?['players']?.length ?? 0}/${_gameData?['maxPlayers'] ?? 'N/A'}

Possible Issues:
1. Game status is not actually "pending" (check Firebase Console)
2. Player balance is insufficient
3. Game is full
4. Player already has cards for this game
5. Network connectivity issues
6. Firebase security rules blocking operation

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
        title: const Text('Deep Payment Debug'),
        backgroundColor: const Color(0xFF1C1C3A),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _isTesting ? null : _runDeepDebug,
            tooltip: 'Run Deep Debug',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _runDeepDebug,
              icon: _isTesting 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_isTesting ? 'Debugging...' : 'Run Deep Payment Debug'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
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
                        _testResult.isEmpty ? 'Press "Run Deep Payment Debug" to analyze the exact issue' : _testResult,
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
                          color: Colors.red.withOpacity(0.1),
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Deep Debug Analysis:',
                              style: TextStyle(
                                color: Colors.red,
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
