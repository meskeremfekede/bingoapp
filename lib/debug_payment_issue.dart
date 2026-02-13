import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';

/// Debug tool to diagnose payment issues
class PaymentDebugScreen extends StatefulWidget {
  const PaymentDebugScreen({super.key});

  @override
  _PaymentDebugScreenState createState() => _PaymentDebugScreenState();
}

class _PaymentDebugScreenState extends State<PaymentDebugScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isChecking = false;
  String _debugInfo = '';
  String _errorMessage = '';

  Future<void> _checkPaymentPrerequisites() async {
    setState(() {
      _isChecking = true;
      _debugInfo = '';
      _errorMessage = '';
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'No user logged in';
          _isChecking = false;
        });
        return;
      }

      final playerRef = FirebaseFirestore.instance.collection('players').doc(user.uid);
      final playerSnap = await playerRef.get();

      if (!playerSnap.exists) {
        setState(() {
          _errorMessage = 'Player document does not exist';
          _isChecking = false;
        });
        return;
      }

      final playerData = playerSnap.data() as Map<String, dynamic>;
      final double balance = (playerData['balance'] ?? 0.0).toDouble();

      // Check available games
      final gamesQuery = await FirebaseFirestore.instance
          .collection('games')
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (gamesQuery.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No pending games available';
          _isChecking = false;
        });
        return;
      }

      final gameDoc = gamesQuery.docs.first;
      final gameData = gameDoc.data() as Map<String, dynamic>;
      final double entryFee = (gameData['entryFee'] ?? 10.0).toDouble();

      setState(() {
        _debugInfo = '''
✅ Payment Prerequisites Check:

User ID: ${user.uid}
Player Balance: ${balance.toStringAsFixed(2)} ETB
Available Games: ${gamesQuery.docs.length}
Game ID: ${gameDoc.id}
Entry Fee: ${entryFee.toStringAsFixed(2)} ETB
Can Afford 1 Card: ${balance >= entryFee ? 'YES' : 'NO'}
Can Afford 2 Cards: ${balance >= (entryFee * 2) ? 'YES' : 'NO'}
Can Afford 3 Cards: ${balance >= (entryFee * 3) ? 'YES' : 'NO'}

Player Data Fields: ${playerData.keys.join(', ')}
Game Data Fields: ${gameData.keys.join(', ')}
        ''';
        _isChecking = false;
      });

    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = 'Debug check failed: ${e.toString()}';
        _debugInfo = 'Stack trace: $stackTrace';
        _isChecking = false;
      });
    }
  }

  Future<void> _testPayment() async {
    setState(() {
      _isChecking = true;
      _errorMessage = '';
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Get first available game
      final gamesQuery = await FirebaseFirestore.instance
          .collection('games')
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (gamesQuery.docs.isEmpty) {
        throw Exception('No pending games available');
      }

      final gameDoc = gamesQuery.docs.first;
      final gameData = gameDoc.data() as Map<String, dynamic>;
      final double entryFee = (gameData['entryFee'] ?? 10.0).toDouble();

      // Test payment with 1 card
      final result = await _firebaseService.purchaseAndSelectCards(
        gameId: gameDoc.id,
        playerId: user.uid,
        numberOfCards: 1,
        cardCost: entryFee,
      );

      setState(() {
        _debugInfo += '''
        
✅ Test Payment Successful!

Cards Generated: ${result.length} cards
First Card Numbers: ${result.first.take(5).join(', ')}...
        ''';
        _isChecking = false;
      });

    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = 'Test payment failed: ${e.toString()}';
        _debugInfo += '''
        
❌ Payment Error Details:
Error Type: ${e.runtimeType.toString()}
Error Message: ${e.toString()}
Stack Trace: $stackTrace
        ''';
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('Payment Debug Tool'),
        backgroundColor: const Color(0xFF1C1C3A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _checkPaymentPrerequisites,
                    child: _isChecking 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Check Prerequisites'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _testPayment,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: _isChecking 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Test Payment'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            if (_debugInfo.isNotEmpty)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _debugInfo,
                      style: const TextStyle(color: Colors.green, fontSize: 12, fontFamily: 'monospace'),
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
