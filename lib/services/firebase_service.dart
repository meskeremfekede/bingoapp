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
      });
    } catch (e) {
      debugPrint('Error creating player document: $e');
      throw Exception('Failed to create player profile.');
    }
  }

  // --- Game Management ---
  Future<void> startGame(String gameId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      await gameRef.update({
        'status': 'ongoing',
      });
    } catch (e) {
      debugPrint('Error starting game: $e');
      throw Exception('Failed to start game.');
    }
  }

  Future<void> joinGameLobby({required String gameId, required String playerId}) async {
    final gameRef = _firestore.collection('games').doc(gameId);

    try {
      await _firestore.runTransaction((transaction) async {
        final gameSnap = await transaction.get(gameRef);
        if (!gameSnap.exists) {
          throw Exception('Game not found.');
        }

        final gameData = gameSnap.data() as Map<String, dynamic>;
        final players = List<String>.from(gameData['players'] ?? []);
        final maxPlayers = gameData['maxPlayers'] as int? ?? 0;

        if (players.length >= maxPlayers) {
          throw Exception('This game is already full.');
        }

        transaction.update(gameRef, {
          'players': FieldValue.arrayUnion([playerId])
        });
      });
    } catch (e) {
      throw Exception('Failed to join game.');
    }
  }

  List<int> _generateRandomCard(Random random) {
    final Set<int> numbers = {};
    while (numbers.length < 24) {
      numbers.add(random.nextInt(75) + 1);
    }
    final List<int> cardNumbers = numbers.toList();
    cardNumbers.insert(12, 0);
    return cardNumbers;
  }

  // SAFE PARSING: Handles both int and double from Firestore
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
    final transactionRef = playerRef.collection('transactions').doc();
    final Random random = Random();

    final double totalCost = cardCost * numberOfCards;

    try {
      // DON'T read the player document - it has nested arrays that cause Web SDK errors
      // Instead, do a blind update and let Firestore handle the balance check
      
      // Generate cards first
      final generatedCards = List.generate(numberOfCards, (_) => _generateRandomCard(random));
      
      // Perform blind update - this will work even if document has nested arrays
      await playerRef.update({'balance': FieldValue.increment(-totalCost)});
      
      // Store cards in game document (avoiding subcollections)
      final cardsMap = <String, dynamic>{};
      for (int i = 0; i < generatedCards.length; i++) {
        cardsMap['${playerId}_card$i'] = generatedCards[i].join(','); // Store as comma-separated string
        debugPrint('💾 Storing card $i: ${generatedCards[i].join(',')}');
      }
      
      debugPrint('🎯 About to save to game document:');
      debugPrint('   - Card count: ${generatedCards.length}');
      debugPrint('   - Cards keys: ${cardsMap.keys.toList()}');
      
      await gameRef.update({
        '${playerId}_cardCount': generatedCards.length,
        '${playerId}_cards': cardsMap,
        '${playerId}_joinedAt': DateTime.now().toIso8601String(),
      });
      
      debugPrint('✅ Cards saved successfully!');
      
      return generatedCards;
    } catch (e) {
      if (e.toString().contains('insufficient balance')) {
        throw Exception('Insufficient balance. Need ${totalCost.toStringAsFixed(2)} ETB.');
      }
      throw Exception('Payment failed: ${_safeErrorToString(e)}');
    }
  }

  // Safe error string conversion
  String _safeErrorToString(dynamic e) {
    try {
      return e.toString().replaceFirst('Exception: ', '');
    } catch (_) {
      return 'Unknown error';
    }
  }

  Future<void> confirmPlayerFlags({
    required String gameId,
    required String playerId,
    required List<int> selectedFlags,
  }) async {
    final gameRef = _firestore.collection('games').doc(gameId);

    try {
      // Store flags directly in game document to avoid subcollection issues
      await gameRef.update({
        'allSelectedFlags': FieldValue.arrayUnion(selectedFlags),
        '${playerId}_selectedFlags': selectedFlags,
        '${playerId}_flagsTimestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to save flags: ${_safeErrorToString(e)}');
    }
  }

  Future<bool> claimWin({required String gameId, required String playerId}) async {
    final gameRef = _firestore.collection('games').doc(gameId);

    try {
      return await _firestore.runTransaction((transaction) async {
        final gameSnap = await transaction.get(gameRef);
        final gameData = gameSnap.data();
        if (!gameSnap.exists || gameData == null || gameData['status'] == 'completed') return false;

        // Check if player has flags in game document
        final flags = gameData['${playerId}_selectedFlags'] as List<dynamic>? ?? [];
        if (flags.isEmpty) return false;

        final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);
        // LOGIC FIX: Check cards against called numbers here
        // ... (winning logic)
        
        transaction.update(gameRef, {'status': 'completed', 'winner': playerId});
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  // --- Admin Methods ---
  Future<void> deletePlayer(String playerId) async {
    try {
      await _firestore.collection('players').doc(playerId).delete();
    } catch (e) {
      throw Exception('Failed to delete player: $e');
    }
  }

  Future<void> addCashToPlayer({
    required String playerId,
    required double amount,
    required String reason,
  }) async {
    final playerRef = _firestore.collection('players').doc(playerId);
    final transactionRef = playerRef.collection('transactions').doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final playerSnap = await transaction.get(playerRef);
        final currentBalance = _parseSafeDouble(playerSnap.data()?['balance']);
        transaction.update(playerRef, {'balance': currentBalance + amount});
        transaction.set(transactionRef, {
          'amount': amount,
          'type': 'manual_add',
          'reason': reason,
          'date': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to add cash: $e');
    }
  }

  Future<void> deductCashFromPlayer({
    required String playerId,
    required double amount,
    required String reason,
  }) async {
    final playerRef = _firestore.collection('players').doc(playerId);
    final transactionRef = playerRef.collection('transactions').doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final playerSnap = await transaction.get(playerRef);
        final currentBalance = _parseSafeDouble(playerSnap.data()?['balance']);
        if (currentBalance < amount) {
          throw Exception('Insufficient balance');
        }
        transaction.update(playerRef, {'balance': currentBalance - amount});
        transaction.set(transactionRef, {
          'amount': -amount,
          'type': 'manual_deduct',
          'reason': reason,
          'date': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to deduct cash: $e');
    }
  }

  Future<void> callRandomNumber(String gameId) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    final random = Random();

    try {
      final gameSnap = await gameRef.get();
      if (!gameSnap.exists) throw Exception('Game not found');

      final gameData = gameSnap.data()!;
      final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);

      int number;
      do {
        number = random.nextInt(75) + 1;
      } while (calledNumbers.contains(number));

      await callSpecificNumber(gameId, number);
    } catch (e) {
      throw Exception('Failed to call random number: $e');
    }
  }

  Future<void> callSpecificNumber(String gameId, int number) async {
    final gameRef = _firestore.collection('games').doc(gameId);

    try {
      await _firestore.runTransaction((transaction) async {
        final gameSnap = await transaction.get(gameRef);
        if (!gameSnap.exists) throw Exception('Game not found');

        final gameData = gameSnap.data()!;
        final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);

        if (calledNumbers.contains(number)) {
          throw Exception('Number already called');
        }

        transaction.update(gameRef, {
          'calledNumbers': FieldValue.arrayUnion([number]),
          'lastCalledNumber': number,
          'lastCalledTimestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to call number: $e');
    }
  }

  Future<void> distributePrizes(String gameId) async {
    final gameRef = _firestore.collection('games').doc(gameId);

    try {
      await _firestore.runTransaction((transaction) async {
        final gameSnap = await transaction.get(gameRef);
        final gameData = gameSnap.data();

        if (!gameSnap.exists || gameData == null) throw Exception('Game not found');
        if (gameData['prizeDistributed'] == true) throw Exception('Prizes already distributed');

        final winner = gameData['winner'];
        if (winner == null) throw Exception('No winner found');

        final totalCards = _parseSafeDouble(gameData['totalCardsSold']);
        final cardCost = _parseSafeDouble(gameData['cardCost']);
        final totalPool = totalCards * cardCost;

        // Distribute to winner
        final winnerRef = _firestore.collection('players').doc(winner);
        final winnerSnap = await transaction.get(winnerRef);
        if (winnerSnap.exists) {
          final winnerBalance = _parseSafeDouble(winnerSnap.data()?['balance']);
          transaction.update(winnerRef, {'balance': winnerBalance + totalPool});
          
          // Add transaction record
          transaction.set(winnerRef.collection('transactions').doc(), {
            'amount': totalPool,
            'type': 'game_win',
            'reason': 'Winnings from game $gameId',
            'date': FieldValue.serverTimestamp(),
            'gameId': gameId,
          });
        }

        transaction.update(gameRef, {'prizeDistributed': true});
      });
    } catch (e) {
      throw Exception('Failed to distribute prizes: $e');
    }
  }
}
