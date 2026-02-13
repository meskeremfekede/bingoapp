import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/screens/player/player_card_selection_screen.dart';
import 'dart:developer' as developer;

class PlayerGameLobbyScreen extends StatefulWidget {
  final String gameId;

  const PlayerGameLobbyScreen({super.key, required this.gameId});

  @override
  State<PlayerGameLobbyScreen> createState() => _PlayerGameLobbyScreenState();
}

class _PlayerGameLobbyScreenState extends State<PlayerGameLobbyScreen> {

  Stream<DocumentSnapshot> _getGameStream() {
    return FirebaseFirestore.instance.collection('games').doc(widget.gameId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _getGameStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final gameData = snapshot.data!.data()! as Map<String, dynamic>;
          final status = gameData['status'] as String? ?? 'pending';
          
          developer.log('=== GAME LOBBY DEBUG ===');
          developer.log('Game ID: ${widget.gameId}');
          developer.log('Game Status: $status');

          // If game is ongoing, navigate to card selection
          if (status == 'ongoing') {
            developer.log('✅ Game is ongoing - navigating to card selection');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => CardSelectionScreen(gameId: widget.gameId)),
                (Route<dynamic> route) => false,
              );
            });
          } else {
            developer.log('⏳ Game is not ongoing yet - staying in lobby (status: $status)');
          }
        }

        // Build the lobby UI while waiting
        return Scaffold(
          backgroundColor: const Color(0xFF0A0A1A),
          appBar: AppBar(
            title: const Text('Game Lobby'),
            backgroundColor: const Color(0xFF0A0A1A),
            elevation: 0,
            automaticallyImplyLeading: false,
          ),
          body: _buildLobbyContent(context, snapshot),
        );
      },
    );
  }

  Widget _buildLobbyContent(BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!snapshot.hasData || !snapshot.data!.exists) {
      return const Center(child: Text('Game not found or has been cancelled.', style: TextStyle(color: Colors.white)));
    }

    final gameData = snapshot.data!.data()! as Map<String, dynamic>;
    final playersJoined = List<String>.from(gameData['players'] ?? []);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Text('Waiting for admin to start the game...', style: TextStyle(color: Colors.amber, fontSize: 16)),
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    developer.log('🔄 Manual refresh triggered by user');
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check if Game Started'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Game Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white24, height: 20),
          _buildInfoRow('Winning Pattern:', gameData['winningPattern'] ?? 'N/A'), // Fixed spelling
          _buildInfoRow('Card Cost:', '${(gameData['cardCost'] as num?)?.toDouble() ?? 0.0} Birr'),
          const SizedBox(height: 24),
          const Text('Joined Players', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white24, height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: playersJoined.length,
              itemBuilder: (context, index) {
                return Card(
                  color: const Color(0xFF1C1C3A),
                  child: ListTile(
                    leading: const Icon(Icons.person, color: Colors.white70),
                    title: Text(playersJoined[index], style: const TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
