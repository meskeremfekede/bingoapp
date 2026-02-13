import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DebugGameBoardSyncScreen extends StatefulWidget {
  final String gameId;
  final String playerId;

  const DebugGameBoardSyncScreen({
    super.key,
    required this.gameId,
    required this.playerId,
  });

  @override
  State<DebugGameBoardSyncScreen> createState() => _DebugGameBoardSyncScreenState();
}

class _DebugGameBoardSyncScreenState extends State<DebugGameBoardSyncScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _gameData;
  Map<String, dynamic>? _playerData;
  String _status = 'Checking...';

  @override
  void initState() {
    super.initState();
    _checkGameStatus();
  }

  Future<void> _checkGameStatus() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking game existence...';
    });

    try {
      // Check if game exists
      final gameRef = FirebaseFirestore.instance.collection('games').doc(widget.gameId);
      final gameSnap = await gameRef.get();
      
      if (!gameSnap.exists) {
        setState(() {
          _status = '❌ Game does not exist!';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _gameData = gameSnap.data();
        _status = '✅ Game exists. Checking player data...';
      });

      // Check if player data exists
      final playerDataRef = gameRef.collection('playerData').doc(widget.playerId);
      final playerDataSnap = await playerDataRef.get();
      
      if (!playerDataSnap.exists) {
        setState(() {
          _status = '❌ Player data not found! Cards not purchased?';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _playerData = playerDataSnap.data();
        _status = '✅ Player data found. Analyzing...';
      });

      // Check if cards exist
      final cardsData = _playerData!['cards'] as List<dynamic>? ?? [];
      final paymentStatus = _playerData!['paymentStatus'] as String? ?? 'unknown';

      setState(() {
        _isLoading = false;
        if (cardsData.isEmpty) {
          _status = '❌ No cards found! Payment may have failed.';
        } else {
          _status = '✅ Cards found! Game board should work.';
        }
      });

    } catch (e) {
      setState(() {
        _status = '❌ Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _forceRefresh() async {
    await _checkGameStatus();
  }

  Future<void> _clearCacheAndRetry() async {
    try {
      await FirebaseFirestore.instance.clearPersistence();
      await _checkGameStatus();
    } catch (e) {
      setState(() {
        _status = '❌ Cache clear failed: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('Game Board Debug', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1C1C3A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: const Color(0xFF1C1C3A),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (_isLoading) 
                          const CircularProgressIndicator(color: Colors.white)
                        else if (_status.startsWith('✅'))
                          const Icon(Icons.check_circle, color: Colors.green)
                        else
                          const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _status,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Game Info
            if (_gameData != null) ...[
              _buildInfoCard('Game Info', {
                'Game ID': widget.gameId,
                'Game Name': _gameData!['gameName'] ?? 'N/A',
                'Status': _gameData!['status'] ?? 'N/A',
                'Players': '${(_gameData!['players'] as List?)?.length ?? 0} players',
              }),
              const SizedBox(height: 16),
            ],

            // Player Info
            if (_playerData != null) ...[
              _buildInfoCard('Player Info', {
                'Player ID': widget.playerId,
                'Payment Status': _playerData!['paymentStatus'] ?? 'N/A',
                'Cards Count': '${(_playerData!['cards'] as List?)?.length ?? 0} cards',
                'Has Cards': ((_playerData!['cards'] as List?)?.isNotEmpty ?? false) ? 'Yes' : 'No',
              }),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _forceRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearCacheAndRetry,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Clear Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Recommendations
            Card(
              color: const Color(0xFF1C1C3A),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔧 Troubleshooting Steps:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStep('1. Check if you purchased cards'),
                    _buildStep('2. Verify payment was successful'),
                    _buildStep('3. Try clearing cache and refreshing'),
                    _buildStep('4. Go back and rejoin the game'),
                    _buildStep('5. Check internet connection'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, Map<String, String> data) {
    return Card(
      color: const Color(0xFF1C1C3A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...data.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      '${entry.key}:',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String step) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(
        step,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }
}
