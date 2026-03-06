import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/screens/player/player_flag_selection_screen.dart';

class CardSelectionScreen extends StatefulWidget {
  final String gameId;
  const CardSelectionScreen({super.key, required this.gameId});

  @override
  State<CardSelectionScreen> createState() => _CardSelectionScreenState();
}

class _CardSelectionScreenState extends State<CardSelectionScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedCount = 1;
  bool _isProcessing = false;

  Stream<DocumentSnapshot> _getGameStream() => 
      FirebaseFirestore.instance.collection('games').doc(widget.gameId).snapshots();

  // SAFE PARSING: Handles integer or double from database
  double _parseSafeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  Future<void> _handlePayment(double cardCost) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() { _isProcessing = true; });

    try {
      final cards = await _firebaseService.purchaseAndSelectCards(
        gameId: widget.gameId,
        playerId: user.uid,
        numberOfCards: _selectedCount,
        cardCost: cardCost,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerFlagSelectionScreen(
              gameId: widget.gameId,
              playerId: user.uid,
              cards: cards,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _getGameStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const Scaffold(body: Center(child: Text("ERROR: Game data corrupted.")));

        // CRITICAL FIX: Safe parse the cardCost
        final cardCost = _parseSafeDouble(data['cardCost']);
        final maxCards = (data['maxCards'] as int? ?? 1);

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A1A),
          appBar: AppBar(title: const Text('PURCHASE CARDS'), backgroundColor: Colors.transparent),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${cardCost.toStringAsFixed(2)} ETB per card',
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 32),
                DropdownButtonFormField<int>(
                  value: _selectedCount,
                  dropdownColor: const Color(0xFF1C1C3A),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: const InputDecoration(
                    labelText: 'How many cards?',
                    labelStyle: TextStyle(color: Colors.purpleAccent),
                    filled: true,
                    fillColor: Color(0xFF1C1C3A),
                  ),
                  items: List.generate(maxCards, (i) => i + 1)
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n Card(s)')))
                      .toList(),
                  onChanged: (val) => setState(() { _selectedCount = val!; }),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _handlePayment(cardCost),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: _isProcessing 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text('PAY & JOIN - ${(_selectedCount * cardCost).toStringAsFixed(2)} ETB'),
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
