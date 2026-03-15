import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/config/game_config.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- App Configuration ---
  Stream<String> getRegistrationCodeStream() {
    return _firestore.collection('config').doc('app_settings').snapshots().map((doc) {
      if (doc.exists && doc.data()!.containsKey('registrationCode')) {
        return doc.data()!['registrationCode'] as String;
      }
      return 'NOT SET';
    });
  }

  Future<void> updateRegistrationCode(String newCode) async {
    try {
      await _firestore.collection('config').doc('app_settings').set({
        'registrationCode': newCode,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating registration code: $e');
      throw Exception('Failed to update registration code.');
    }
  }

  // --- Player Management ---
  Future<void> createPlayerDocument(String uid, String name, String email, String phoneNumber, double initialBalance) async {
    try {
      await _firestore.collection('players').doc(uid).set({
        'name': name,
        'email': email,
        'phoneNumber': phoneNumber,
        'balance': initialBalance,
        'joinDate': FieldValue.serverTimestamp(),
        'role': 'player',
      });
    } catch (e) {
      debugPrint('Error creating player document: $e');
      throw Exception('Failed to create player profile.');
    }
  }

  Future<void> deletePlayer(String playerId) async {
    try {
      await _firestore.collection('players').doc(playerId).delete();
    } catch (e) {
      debugPrint('Error deleting player: $e');
      throw Exception('Failed to delete player.');
    }
  }

  Future<void> addCashToPlayer({required String playerId, required double amount, required String reason, String type = 'manual_add'}) async {
    final playerRef = _firestore.collection('players').doc(playerId);
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(playerRef);
      if (!snap.exists) return;
      final current = _parseSafeDouble((snap.data() as Map<String, dynamic>?)?['balance']);
      transaction.update(playerRef, {'balance': current + amount});
      transaction.set(playerRef.collection('transactions').doc(), {
        'amount': amount, 'type': type, 'reason': reason, 'date': DateTime.now(),
      });
    });
  }

  Future<void> deductCashFromPlayer({required String playerId, required double amount, required String reason, String type = 'manual_deduct'}) async {
    final playerRef = _firestore.collection('players').doc(playerId);
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(playerRef);
      if (!snap.exists) return;
      final current = _parseSafeDouble((snap.data() as Map<String, dynamic>?)?['balance']);
      transaction.update(playerRef, {'balance': current - amount});
      transaction.set(playerRef.collection('transactions').doc(), {
        'amount': -amount, 'type': type, 'reason': reason, 'date': DateTime.now(),
      });
    });
  }

  // --- Game Management ---
  Future<void> startGame(String gameId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      await gameRef.update({'status': 'ongoing'});
    } catch (e) {
      throw Exception('Failed to start game.');
    }
  }

  Future<void> joinGameLobby({required String gameId, required String playerId}) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    try {
      await gameRef.update({
        'players': FieldValue.arrayUnion([playerId])
      });
    } catch (e) {
      throw Exception('Failed to join game lobby.');
    }
  }

  List<int> _generateRandomCard(Random random) {
    final List<int> grid = List.filled(25, 0);
    final Set<int> used = {};
    for (int col = 0; col < 5; col++) {
      for (int row = 0; row < 5; row++) {
        if (col == 2 && row == 2) continue;
        int n;
        do { n = random.nextInt(15) + 1 + (col * 15); } while (used.contains(n));
        used.add(n);
        grid[row * 5 + col] = n;
      }
    }
    grid[12] = 0;
    return grid;
  }

  double _parseSafeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<List<List<int>>> purchaseAndSelectCards({
    required String gameId,
    required String playerId,
    required int numberOfCards,
    required double cardCost,
  }) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    final playerRef = _firestore.collection('players').doc(playerId);
    try {
      return await _firestore.runTransaction((transaction) async {
        final playerSnap = await transaction.get(playerRef);
        final double currentBalance = _parseSafeDouble((playerSnap.data() as Map<String, dynamic>?)?['balance']);
        if (currentBalance < (cardCost * numberOfCards)) throw Exception('Insufficient balance.');

        final List<List<int>> generatedCards = List.generate(numberOfCards, (_) => _generateRandomCard(Random()));

        transaction.update(playerRef, {'balance': currentBalance - (cardCost * numberOfCards)});
        transaction.set(playerRef.collection('transactions').doc(), {
          'amount': -(cardCost * numberOfCards), 'type': 'game_fee', 'reason': 'Match entry', 'date': DateTime.now(),
        });

        Map<String, dynamic> cardData = {};
        for (int i = 0; i < generatedCards.length; i++) {
          cardData['${playerId}_card$i'] = generatedCards[i].join(',');
        }
        cardData['${playerId}_cardCount'] = numberOfCards;
        cardData['${playerId}_paymentStatus'] = 'paid';

        transaction.update(gameRef, cardData);
        transaction.update(gameRef, {
          'totalCardsSold': FieldValue.increment(numberOfCards),
          'players': FieldValue.arrayUnion([playerId])
        });

        return generatedCards;
      }, timeout: const Duration(seconds: 25));
    } catch (e) {
      throw Exception(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> confirmPlayerFlags({
    required String gameId,
    required String playerId,
    required List<int> selectedFlags,
  }) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    try {
      await gameRef.update({
        'allSelectedFlags': FieldValue.arrayUnion(selectedFlags),
        '${playerId}_selectedFlags': selectedFlags,
      });
    } catch (e) {
      throw Exception('Failed to save flags.');
    }
  }

  bool _checkWinner(List<int> card, List<int> calledNumbers, String pattern) {
    if (card.length != 25) return false;
    final grid = List.generate(5, (i) => card.sublist(i * 5, (i + 1) * 5));
    final Set<int> active = {...calledNumbers, 0};
    final p = pattern.toLowerCase();

    if (p == 'horizontal' || p == 'any line' || p == 'any_line') {
      for (int i = 0; i < 5; i++) { if (grid[i].every((n) => active.contains(n))) return true; }
    }
    if (p == 'vertical' || p == 'any line' || p == 'any_line') {
      for (int i = 0; i < 5; i++) {
        if ([grid[0][i], grid[1][i], grid[2][i], grid[3][i], grid[4][i]].every((n) => active.contains(n))) return true;
      }
    }
    if (p == 'diagonal' || p == 'any line' || p == 'any_line') {
      if ([grid[0][0], grid[1][1], grid[2][2], grid[3][3], grid[4][4]].every((n) => active.contains(n))) return true;
      if ([grid[0][4], grid[1][3], grid[2][2], grid[3][1], grid[4][0]].every((n) => active.contains(n))) return true;
    }
    if (p == 'four corners' || p == 'four_corners') {
      if (active.contains(grid[0][0]) && active.contains(grid[0][4]) && active.contains(grid[4][0]) && active.contains(grid[4][4])) return true;
    }
    if (p == 'full house' || p == 'full_house') {
      return card.every((n) => active.contains(n));
    }
    return false;
  }

  Future<bool> claimWin({required String gameId, required String playerId}) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    try {
      return await _firestore.runTransaction((transaction) async {
        final gameSnap = await transaction.get(gameRef);
        if (!gameSnap.exists) return false;
        final gameData = gameSnap.data() as Map<String, dynamic>;
        final called = (gameData['calledNumbers'] as List<dynamic>? ?? []).map((e) => (e as num).toInt()).toList();
        final flags = List<int>.from(gameData['${playerId}_selectedFlags'] ?? []);
        final pattern = gameData['winningPattern'] as String? ?? 'Any Line';
        
        int count = gameData['${playerId}_cardCount'] ?? 0;
        for (int i = 0; i < count; i++) {
          String cardStr = gameData['${playerId}_card$i'] ?? '';
          if (cardStr.isEmpty) continue;
          List<int> card = cardStr.split(',').map((s) => int.parse(s.trim())).toList();
          if (_checkWinner(card, called, pattern)) {
            final nickname = flags.length > i ? flags[i].toString() : 'Player';
            final winners = List<Map<String, dynamic>>.from(gameData['winners'] ?? []);
            if (!winners.any((w) => w['playerId'] == playerId)) {
              winners.add({'playerId': playerId, 'nickname': nickname, 'timestamp': DateTime.now().toIso8601String()});
              transaction.update(gameRef, {'status': 'completed', 'winner': playerId, 'winners': winners});
            }
            return true;
          }
        }
        return false;
      });
    } catch (e) {
      return false;
    }
  }

  Future<void> callSpecificNumber(String gameId, int number) async {
    await _firestore.collection('games').doc(gameId).update({
      'calledNumbers': FieldValue.arrayUnion([number])
    });
  }

  Future<void> callRandomNumber(String gameId) async {
    final gameSnap = await _firestore.collection('games').doc(gameId).get();
    final called = (gameSnap.data()?['calledNumbers'] as List<dynamic>? ?? []).map((e) => (e as num).toInt()).toList();
    if (called.length >= 75) return;
    int next;
    do { next = Random().nextInt(75) + 1; } while (called.contains(next));
    await callSpecificNumber(gameId, next);
  }

  Future<void> distributePrizes(String gameId) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    
    try {
      final gameSnap = await gameRef.get();
      if (!gameSnap.exists) throw Exception('Game not found.');
      final gameData = gameSnap.data() as Map<String, dynamic>;
      if (gameData['prizeDistributed'] == true) throw Exception('Already paid.');

      final winners = List<dynamic>.from(gameData['winners'] ?? []);
      final String? adminId = gameData['adminId'];
      if (winners.isEmpty) throw Exception('No winners.');
      if (adminId == null) throw Exception('Admin ID missing.');

      final double totalPool = (gameData['totalCardsSold'] ?? 0) * _parseSafeDouble(gameData['cardCost']);
      final double totalWinnerShare = GameConfig.calculateWinnerShare(totalPool);
      final double adminShare = GameConfig.calculateAdminShare(totalPool);
      final double prizePerWinner = totalWinnerShare / winners.length;
      final now = DateTime.now();

      await _firestore.runTransaction((transaction) async {
        final List<DocumentSnapshot> wSnaps = [];
        for (var w in winners) {
          wSnaps.add(await transaction.get(_firestore.collection('players').doc(w['playerId'])));
        }
        final aSnap = await transaction.get(_firestore.collection('players').doc(adminId));

        for (var s in wSnaps) {
          if (s.exists) {
            final double bal = _parseSafeDouble((s.data() as Map<String, dynamic>?)?['balance']);
            transaction.update(s.reference, {'balance': bal + prizePerWinner});
            transaction.set(s.reference.collection('transactions').doc(), {
              'amount': prizePerWinner, 'type': 'game_win', 'reason': 'Bingo Win', 'date': now,
            });
          }
        }

        if (aSnap.exists) {
          final double bal = _parseSafeDouble((aSnap.data() as Map<String, dynamic>?)?['balance']);
          transaction.update(aSnap.reference, {'balance': bal + adminShare});
          transaction.set(aSnap.reference.collection('transactions').doc(), {
            'amount': adminShare, 'type': 'admin_profit', 'reason': 'Profit', 'date': now,
          });
        }

        transaction.update(gameRef, {'prizeDistributed': true});
      });
    } catch (e) {
      throw Exception('Payout error: $e');
    }
  }
}
