import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/screens/player/player_game_lobby_screen.dart';

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

  void _onFlagSelected(int number) {
    setState(() {
      if (_selectedFlags.contains(number)) {
        _selectedFlags.remove(number);
      } else {
        if (_selectedFlags.length < widget.cards.length) {
          _selectedFlags.add(number);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You can only select ${widget.cards.length} flag(s).')),
          );
        }
      }
    });
  }

  Future<void> _confirmFlags() async {
    if (_selectedFlags.length != widget.cards.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select exactly ${widget.cards.length} flag(s).')),
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PlayerGameLobbyScreen(gameId: widget.gameId)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() { _isConfirming = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('CHOOSE YOUR IDENTITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Select ${_selectedFlags.length}/${widget.cards.length} identities from 1 to 300.',
              style: const TextStyle(color: Colors.amber, fontSize: 16),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6, // 6 items per row for 300 items
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 300,
              itemBuilder: (context, index) {
                final number = index + 1;
                final isSelected = _selectedFlags.contains(number);
                return GestureDetector(
                  onTap: () => _onFlagSelected(number),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.purpleAccent : const Color(0xFF1C1C3A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? Colors.white : Colors.white10),
                    ),
                    child: Center(
                      child: Text(
                        '$number',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isConfirming ? const CircularProgressIndicator(color: Colors.white) : const Text('JOIN WAITING ROOM', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
