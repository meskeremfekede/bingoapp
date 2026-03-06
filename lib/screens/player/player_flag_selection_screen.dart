import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/screens/player/player_game_lobby_screen.dart';
import 'dart:developer' as developer;

class PlayerFlagSelectionScreen extends StatefulWidget {
  final String gameId;
  final String playerId;
  final List<List<int>> cards;

  const PlayerFlagSelectionScreen({
    super.key,
    required this.gameId,
    required this.playerId,
    required this.cards,
  });

  @override
  _PlayerFlagSelectionScreenState createState() => _PlayerFlagSelectionScreenState();
}

class _PlayerFlagSelectionScreenState extends State<PlayerFlagSelectionScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final Set<int> _selectedFlags = {};
  bool _isConfirming = false;

  void _onNumberTapped(int number) {
    if (number == 0) return;
    setState(() {
      if (_selectedFlags.contains(number)) {
        _selectedFlags.remove(number);
      } else {
        if (_selectedFlags.length < widget.cards.length) {
          _selectedFlags.add(number);
        }
      }
    });
  }

  Future<void> _confirmFlags() async {
    if (_selectedFlags.length != widget.cards.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select ${widget.cards.length} flag(s) to continue.')),
      );
      return;
    }

    setState(() { _isConfirming = true; });

    try {
      await _firebaseService.confirmPlayerFlags(
        gameId: widget.gameId,
        playerId: widget.playerId,
        selectedFlags: _selectedFlags.toList(),
      );

      if (mounted) {
        // JOURNEY STEP: Move to Waiting Room (Lobby) after flags are set
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerGameLobbyScreen(gameId: widget.gameId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() { _isConfirming = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(title: const Text('CHOOSE YOUR IDENTITY'), backgroundColor: Colors.transparent),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Select ${_selectedFlags.length}/${widget.cards.length} numbers as your game identity.',
              style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.cards.length,
              itemBuilder: (context, index) {
                return Card(
                  color: const Color(0xFF1C1C3A),
                  margin: const EdgeInsets.all(12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
                    itemCount: 25,
                    itemBuilder: (context, gridIndex) {
                      final number = widget.cards[index][gridIndex];
                      final isSelected = _selectedFlags.contains(number);
                      return GestureDetector(
                        onTap: () => _onNumberTapped(number),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.purpleAccent : Colors.transparent,
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Center(
                            child: Text(
                              number == 0 ? 'FREE' : number.toString(),
                              style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isConfirming ? null : _confirmFlags,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: _isConfirming ? const CircularProgressIndicator() : const Text('CONFIRM & JOIN WAITING ROOM'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
