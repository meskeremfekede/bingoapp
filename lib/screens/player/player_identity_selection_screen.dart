import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/screens/player/player_flag_selection_screen.dart';
import 'dart:developer' as developer;

class PlayerIdentitySelectionScreen extends StatefulWidget {
  final String gameId;
  final String playerId;
  final List<List<int>> cards;
  final double totalPaid;

  const PlayerIdentitySelectionScreen({
    super.key,
    required this.gameId,
    required this.playerId,
    required this.cards,
    required this.totalPaid,
  });

  @override
  _PlayerIdentitySelectionScreenState createState() => _PlayerIdentitySelectionScreenState();
}

class _PlayerIdentitySelectionScreenState extends State<PlayerIdentitySelectionScreen> {
  final Set<int> _selectedNumbers = {};
  bool _isConfirming = false;
  bool _hasConfirmedNumbers = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: Text('Choose Your Identity Numbers (${widget.cards.length} cards)'),
        backgroundColor: const Color(0xFF0A0A1A),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Payment Summary
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C3A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.payment, color: Colors.green, size: 24),
                    const SizedBox(width: 8),
                    const Text('Payment Summary', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cards Purchased:', style: TextStyle(color: Colors.white70)),
                    Text('${widget.cards.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Paid:', style: TextStyle(color: Colors.white70)),
                    Text('${widget.totalPaid.toStringAsFixed(2)} ETB', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          
          // Instructions
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('Choose Your Identity Numbers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select ${widget.cards.length} unique numbers (1-75) that will be your identity for this game.',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (widget.cards.length > 1)
                  Text(
                    'Each card needs its own identity number.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Number Selection Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: 75,
                itemBuilder: (context, index) {
                  final number = index + 1;
                  final isSelected = _selectedNumbers.contains(number);
                  final isConfirmed = _hasConfirmedNumbers;
                  
                  return GestureDetector(
                    onTap: isConfirmed ? null : () {
                      setState(() {
                        if (isSelected) {
                          _selectedNumbers.remove(number);
                        } else if (_selectedNumbers.length < widget.cards.length) {
                          _selectedNumbers.add(number);
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? (isConfirmed ? Colors.green : Colors.blue)
                            : const Color(0xFF1C1C3A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? (isConfirmed ? Colors.green : Colors.blue) : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          number.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Bottom Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Selection Status
                Row(
                  children: [
                    Icon(
                      _selectedNumbers.length == widget.cards.length 
                          ? Icons.check_circle 
                          : Icons.circle,
                      color: _selectedNumbers.length == widget.cards.length 
                          ? Colors.green 
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Selected: ${_selectedNumbers.length}/${widget.cards.length} identity numbers',
                      style: TextStyle(
                        color: _selectedNumbers.length == widget.cards.length 
                            ? Colors.green 
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_selectedNumbers.length != widget.cards.length || _isConfirming || _hasConfirmedNumbers) 
                        ? null 
                        : _confirmIdentityNumbers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isConfirming 
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Saving...'),
                            ],
                          )
                        : _hasConfirmedNumbers 
                            ? const Text('✅ Identity Confirmed')
                            : const Text('Confirm Identity Numbers'),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Waiting Message
                if (_hasConfirmedNumbers)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Waiting for admin to start the game...',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmIdentityNumbers() async {
    setState(() {
      _isConfirming = true;
    });

    try {
      developer.log('Confirming identity numbers: ${_selectedNumbers.toList()}');
      
      // Save identity numbers to player data
      await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .collection('playerData')
          .doc(widget.playerId)
          .update({
            'identityNumbers': _selectedNumbers.toList(),
            'identityConfirmed': true,
            'identityConfirmedAt': FieldValue.serverTimestamp(),
          });

      developer.log('Identity numbers saved successfully');

      if (mounted) {
        setState(() {
          _hasConfirmedNumbers = true;
          _isConfirming = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✅ Identity numbers confirmed! Redirecting to waiting room...'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate to waiting screen after a short delay
        await Future.delayed(const Duration(milliseconds: 2000));
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerFlagSelectionScreen(
                gameId: widget.gameId,
                playerId: widget.playerId,
                cards: widget.cards,
              ),
            ),
          );
        }
      }
    } catch (e) {
      developer.log('Error confirming identity numbers: $e');
      
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving identity numbers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
