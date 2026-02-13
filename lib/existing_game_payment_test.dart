import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'dart:developer' as developer;

/// Test payment with your existing game document
class ExistingGamePaymentTest extends StatefulWidget {
  const ExistingGamePaymentTest({super.key});

  @override
  _ExistingGamePaymentTestState createState() => _ExistingGamePaymentTestState();
}

class _ExistingGamePaymentTestState extends State<ExistingGamePaymentTest> {
  bool _isTesting = false;
  String _testResult = '';
  String _debugInfo = '';
  List<Map<String, dynamic>> _availableGames = [];
  String? _selectedGameId;

  Future<void> _loadAvailableGames() async {
    try {
      developer.log('=== LOADING AVAILABLE GAMES ===');
      
      final gamesQuery = await FirebaseFirestore.instance
          .collection('games')
          .get();

      _availableGames = gamesQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['gameName'] ?? 'Unknown Game',
          'status': data['status'] ?? 'unknown',
          'entryFee': (data['entryFee'] ?? 0.0).toDouble(),
          'players': List<String>.from(data['players'] ?? []),
          'maxPlayers': data['maxPlayers'] ?? 4,
        };
      }).toList();

      developer.log('✅ Found ${_availableGames.length} games');
      for (var game in _availableGames) {
        developer.log('Game: ${game['name']} (${game['id']}) - Status: ${game['status']}');
      }

      setState(() {});
    } catch (e) {
      developer.log('❌ Error loading games: $e');
      setState(() {
        _debugInfo = 'Error loading games: $e';
      });
    }
  }

  Future<void> _testPaymentWithSelectedGame() async {
    if (_selectedGameId == null) {
      setState(() {
        _testResult = '❌ Please select a game first';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = 'Testing payment with selected game...';
      _debugInfo = '';
    });

    try {
      developer.log('=== TESTING PAYMENT WITH EXISTING GAME ===');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _testResult = '❌ No user logged in';
          _isTesting = false;
        });
        return;
      }
      developer.log('✅ User logged in: ${user.email}');

      // Get selected game details
      final selectedGame = _availableGames.firstWhere((game) => game['id'] == _selectedGameId);
      developer.log('Selected game: ${selectedGame['name']} (${selectedGame['id']})');
      developer.log('Game status: ${selectedGame['status']}');
      developer.log('Entry fee: ${selectedGame['entryFee']} ETB');

      // Check player balance
      developer.log('\n🔍 CHECKING PLAYER BALANCE...');
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

      final playerData = playerDoc.data() as Map<String, dynamic>;
      final double playerBalance = (playerData['balance'] ?? 0.0).toDouble();
      developer.log('✅ Player balance: $playerBalance ETB');

      // Validate payment requirements
      developer.log('\n🔍 VALIDATING PAYMENT REQUIREMENTS...');
      
      final String gameStatus = selectedGame['status'];
      final double entryFee = selectedGame['entryFee'];
      
      if (gameStatus != 'pending') {
        setState(() {
          _testResult = '❌ Game is not pending';
          _debugInfo = 'Game status is "$gameStatus" - must be "pending" for payments\n\nSOLUTION: In Firebase Console, change game status to "pending"';
          _isTesting = false;
        });
        return;
      }

      if (playerBalance < entryFee) {
        setState(() {
          _testResult = '❌ Insufficient balance';
          _debugInfo = 'Player balance: $playerBalance ETB\nRequired: $entryFee ETB\n\nSOLUTION: In Firebase Console, add balance to player document';
          _isTesting = false;
        });
        return;
      }

      developer.log('✅ All validation checks passed');

      // Test actual payment
      developer.log('\n🔍 TESTING ACTUAL PAYMENT...');
      
      final firebaseService = FirebaseService();
      
      developer.log('Calling purchaseAndSelectCards with:');
      developer.log('  gameId: $_selectedGameId');
      developer.log('  playerId: ${user.uid}');
      developer.log('  numberOfCards: 1');
      developer.log('  cardCost: $entryFee');
      
      final cards = await firebaseService.purchaseAndSelectCards(
        gameId: _selectedGameId!,
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

Game: ${selectedGame['name']} (${selectedGame['id']})
Entry Fee: $entryFee ETB
Player Balance: $playerBalance ETB
Cards Purchased: ${cards.length}

Payment completed without any errors!
Your existing game is working perfectly!
        ''';
        _debugInfo = '''
Validation Results:
✅ Game status: $gameStatus (correct)
✅ Player balance: $playerBalance ETB (sufficient)
✅ Payment parameters: All correct
✅ Transaction: Completed successfully
✅ Cards generated: ${cards.length}

Your existing game document is working perfectly!
The payment system is functioning correctly.
        ''';
        _isTesting = false;
      });

    } catch (e, stackTrace) {
      developer.log('❌ Payment test failed: $e');
      developer.log('Error type: ${e.runtimeType}');
      developer.log('Stack trace: $stackTrace');
      
      setState(() {
        _testResult = '''
❌ PAYMENT TEST FAILED!

Error: ${e.toString()}
Error Type: ${e.runtimeType.toString()}

This is the exact error from your existing game.
        ''';
        _debugInfo = '''
Debug Information:
- User: ${FirebaseAuth.instance.currentUser?.email}
- Selected Game: ${_selectedGameId}
- Game Status: ${_availableGames.firstWhere((game) => game['id'] == _selectedGameId, orElse: () => {'status': 'unknown'})['status']}
- Player Balance: ${FirebaseAuth.instance.currentUser != null ? 'Check Firebase Console' : 'N/A'}
- Entry Fee: ${_availableGames.firstWhere((game) => game['id'] == _selectedGameId, orElse: () => {'entryFee': 0})['entryFee']} ETB

Common Solutions:
1. Check game status in Firebase Console (must be "pending")
2. Check player balance in Firebase Console
3. Check if player already has cards for this game
4. Check network connection

Full Error Details:
$stackTrace
        ''';
        _isTesting = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableGames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('Test Existing Game Payment'),
        backgroundColor: const Color(0xFF1C1C3A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isTesting ? null : _loadAvailableGames,
            tooltip: 'Refresh Games',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Game Selection
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C3A),
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Game to Test:',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_availableGames.isEmpty)
                    const Text(
                      'No games found. Create a game in Firebase Console first.',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    DropdownButton<String>(
                      value: _selectedGameId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1C1C3A),
                      style: const TextStyle(color: Colors.white),
                      items: _availableGames.map((game) {
                        return DropdownMenuItem<String>(
                          value: game['id'],
                          child: Text(
                            '${game['name']} (${game['status']}) - ${game['entryFee']} ETB',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGameId = value;
                        });
                      },
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Test Button
            ElevatedButton.icon(
              onPressed: (_isTesting || _selectedGameId == null) ? null : _testPaymentWithSelectedGame,
              icon: _isTesting 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.payment),
              label: Text(_isTesting ? 'Testing...' : 'Test Payment with Selected Game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Results
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
                        _testResult.isEmpty ? 'Select a game and click "Test Payment"' : _testResult,
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
