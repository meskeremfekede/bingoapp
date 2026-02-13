import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simple payment test to identify the exact issue
class SimplePaymentTest extends StatefulWidget {
  const SimplePaymentTest({super.key});

  @override
  _SimplePaymentTestState createState() => _SimplePaymentTestState();
}

class _SimplePaymentTestState extends State<SimplePaymentTest> {
  bool _isTesting = false;
  String _result = '';

  Future<void> _runSimpleTest() async {
    setState(() {
      _isTesting = true;
      _result = 'Testing...';
    });

    try {
      // Step 1: Check user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _result = '❌ No user logged in';
          _isTesting = false;
        });
        return;
      }

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

      final playerData = playerSnap.data() as Map<String, dynamic>;
      final dynamic balance = playerData['balance'];

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

      final gameDoc = gamesQuery.docs.first;
      final gameData = gameDoc.data() as Map<String, dynamic>;
      final double entryFee = (gameData['entryFee'] ?? 10.0).toDouble();

      setState(() {
        _result = '''
✅ Basic Checks Passed:

User: ${user.email}
Player ID: ${user.uid}
Balance: $balance ETB
Balance Type: ${balance.runtimeType}
Available Games: ${gamesQuery.docs.length}
Game ID: ${gameDoc.id}
Entry Fee: $entryFee ETB
Game Status: ${gameData['status']}

Can Afford: ${balance is num && balance >= entryFee ? 'YES' : 'NO'}

Next Step: Try actual payment...
        ''';
      });

    } catch (e, stackTrace) {
      setState(() {
        _result = '''
❌ Test Failed:

Error: ${e.toString()}
Type: ${e.runtimeType.toString()}
Stack: $stackTrace
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
        title: const Text('Simple Payment Test'),
        backgroundColor: const Color(0xFF1C1C3A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isTesting ? null : _runSimpleTest,
              child: _isTesting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Run Simple Test'),
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
                    _result.isEmpty ? 'Press "Run Simple Test" to check payment prerequisites' : _result,
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
