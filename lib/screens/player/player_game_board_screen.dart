import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/widgets/player_name_widget.dart';

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
  bool _isClaiming = false;
  bool _isWinnerDialogShown = false;

  Stream<DocumentSnapshot> _getGameStream() {
    return FirebaseFirestore.instance.collection('games').doc(widget.gameId).snapshots();
  }

  Stream<DocumentSnapshot> _getPlayerDataStream() {
    return FirebaseFirestore.instance
        .collection('games')
        .doc(widget.gameId)
        .collection('playerData')
        .doc(widget.playerId)
        .snapshots(
          // Add real-time sync options
          includeMetadataChanges: true,
        );
  }

  Future<void> _claimWin() async {
    setState(() {
      _isClaiming = true;
    });

    final bool didWin = await _firebaseService.claimWin(gameId: widget.gameId, playerId: widget.playerId);

    if (mounted) {
      if (!didWin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have a winning pattern yet.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isClaiming = false;
      });
    }
  }

  void _showWinnerDialog(BuildContext context, List<dynamic> winners) {
    if (_isWinnerDialogShown) return;
    setState(() {
      _isWinnerDialogShown = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final winnerIds = winners.map((w) => w['playerId'] as String? ?? '').where((id) => id.isNotEmpty).toList();
          final isWinner = winnerIds.contains(widget.playerId);

          return AlertDialog(
            title: Text(isWinner ? 'Congratulations, You Won!' : 'Game Over!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isWinner ? 'You are one of the winners!' : 'A winner has been found.'),
                const SizedBox(height: 10),
                const Text('Winners:', style: TextStyle(fontWeight: FontWeight.bold)),
                if (winnerIds.isEmpty)
                  const Text('No winners information available.')
                else
                  ...winnerIds.map((id) => PlayerNameWidget(playerId: id)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Go to Main Screen'),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _getGameStream(),
      builder: (context, gameSnapshot) {
        if (gameSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Color(0xFF0A0A1A), body: Center(child: CircularProgressIndicator()));
        }
        if (!gameSnapshot.hasData || gameSnapshot.data?.data() == null) {
          return const Scaffold(backgroundColor: Color(0xFF0A0A1A), body: Center(child: Text('Game not found.', style: TextStyle(color: Colors.white))));
        }

        final gameData = gameSnapshot.data!.data()! as Map<String, dynamic>;
        final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);
        final winningPattern = gameData['winningPattern'] as String? ?? 'N/A'; // Fixed spelling
        final status = gameData['status'] as String? ?? 'pending';
        final competitors = List<String>.from(gameData['players'] ?? []);

        if (status == 'completed') {
          final winners = gameData['winners'] as List<dynamic>? ?? [];
          _showWinnerDialog(context, winners);
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A1A),
          appBar: AppBar(
            title: Text('Game: ${widget.gameId}'),
            backgroundColor: const Color(0xFF0A0A1A),
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [_buildSelectedFlagsWidget()], // Display flags in app bar
          ),
          body: Column(
            children: [
              _buildGameInfoBar(calledNumbers, winningPattern),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView(
                  children: [
                    _buildCardsWidget(calledNumbers),
                    _buildCompetitorsList(competitors),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isClaiming || status == 'completed' ? null : _claimWin,
            label: const Text('Bingo!'),
            icon: const Icon(Icons.celebration),
            backgroundColor: _isClaiming || status == 'completed' ? Colors.grey : Colors.orange,
          ),
        );
      },
    );
  }
  
  // New Widget to display selected flags
  Widget _buildSelectedFlagsWidget() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _getPlayerDataStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final playerData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final flags = List<int>.from(playerData['selectedFlags'] ?? []);
        if (flags.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: flags.map((flag) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(flag.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCardsWidget(List<int> calledNumbers) {
    if (widget.initialCards != null && widget.initialCards!.isNotEmpty) {
      return _buildCardList(widget.initialCards!, calledNumbers);
    }
    
    return StreamBuilder<DocumentSnapshot>(
      stream: _getPlayerDataStream(),
      builder: (context, playerSnapshot) {
        if (playerSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (playerSnapshot.hasError) {
          return Center(child: Text("Error loading cards: ${playerSnapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (!playerSnapshot.hasData || playerSnapshot.data?.data() == null) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Rejoining... Waiting for cards...", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  // Force refresh by clearing cache and reconnecting
                  try {
                    await FirebaseFirestore.instance.clearPersistence();
                    setState(() {});
                  } catch (e) {
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Force Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "If you're stuck, try refreshing or go back and rejoin the game.",
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          );
        }

        final playerData = playerSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final List<dynamic> cardsData = playerData['cards'] as List<dynamic>? ?? [];
        final List<dynamic> selectedFlags = playerData['selectedFlags'] as List<dynamic>? ?? [];
        final String paymentStatus = playerData['paymentStatus'] as String? ?? 'unknown';

        debugPrint('=== GAME BOARD DEBUG ===');
        debugPrint('Player ID: ${widget.playerId}');
        debugPrint('Game ID: ${widget.gameId}');
        debugPrint('Cards data count: ${cardsData.length}');
        debugPrint('Selected flags: ${selectedFlags.toList()}');
        debugPrint('Payment status: $paymentStatus');

        // Check if player has selected flags
        if (selectedFlags.isEmpty) {
          debugPrint('❌ No flags selected - showing flag selection prompt');
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flag, color: Colors.amber, size: 48),
              const SizedBox(height: 16),
              const Text(
                "You need to select your flag numbers first!",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Please go back and select your flag numbers before joining the game.",
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(); // Go back to flag selection
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back to Flag Selection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          );
        }

        if (cardsData.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("You have no cards in this game.", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseFirestore.instance.clearPersistence();
                  setState(() {});
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        }

        final List<List<int>> safeCards = cardsData.map((card) {
          if (card is List) {
            return card.map((num) => (num as int? ?? 0)).toList();
          } else {
            return <int>[];
          }
        }).where((card) => card.isNotEmpty).toList();
        
        return _buildCardList(safeCards, calledNumbers);
      },
    );
  }

  Widget _buildCardList(List<List<int>> cards, List<int> calledNumbers) {
    return Column(
      children: cards.asMap().entries.map((entry) {
        return _buildBingoCard(entry.value, calledNumbers, entry.key + 1);
      }).toList(),
    );
  }

  Widget _buildGameInfoBar(List<int> calledNumbers, String winningPattern) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Winning Pattern:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), // Fixed display
              Chip(label: Text(winningPattern, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.purple.shade300),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Called Numbers', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: calledNumbers.length,
              itemBuilder: (context, index) {
                final number = calledNumbers[calledNumbers.length - 1 - index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.shade800, shape: BoxShape.circle),
                  child: Center(child: Text(number.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBingoCard(List<int> cardNumbers, List<int> calledNumbers, int cardTitleIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Card $cardTitleIndex', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 4, mainAxisSpacing: 4),
            itemCount: 25,
            itemBuilder: (context, index) {
              final number = (index < cardNumbers.length) ? cardNumbers[index] : 0;
              final isCalled = number == 0 || calledNumbers.contains(number);

              return Container(
                decoration: BoxDecoration(
                  color: isCalled ? Colors.amber : const Color(0xFF1C1C3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    number == 0 ? 'FREE' : number.toString(),
                    style: TextStyle(
                      color: isCalled ? Colors.black : Colors.white,
                      fontWeight: isCalled ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitorsList(List<String> competitors) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ExpansionTile(
        title: const Text('Competitors', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        initiallyExpanded: false,
        children: competitors.map((playerId) => Card(
          color: const Color(0xFF1C1C3A),
          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.white70),
            title: PlayerNameWidget(playerId: playerId),
          ),
        )).toList(),
      ),
    );
  }
}
