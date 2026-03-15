import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/screens/player/player_flag_selection_screen.dart';
import 'package:mygame/screens/player/player_game_lobby_screen.dart';
import 'package:mygame/screens/player/player_game_board_screen.dart';

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
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: _getGameStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const Scaffold(body: Center(child: Text("ERROR: Game data corrupted.")));

        // SAFETY CHECK: If player already paid, skip this screen
        if (user != null && data.containsKey('${user.uid}_paymentStatus') && data['${user.uid}_paymentStatus'] == 'paid') {
          final hasFlags = data.containsKey('${user.uid}_selectedFlags') && (data['${user.uid}_selectedFlags'] as List).isNotEmpty;
          final gameStatus = data['status'] as String? ?? 'pending';

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (hasFlags) {
              if (gameStatus == 'ongoing') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => PlayerGameBoardScreen(gameId: widget.gameId, playerId: user.uid)),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => PlayerGameLobbyScreen(gameId: widget.gameId)),
                );
              }
            } else {
              // Paid but no flags? Read cards from DB and go to flag selection
              final List<List<int>> cardsData = [];
              for (int i = 0; i < (data['${user.uid}_cardCount'] ?? 0); i++) {
                final String val = data['${user.uid}_card$i'] ?? '';
                if (val.isNotEmpty) {
                  cardsData.add(val.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList());
                }
              }
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => PlayerFlagSelectionScreen(gameId: widget.gameId, playerId: user.uid, cards: cardsData)),
              );
            }
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

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
