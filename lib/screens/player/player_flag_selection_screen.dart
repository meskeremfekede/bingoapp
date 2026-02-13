import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/screens/player/player_game_board_screen.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<int> _selectedFlags = {};
  bool _isConfirming = false;
  bool _hasConfirmedFlags = false;

  Stream<DocumentSnapshot> _getGameStateStream() {
    return _firebaseService.getGameStateStream(widget.gameId);
  }

  void _onNumberTapped(int number) {
    if (number == 0) return; // The center "free" space cannot be a flag.
    setState(() {
      if (_selectedFlags.contains(number)) {
        _selectedFlags.remove(number);
        debugPrint('Removed flag $number. Selected flags: ${_selectedFlags.toList()}');
      } else {
        if (_selectedFlags.length < widget.cards.length) {
          _selectedFlags.add(number);
          debugPrint('Added flag $number. Selected flags: ${_selectedFlags.toList()}');
        } else {
          debugPrint('Cannot add flag $number. Already have ${_selectedFlags.length}/${widget.cards.length} flags');
        }
      }
    });
  }

  Future<void> _confirmFlags() async {
    debugPrint('Confirming flags: ${_selectedFlags.toList()}');
    debugPrint('Required flags: ${widget.cards.length}');
    debugPrint('Selected flags count: ${_selectedFlags.length}');
    
    if (_selectedFlags.length != widget.cards.length) {
      String message = 'Please select exactly ${widget.cards.length} flag numbers (you selected ${_selectedFlags.length})';
      debugPrint('Validation failed: $message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      return;
    }

    debugPrint('Flag validation passed. Proceeding with confirmation...');
    setState(() { 
      _isConfirming = true;
      _hasConfirmedFlags = true;
    });

    try {
      await _firebaseService.confirmPlayerFlags(
        gameId: widget.gameId,
        playerId: widget.playerId,
        selectedFlags: _selectedFlags.toList(),
      );

      debugPrint('Flags confirmed successfully for player ${widget.playerId}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flags confirmed! Waiting for other players...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, s) {
      debugPrint('Error confirming flags: ${e.toString()}');
      debugPrint('Stack trace: $s');
      
      // Reset state on error
      setState(() {
        _hasConfirmedFlags = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to confirm flags: ${e.toString()}")),
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

  void _navigateToGameBoard() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerGameBoardScreen(
            gameId: widget.gameId,
            playerId: widget.playerId,
            initialCards: widget.cards,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _getGameStateStream(),
      builder: (context, gameSnapshot) {
        // Check if game has started and navigate automatically
        if (gameSnapshot.hasData && gameSnapshot.data!.exists) {
          final gameData = gameSnapshot.data!.data() as Map<String, dynamic>;
          final status = gameData['status'] as String? ?? 'pending';
          
          if (status == 'flag_selection_complete' && _hasConfirmedFlags) {
            // All players are ready, navigate to game board
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigateToGameBoard();
            });
          }
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A1A),
          appBar: AppBar(
            title: Text(
              _hasConfirmedFlags ? 'Waiting for Players...' : 'Select Your Flag Numbers',
              style: TextStyle(
                color: _hasConfirmedFlags ? Colors.amber : Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFF0A0A1A),
            automaticallyImplyLeading: false,
          ),
          body: Column(
            children: [
              if (_hasConfirmedFlags)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.green.withOpacity(0.2),
                  child: const Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Your flags are confirmed!',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Waiting for other players to select their flags...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              if (!_hasConfirmedFlags)
                Column(
                  children: [
                    // Status display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Flag Selection Progress',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_selectedFlags.length} / ${widget.cards.length} flags selected',
                            style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (_selectedFlags.length < widget.cards.length)
                            const Text(
                              'Select one flag number for each card/board',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                    
                    // Instructions
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Select your lucky numbers! You paid for ${widget.cards.length} cards, so you play as ${widget.cards.length} players. Select ${widget.cards.length} flag numbers - one for each card/board.',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.cards.length,
                  itemBuilder: (context, index) {
                    return Card(
                      color: const Color(0xFF1C1C3A),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                          ),
                          itemCount: 25,
                          itemBuilder: (context, gridIndex) {
                            final number = widget.cards[index][gridIndex];
                            final bool isSelected = _selectedFlags.contains(number);
                            final bool isDisabled = _hasConfirmedFlags;
                            
                            return GestureDetector(
                              onTap: isDisabled ? null : () => _onNumberTapped(number),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? (_hasConfirmedFlags ? Colors.grey : Colors.amber) 
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isDisabled ? Colors.grey : Colors.white24, 
                                    width: 0.5
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    number == 0 ? 'FREE' : number.toString(),
                                    style: TextStyle(
                                      color: isSelected 
                                          ? (_hasConfirmedFlags ? Colors.white70 : Colors.black) 
                                          : (isDisabled ? Colors.grey : Colors.white),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!_hasConfirmedFlags)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isConfirming ? null : _confirmFlags,
                      child: _isConfirming
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Confirm Flags & Start Game'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
