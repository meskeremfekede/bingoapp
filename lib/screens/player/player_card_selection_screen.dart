import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/screens/player/player_identity_selection_screen.dart';
import 'dart:developer' as developer;

class CardSelectionScreen extends StatefulWidget {
  final String gameId;

  const CardSelectionScreen({super.key, required this.gameId});

  @override
  State<CardSelectionScreen> createState() => _CardSelectionScreenState();
}

class _CardSelectionScreenState extends State<CardSelectionScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int? _selectedNumberOfCards;
  bool _isConfirming = false;

  Stream<DocumentSnapshot> _getGameStream() {
    return _firestore.collection('games').doc(widget.gameId).snapshots();
  }

  Future<void> _confirmSelection(double cardCost) async {
    final user = _auth.currentUser;
    if (user == null) {
      developer.log('Error: User is not logged in.');
      return;
    }

    if (_selectedNumberOfCards == null || _selectedNumberOfCards == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the number of cards you want to buy.')),
      );
      return;
    }

    setState(() {
      _isConfirming = true;
    });

    try {
      // Show progress indicator with retry information
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(width: 16),
                Text('Processing payment...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );
      }

      final List<List<int>> generatedCards = await _firebaseService.purchaseAndSelectCards(
        gameId: widget.gameId,
        playerId: user.uid,
        numberOfCards: _selectedNumberOfCards!,
        cardCost: cardCost,
      );

      developer.log('Cards purchased and created successfully.');
      developer.log('Generated cards count: ${generatedCards.length}');

      // Clear any existing snackbars
      ScaffoldMessenger.of(context).clearSnackBars();

      if (mounted) {
        // Show prominent success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '✅ Payment Successful! ${_selectedNumberOfCards} card(s) purchased for ${(cardCost * _selectedNumberOfCards!).toStringAsFixed(2)} ETB',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Add a delay to ensure the success message is visible
        await Future.delayed(const Duration(milliseconds: 1500));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerIdentitySelectionScreen(
              gameId: widget.gameId,
              playerId: user.uid,
              cards: generatedCards,
              totalPaid: cardCost * _selectedNumberOfCards!,
            ),
          ),
        );
      }
    } catch (e, s) {
      developer.log('An error occurred during card purchase: ${e.toString()}', stackTrace: s);
      developer.log('Error type: ${e.runtimeType}');
      
      // Clear any existing snackbars
      ScaffoldMessenger.of(context).clearSnackBars();
      
      if (mounted) {
        // Simple, clear error messages - no technical jargon
        String errorMessage = e.toString();
        
        // Debug: Log the full error for troubleshooting
        developer.log('Full error message: $errorMessage');
        
        if (errorMessage.contains('Insufficient balance')) {
          errorMessage = '❌ Not enough money in your wallet. Please add funds first.';
        } else if (errorMessage.contains('already purchased')) {
          errorMessage = '❌ You already bought cards for this game.';
        } else if (errorMessage.contains('Permission denied')) {
          errorMessage = '❌ Account access denied. Please check your login.';
        } else if (errorMessage.contains('timed out') || errorMessage.contains('deadline-exceeded')) {
          errorMessage = '❌ Connection timeout. Please check internet and try again.';
        } else if (errorMessage.contains('not-found') || errorMessage.contains('Player not found')) {
          errorMessage = '❌ Account not found. Please login again.';
        } else if (errorMessage.contains('resource-exhausted')) {
          errorMessage = '❌ Server busy. Please wait and try again.';
        } else if (errorMessage.contains('Game is not') || errorMessage.contains('pending')) {
          errorMessage = '✅ Payment successful! You can join even if game started.';
        } else if (errorMessage.contains('Future') || errorMessage.contains('converted Future')) {
          errorMessage = '❌ Payment processing error. Please try again.';
        } else if (errorMessage.contains('Type error') || errorMessage.contains('TypeError')) {
          errorMessage = '❌ Data format error. Please check your account data or contact support.';
        } else if (errorMessage.contains('Data error')) {
          errorMessage = '❌ Account data issue. Please try refreshing or contact support.';
        } else {
          // Extract the actual error message, not the technical details
          if (errorMessage.contains(':')) {
            errorMessage = '❌ ${errorMessage.split(':').last.trim()}';
          } else {
            errorMessage = '❌ Payment failed. Please try again.';
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                // Retry the payment
                _confirmSelection(cardCost);
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _getGameStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          developer.log("Error in game stream: ${snapshot.error}");
          return Scaffold(
            backgroundColor: const Color(0xFF0A0A1A),
            appBar: AppBar(title: const Text("Error")),
            body: Center(
              child: Text(
                'An error occurred loading the game: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A1A),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final gameData = snapshot.data!.data()! as Map<String, dynamic>;
        final maxCards = gameData['maxCards'] as int? ?? 1;
        final cardCost = (gameData['cardCost'] as num?)?.toDouble() ?? 0.0;

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A1A),
          appBar: AppBar(
            title: const Text('Select Your Cards'),
            backgroundColor: const Color(0xFF0A0A1A),
            elevation: 0,
            automaticallyImplyLeading: false,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Each card costs ${cardCost.toStringAsFixed(2)} ETB.',
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                DropdownButtonFormField<int>(
                  value: _selectedNumberOfCards,
                  hint: const Text('Select number of cards', style: TextStyle(color: Colors.white70)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1C1C3A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  dropdownColor: const Color(0xFF1C1C3A),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  items: List.generate(maxCards, (index) => index + 1).map((number) {
                    return DropdownMenuItem<int>(
                      value: number,
                      child: Text('$number Card(s)'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedNumberOfCards = value;
                    });
                  },
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isConfirming ? null : () => _confirmSelection(cardCost),
                    child: _isConfirming ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm & Pay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
