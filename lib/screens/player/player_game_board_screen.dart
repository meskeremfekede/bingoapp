import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/widgets/player_name_widget.dart';
import 'package:audioplayers/audioplayers.dart';

class PlayerGameBoardScreen extends StatefulWidget {
  final String gameId;
  final String playerId;
  final List<List<int>>? initialCards;

  const PlayerGameBoardScreen({
    super.key,
    required this.gameId,
    required this.playerId,
    this.initialCards,
  });

  @override
  State<PlayerGameBoardScreen> createState() => _PlayerGameBoardScreenState();
}

class _PlayerGameBoardScreenState extends State<PlayerGameBoardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final Set<int> _markedNumbers = {0}; 
  final Map<int, Timer> _activeTimers = {}; 
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _lastCalledCount = 0;

  @override
  void dispose() {
    for (var timer in _activeTimers.values) { timer.cancel(); }
    _audioPlayer.dispose();
    super.dispose();
  }

  Stream<DocumentSnapshot> _getGameStream() {
    return FirebaseFirestore.instance.collection('games').doc(widget.gameId).snapshots();
  }

  void _onSquareTapped(int number) {
    if (number == 0 || _markedNumbers.contains(number)) return;
    
    setState(() {
      _markedNumbers.add(number);
      if (_activeTimers.containsKey(number)) {
        _activeTimers[number]?.cancel();
        _activeTimers.remove(number);
      }
    });
  }

  void _playNumberCalledSound() async {
    try { await _audioPlayer.play(AssetSource('sounds/number_called.mp3')); } catch (e) {}
  }

  void _playWinnerSound() async {
    try { await _audioPlayer.play(AssetSource('sounds/winner_announced.mp3')); } catch (e) {}
  }

  void _handleIncomingNumbers(List<int> calledNumbers) {
    if (calledNumbers.length > _lastCalledCount) {
      _lastCalledCount = calledNumbers.length;
      _playNumberCalledSound();
    }

    for (final n in calledNumbers) {
      if (!_markedNumbers.contains(n) && !_activeTimers.containsKey(n)) {
        _activeTimers[n] = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _markedNumbers.add(n);
              _activeTimers.remove(n);
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _getGameStream(),
      builder: (context, gameSnapshot) {
        if (!gameSnapshot.hasData || gameSnapshot.data?.data() == null) {
          return const Scaffold(backgroundColor: Color(0xFF0A0A1A), body: Center(child: CircularProgressIndicator()));
        }

        final gameData = gameSnapshot.data!.data()! as Map<String, dynamic>;
        final calledNumbers = (gameData['calledNumbers'] as List<dynamic>? ?? [])
            .map((e) => (e as num).toInt())
            .toList();
            
        final winningPattern = gameData['winningPattern'] as String? ?? 'Any Line';
        final status = gameData['status'] as String? ?? 'ongoing';
        final winners = List<dynamic>.from(gameData['winners'] ?? []);

        _handleIncomingNumbers(calledNumbers);

        if (status == 'completed' && winners.isNotEmpty) {
          final winner = winners.first as Map<String, dynamic>;
          final winnerNickname = winner['nickname'] ?? '??';
          final winnerId = winner['playerId'] ?? '';
          final isYou = winnerId == widget.playerId;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _playWinnerSound();
            _showWinnerVibe(context, winnerNickname, winnerId, isYou);
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A1A),
          appBar: AppBar(
            title: const Text('BINGO MATCH', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            backgroundColor: const Color(0xFF0A0A1A),
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [_buildSelectedFlagsWidget(gameData)],
          ),
          body: Column(
            children: [
              _buildGameInfoBar(calledNumbers, winningPattern),
              const Divider(color: Colors.white10),
              Expanded(
                child: ListView(
                  children: [
                    _buildCardsWidget(gameData, calledNumbers),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text('COMPETITORS', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ),
                    _buildCompetitorsGrid(List<String>.from(gameData['players'] ?? [])),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWinnerVibe(BuildContext context, String nickname, String id, bool isYou) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C3A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        title: Text(isYou ? '🏆 YOU WON! 🏆' : '🔥 BINGO! 🔥', textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 80),
            const SizedBox(height: 24),
            const Text('Match Winner:', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            PlayerNameWidget(playerId: id, textStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), 
            const SizedBox(height: 16),
            const Text('Game Identity:', style: TextStyle(color: Colors.white38, fontSize: 12)),
            Text('FLAG #$nickname', style: const TextStyle(color: Colors.greenAccent, fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Text(isYou ? 'Prizes have been added to your balance.' : 'Better luck next time!', 
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white24, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('BACK TO MENU', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFlagsWidget(Map<String, dynamic> gameData) {
    final flags = (gameData['${widget.playerId}_selectedFlags'] as List<dynamic>? ?? [])
        .map((e) => (e as num).toInt())
        .toList();
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: flags.map((flag) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
          child: Text('$flag', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        )).toList(),
      ),
    );
  }

  Widget _buildCardsWidget(Map<String, dynamic> gameData, List<int> calledNumbers) {
    final List<List<int>> cardsData = [];
    final playerPrefix = '${widget.playerId}_card';
    final cardKeys = gameData.keys.where((k) => k.startsWith(playerPrefix) && !k.contains('Count')).toList();
    cardKeys.sort();

    for (final key in cardKeys) {
      final val = gameData[key] ?? '';
      if (val is String && val.isNotEmpty) {
        final List<int> card = val.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
        if (card.length == 25) cardsData.add(card);
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cardsData.asMap().entries.map((entry) => Container(
          width: 220,
          margin: const EdgeInsets.all(12),
          child: _buildBingoCard(entry.value, calledNumbers, entry.key + 1),
        )).toList(),
      ),
    );
  }

  Widget _buildGameInfoBar(List<int> calledNumbers, String winningPattern) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('PATTERN:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
                child: Text(winningPattern, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: calledNumbers.length,
              itemBuilder: (context, index) {
                final number = calledNumbers[calledNumbers.length - 1 - index];
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 40,
                  decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                  child: Center(child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBingoCard(List<int> cardNumbers, List<int> calledNumbers, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BOARD #$index', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, childAspectRatio: 1.0, crossAxisSpacing: 4, mainAxisSpacing: 4),
            itemCount: 25,
            itemBuilder: (context, i) {
              final n = cardNumbers[i];
              final isCalled = calledNumbers.contains(n) || n == 0;
              final isMarked = _markedNumbers.contains(n);
              final isGlow = isCalled && !isMarked;

              return GestureDetector(
                onTap: isCalled ? () => _onSquareTapped(n) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isMarked ? Colors.greenAccent : (isGlow ? Colors.white.withOpacity(0.2) : const Color(0xFF1C1C3A)),
                    borderRadius: BorderRadius.circular(6),
                    border: isGlow ? Border.all(color: Colors.white, width: 2) : null,
                    boxShadow: isGlow ? [
                      BoxShadow(color: Colors.purpleAccent.withOpacity(0.8), blurRadius: 12, spreadRadius: 2),
                      const BoxShadow(color: Colors.white, blurRadius: 4),
                    ] : null,
                  ),
                  child: Center(
                    child: Text(
                      n == 0 ? 'FREE' : '$n',
                      style: TextStyle(
                        color: isMarked ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompetitorsGrid(List<String> competitors) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, 
        childAspectRatio: 3.5, 
        crossAxisSpacing: 12, 
        mainAxisSpacing: 12
      ),
      itemCount: competitors.length,
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C3A), 
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.05))
        ),
        child: Center(
          child: PlayerNameWidget(
            playerId: competitors[index], 
            textStyle: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)
          )
        ),
      ),
    );
  }
}
