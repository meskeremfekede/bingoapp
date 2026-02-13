import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/screens/player/player_game_board_screen.dart';
import 'package:mygame/services/firebase_service.dart';
import 'dart:developer' as developer;

class SelectUniqueNumbersScreen extends StatefulWidget {
  final String gameId;
  final String playerId;
  final int numberOfFlags;
  final List<List<int>> initialCards;

  const SelectUniqueNumbersScreen({
    super.key,
    required this.gameId,
    required this.playerId,
    required this.numberOfFlags,
    required this.initialCards,
  });

  @override
  State<SelectUniqueNumbersScreen> createState() => _SelectUniqueNumbersScreenState();
}

class _SelectUniqueNumbersScreenState extends State<SelectUniqueNumbersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final Set<int> _selectedFlags = {};
  bool _isConfirming = false;

  Stream<Set<int>> _getTakenFlagsStream() {
    return _firestore.collection('games').doc(widget.gameId).snapshots().map((snapshot) {
      if (!snapshot.exists) return {};
      final gameData = snapshot.data() as Map<String, dynamic>? ?? {};
      final allFlags = gameData['allSelectedFlags'] as List<dynamic>? ?? [];
      return Set<int>.from(allFlags.map((f) => f as int? ?? 0));
    });
  }

  void _toggleFlagSelection(int flagNumber, Set<int> takenFlags) {
    if (takenFlags.contains(flagNumber)) return;

    setState(() {
      if (_selectedFlags.contains(flagNumber)) {
        _selectedFlags.remove(flagNumber);
      } else {
        if (_selectedFlags.length < widget.numberOfFlags) {
          _selectedFlags.add(flagNumber);
        }
      }
    });
  }

  Future<void> _confirmSelection() async {
    if (_selectedFlags.length != widget.numberOfFlags) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select exactly ${widget.numberOfFlags} flag(s).')),
      );
      return;
    }

    setState(() {
      _isConfirming = true;
    });

    try {
      developer.log('Saving flags $_selectedFlags for player ${widget.playerId}');
      await _firebaseService.confirmPlayerFlags(
        gameId: widget.gameId,
        playerId: widget.playerId,
        selectedFlags: _selectedFlags.toList(),
      );
      developer.log('Flags saved successfully.');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerGameBoardScreen(
              gameId: widget.gameId,
              playerId: widget.playerId,
              initialCards: widget.initialCards,
            ),
          ),
        );
      }
    } catch (e) {
      developer.log('Error saving flags: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save flags: ${e.toString()}")),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: Text('Select ${widget.numberOfFlags} Flag(s)'),
        backgroundColor: const Color(0xFF0A0A1A),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'These are your unique identifiers for this game. Choose wisely.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: StreamBuilder<Set<int>>(
              stream: _getTakenFlagsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final takenFlags = snapshot.data!;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 10,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: 200,
                  itemBuilder: (context, index) {
                    final flagNumber = index + 1;
                    final isTaken = takenFlags.contains(flagNumber);
                    final isSelected = _selectedFlags.contains(flagNumber);

                    return GestureDetector(
                      onTap: () => _toggleFlagSelection(flagNumber, takenFlags),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green
                              : isTaken
                                  ? Colors.grey.shade800
                                  : const Color(0xFF1C1C3A),
                          borderRadius: BorderRadius.circular(4),
                          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                        ),
                        child: Center(
                          child: Text(
                            flagNumber.toString(),
                            style: TextStyle(
                              color: isTaken ? Colors.grey.shade600 : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isConfirming || _selectedFlags.length != widget.numberOfFlags
                    ? null
                    : _confirmSelection,
                child: _isConfirming
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirm Flags'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
