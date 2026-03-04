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

  Future<void> deletePlayer(String playerId) async {
    try {
      await _firestore.collection('players').doc(playerId).delete();
    } catch (e) {
      debugPrint('Error deleting player: $e');
      throw Exception('Failed to delete player.');
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
    final playerRef = _firestore.collection('players').doc(playerId);

    try {
      await _firestore.runTransaction((transaction) async {
        final playerSnap = await playerRef.get();
        if (!playerSnap.exists) {
          debugPrint('❌ Player document not found');
          throw Exception('Player not found.');
        }

        final Map<String, dynamic>? playerData = playerSnap.data();
        if (playerData == null) {
          debugPrint('❌ Player data is null');
          throw Exception('Player data is corrupted or missing.');
        }
        
        final dynamic balanceValue = playerData['balance'];
        debugPrint('Raw balance value: $balanceValue (type: ${balanceValue.runtimeType})');
        
        if (balanceValue == null) {
          debugPrint('❌ Balance value is null');
          throw Exception('Player balance is not set. Please contact support.');
        }
        
        double currentBalance = 0.0;
        if (balanceValue is num) {
          currentBalance = balanceValue.toDouble();
          debugPrint('✅ Balance parsed as number: $currentBalance');
        } else if (balanceValue is String) {
          currentBalance = double.tryParse(balanceValue) ?? 0.0;
          debugPrint('✅ Balance parsed as string: $currentBalance');
        } else {
          debugPrint('❌ Invalid balance type: ${balanceValue.runtimeType}');
          throw Exception('Invalid balance format in player data.');
        }

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
    } on FirebaseException catch (e) {
      debugPrint('Firebase error joining lobby: ${e.message}');
      throw Exception('A database error occurred: ${e.message}');
    } catch (e) {
      debugPrint('Unknown error joining lobby: $e');
      throw Exception('An unknown error occurred while joining the game.');
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

  // --- Enhanced Payment System with Retry and Queue ---
  Future<List<List<int>>> purchaseAndSelectCardsWithRetry({
    required String gameId,
    required String playerId,
    required int numberOfCards,
    required double cardCost,
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // 1) Validate preconditions outside the transaction to avoid Web SDK runtime errors
        final prep = await _preparePaymentPreconditions(
          gameId: gameId,
          playerId: playerId,
          numberOfCards: numberOfCards,
          cardCost: cardCost,
        );

        final List<List<int>> generatedCards = prep['generatedCards'] as List<List<int>>;
        final double totalCost = prep['totalCost'] as double;

        // 2) Execute the minimal transaction that only performs writes
        final result = await _applyPaymentTransaction(
          gameId: gameId,
          playerId: playerId,
          numberOfCards: numberOfCards,
          totalCost: totalCost,
          generatedCards: generatedCards,
        );

        return result;
      } catch (e) {
        if (attempt == maxRetries - 1) {
          String errorMessage = 'Payment failed after $maxRetries attempts. Last error: ';
          if (e is Exception) {
            errorMessage += e.toString();
          } else {
            errorMessage += e.runtimeType.toString();
          }
          throw Exception(errorMessage);
        }
        final waitTime = Duration(milliseconds: 1000 * (1 << attempt));
        await Future.delayed(waitTime);
      }
    }
    throw Exception('Payment failed after $maxRetries attempts');
  }
  
  Future<Map<String, Object>> _preparePaymentPreconditions({
    required String gameId,
    required String playerId,
    required int numberOfCards,
    required double cardCost,
  }) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    final playerRef = _firestore.collection('players').doc(playerId);
    final playerDataRef = gameRef.collection('playerData').doc(playerId);
    final Random random = Random();

    final double totalCost = cardCost * numberOfCards;

    // 1. Get player document with full null safety
    final playerSnap = await playerRef.get();
    if (!playerSnap.exists) {
      throw Exception('Player not found.');
    }

    // 2. Check balance with full null safety
    final playerData = playerSnap.data() as Map<String, dynamic>?;
    if (playerData == null) {
      throw Exception('Player data is null or corrupted.');
    }
    
    debugPrint('🔍 PLAYER DATA DEBUG:');
    debugPrint('All player data: $playerData');
    
    final dynamic balanceValue = playerData['balance'];
    final double currentBalance;
    
    debugPrint('🔍 BALANCE DEBUG:');
    debugPrint('Balance value: $balanceValue');
    debugPrint('Balance type: ${balanceValue.runtimeType}');
    
    if (balanceValue == null) {
      throw Exception('Player balance field is missing.');
    } else if (balanceValue is num) {
      currentBalance = balanceValue.toDouble();
      debugPrint('✅ Balance parsed safely: $currentBalance');
    } else if (balanceValue is String) {
      currentBalance = double.tryParse(balanceValue) ?? 0.0;
      debugPrint('✅ Balance parsed from string: $currentBalance');
    } else {
      debugPrint('❌ Invalid balance type: ${balanceValue.runtimeType}');
      throw Exception('Invalid balance format: ${balanceValue.runtimeType}');
    }
    
    if (currentBalance < totalCost) {
      throw Exception('Insufficient balance. Current: $currentBalance, Required: $totalCost');
    }

    // 3. Check if player already has cards in this game
    final existingPlayerDataSnap = await playerDataRef.get();
    final existingData = existingPlayerDataSnap.data() as Map<String, dynamic>?;
    
    if (existingPlayerDataSnap.exists && 
        existingData != null &&
        existingData.containsKey('cards') &&
        existingData['cards'] != null) {
      throw Exception('You have already purchased cards for this game.');
    }

    // 4. REMOVED: Game status check - players can pay even if game started
    debugPrint('✅ Game status check bypassed - players can join anytime');

    // 5. Generate cards
    final List<List<int>> generatedCards = [];
    try {
      for (int i = 0; i < numberOfCards; i++) {
        final card = _generateRandomCard(random);
        if (card.isEmpty) throw Exception('Generated empty card at index $i');
        generatedCards.add(card);
      }
    } catch (e) {
      throw Exception('Failed to generate bingo cards: $e');
    }

    return {
      'generatedCards': generatedCards,
      'totalCost': totalCost,
    };
  }

  Future<List<List<int>>> _applyPaymentTransaction({
    required String gameId,
    required String playerId,
    required int numberOfCards,
    required double totalCost,
    required List<List<int>> generatedCards,
  }) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    final playerRef = _firestore.collection('players').doc(playerId);
    final playerDataRef = gameRef.collection('playerData').doc(playerId);

    try {
      return await _firestore.runTransaction((transaction) async {
        // Get current player data to check balance field type
        final playerSnap = await transaction.get(playerRef);
        final playerData = playerSnap.data() as Map<String, dynamic>?;
        
        if (playerData == null) {
          throw Exception('Player data not found during transaction.');
        }
        
        // Check balance field type and fix if needed
        final dynamic balanceValue = playerData['balance'];
        double currentBalance;
        
        debugPrint('🔍 TRANSACTION BALANCE DEBUG:');
        debugPrint('Balance value: $balanceValue');
        debugPrint('Balance type: ${balanceValue.runtimeType}');
        
        if (balanceValue == null) {
          throw Exception('Balance field is missing.');
        } else if (balanceValue is num) {
          currentBalance = balanceValue.toDouble();
          debugPrint('✅ Balance is numeric: $currentBalance');
        } else if (balanceValue is String) {
          currentBalance = double.tryParse(balanceValue) ?? 0.0;
          debugPrint('✅ Balance parsed from string: $currentBalance');
          // Fix balance field type
          transaction.update(playerRef, {'balance': currentBalance});
          debugPrint('✅ Fixed balance field type in database');
        } else {
          debugPrint('❌ Invalid balance type: ${balanceValue.runtimeType}');
          throw Exception('Invalid balance format: ${balanceValue.runtimeType}');
        }
        
        // Check if player has enough balance
        if (currentBalance < totalCost) {
          throw Exception('Insufficient balance. Current: $currentBalance, Required: $totalCost');
        }
        
        debugPrint('🔍 ABOUT TO UPDATE BALANCE:');
        debugPrint('Current balance: $currentBalance');
        debugPrint('Total cost: $totalCost');
        debugPrint('FieldValue increment: -${totalCost}');
        
        // Perform payment operations
        transaction.update(playerRef, {'balance': currentBalance - totalCost});
        
        debugPrint('✅ Balance update completed');

        final transactionRef = playerRef.collection('transactions').doc();
        debugPrint('🔍 CREATING TRANSACTION:');
        debugPrint('Transaction data: amount=-$totalCost, type=game_fee, gameId=$gameId');
        
        transaction.set(transactionRef, {
          'amount': -totalCost,
          'type': 'game_fee',
          'reason': 'Entry fee for game $gameId',
          'date': FieldValue.serverTimestamp(),
          'gameId': gameId,
        });
        
        debugPrint('✅ Transaction created');

        debugPrint('🔍 CREATING PLAYER DATA:');
        debugPrint('Cards count: ${generatedCards.length}');
        debugPrint('Player ID: $playerId');
        
        transaction.set(playerDataRef, {
          'cards': generatedCards.map((card) => card.map((num) => num as int).toList()).toList(),
          'playerId': playerId,
          'paymentStatus': 'completed',
          'paymentTimestamp': FieldValue.serverTimestamp(),
        });
        
        debugPrint('✅ Player data created');

        debugPrint('🔍 UPDATING GAME:');
        debugPrint('Cards sold increment: $numberOfCards');
        
        transaction.update(gameRef, {
          'totalCardsSold': FieldValue.increment(numberOfCards),
          'lastPaymentTimestamp': FieldValue.serverTimestamp(),
        });
        
        debugPrint('✅ Game updated');

        return generatedCards;
      });
    } on FirebaseException catch (e) {
      if (e.code == 'deadline-exceeded') {
        throw Exception('Payment timed out. Please check your connection and try again.');
      } else if (e.code == 'permission-denied') {
        throw Exception('Permission denied. Please check your account status.');
      } else if (e.code == 'not-found') {
        throw Exception('Required data not found. Please contact support.');
      } else if (e.code == 'already-exists') {
        throw Exception('You have already purchased cards for this game.');
      } else {
        throw Exception('Database error: ${e.message}');
      }
    } on TimeoutException catch (e) {
      // Handle web platform timeout issue
      debugPrint('🔍 TIMEOUT EXCEPTION: $e');
      throw Exception('Payment timed out. Please check your connection and try again.');
    } catch (e, stackTrace) {
      String errorMessage = 'Payment failed: ';
      debugPrint('🔍 PAYMENT ERROR DEBUG:');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (e is Exception) {
        errorMessage += e.toString();
        debugPrint('🔍 EXCEPTION DETAILS: ${e.toString()}');
      } else if (e is TypeError) {
        errorMessage += 'Data format error: Account data has wrong types. Please run "Fix Account Data" button.';
        debugPrint('🔍 TYPE ERROR DETAILS:');
        debugPrint('Error: $e');
        if (stackTrace != null) {
          debugPrint('Stack trace: $stackTrace');
        }
      } else {
        errorMessage += 'Unknown error: ${e.runtimeType}';
      }
      
      // Also log the exact error for debugging
      debugPrint('🔍 FINAL ERROR MESSAGE: $errorMessage');
      throw Exception(errorMessage);
    }
  }

  // Legacy method for backward compatibility
  Future<List<List<int>>> purchaseAndSelectCards({
    required String gameId,
    required String playerId,
    required int numberOfCards,
    required double cardCost,
  }) async {
    return await purchaseAndSelectCardsWithRetry(
      gameId: gameId,
      playerId: playerId,
      numberOfCards: numberOfCards,
      cardCost: cardCost,
    );
  }

  // --- Game State Synchronization ---
  Future<bool> checkAllPlayersSelectedFlags(String gameId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      final gameSnap = await gameRef.get();
      
      if (!gameSnap.exists) return false;
      
      final gameData = gameSnap.data() as Map<String, dynamic>;
      final players = List<String>.from(gameData['players'] ?? []);
      
      if (players.isEmpty) return false;
      
      // Check if all players have selected flags
      final playerDataCollection = await gameRef.collection('playerData').get();
      int playersWithFlags = 0;
      
      for (final playerDoc in playerDataCollection.docs) {
        final playerData = playerDoc.data();
        if (playerData.containsKey('selectedFlags') && 
            (playerData['selectedFlags'] as List).isNotEmpty) {
          playersWithFlags++;
        }
      }
      
      debugPrint('Players with flags: $playersWithFlags/$players');
      return playersWithFlags == players.length;
      
    } catch (e) {
      debugPrint('Error checking flag selection status: $e');
      return false;
    }
  }

  Future<void> startGameForAllPlayers(String gameId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      
      await _firestore.runTransaction((transaction) async {
        final gameSnap = await transaction.get(gameRef);
        if (!gameSnap.exists) {
          throw Exception('Game not found.');
        }
        
        // Update game status to indicate all players are ready
        transaction.update(gameRef, {
          'status': 'flag_selection_complete',
          'gameStartTime': FieldValue.serverTimestamp(),
        });
      });
      
      debugPrint('Game started for all players in game: $gameId');
    } catch (e) {
      debugPrint('Error starting game for all players: $e');
      throw Exception('Failed to start game: ${e.toString()}');
    }
  }

  Stream<DocumentSnapshot> getGameStateStream(String gameId) {
    return _firestore.collection('games').doc(gameId).snapshots();
  }

  Future<void> confirmPlayerFlags({
    required String gameId,
    required String playerId,
    required List<int> selectedFlags,
  }) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    final playerDataRef = gameRef.collection('playerData').doc(playerId);

    try {
      await _firestore.runTransaction((transaction) async {
        final gameSnap = await transaction.get(gameRef);
        if (!gameSnap.exists) {
          throw Exception('Game not found.');
        }

        final gameData = gameSnap.data() as Map<String, dynamic>? ?? {};
        final allTakenFlags = Set<int>.from(gameData['allSelectedFlags'] as List<dynamic>? ?? []);

        for (final flag in selectedFlags) {
          if (allTakenFlags.contains(flag)) {
            throw Exception('Flag #$flag has just been taken. Please select another.');
          }
        }

        transaction.update(gameRef, {
          'allSelectedFlags': FieldValue.arrayUnion(selectedFlags),
        });
        transaction.update(playerDataRef, {
          'selectedFlags': selectedFlags,
          'flagSelectionTimestamp': FieldValue.serverTimestamp(),
        });
      });

      // After confirming flags, check if all players are ready
      final allReady = await checkAllPlayersSelectedFlags(gameId);
      if (allReady) {
        await startGameForAllPlayers(gameId);
      }
    } on FirebaseException catch (e) {
      debugPrint('Firebase error confirming flags: ${e.message}');
      throw Exception('A database error occurred: ${e.message}');
    } catch (e) {
      debugPrint('Unknown error confirming flags: $e');
      throw Exception('An unknown error occurred while confirming your flags.');
    }
  }

  List<int> _getIndicesForPattern(String pattern) {
    switch (pattern) {
      case 'Any Line':
        // Any complete horizontal line (5 rows)
        return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24];
      case 'Horizontal':
        // Any complete horizontal line (5 rows)
        return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24];
      case 'Vertical':
        // Any complete vertical line (5 columns)
        return [0, 5, 10, 15, 20, 1, 6, 11, 16, 21, 2, 7, 12, 17, 22, 3, 8, 13, 18, 23, 4, 9, 14, 19, 24];
      case 'Diagonal':
        // Two main diagonals
        return [0, 6, 12, 18, 24, 4, 8, 12, 16, 20]; // Both diagonals combined
      case 'Four Corners':
        // Four corner squares
        return [0, 4, 20, 24];
      case 'Full House':
        // All 25 squares
        return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24];
      default:
        return [];
    }
  }

  bool _doesCardWin(List<int> card, List<int> calledNumbers, List<int> patternIndices) {
    for (final index in patternIndices) {
      final number = card[index];
      if (number != 0 && !calledNumbers.contains(number)) {
        return false;
      }
    }
    return true;
  }

  Future<bool> claimWin({required String gameId, required String playerId}) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    final playerDataRef = gameRef.collection('playerData').doc(playerId);

    try {
      return await _firestore.runTransaction((transaction) async {
        final gameSnap = await transaction.get(gameRef);
        final gameData = gameSnap.data();
        if (!gameSnap.exists || gameData == null || gameData['status'] == 'completed') {
          return false;
        }

        final playerDataSnap = await transaction.get(playerDataRef);
        if (!playerDataSnap.exists) return false;

        final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);
        final winningPattern = gameData['winningPattern'] as String;
        final patternIndices = _getIndicesForPattern(winningPattern);

        if (patternIndices.isEmpty) return false;

        final playerData = playerDataSnap.data()!;
        final List<dynamic> cards = playerData['cards'] ?? [];
        bool playerHasWon = false;

        for (final card in cards) {
          if (_doesCardWin(List<int>.from(card), calledNumbers, patternIndices)) {
            playerHasWon = true;
            break;
          }
        }

        if (playerHasWon) {
          final allPlayersSnap = await gameRef.collection('playerData').get();
          final List<Map<String, dynamic>> winners = [];
          final Set<String> winnerIds = {};

          for (final doc in allPlayersSnap.docs) {
            final pData = doc.data();
            if (winnerIds.contains(pData['playerId'])) continue;

            for (final card in pData['cards'] ?? []) {
              if (_doesCardWin(List<int>.from(card), calledNumbers, patternIndices)) {
                winners.add({'playerId': pData['playerId']});
                winnerIds.add(pData['playerId']);
                break;
              }
            }
          }

          if (winners.isNotEmpty) {
            transaction.update(gameRef, {
              'status': 'completed',
              'winners': winners,
            });
          }
          return true;
        }
        return false;
      });
    } on FirebaseException catch (e) {
        debugPrint('Firebase error claiming win: ${e.message}');
        return false;
    } catch (e) {
        debugPrint('Unknown error claiming win: $e');
        return false;
    }
  }

  // --- Enhanced Real-Time Number Calling ---
  Future<void> callSpecificNumber(String gameId, int number) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      
      await _firestore.runTransaction((transaction) async {
        final gameSnap = await transaction.get(gameRef);
        if (!gameSnap.exists) {
          throw Exception('Game not found.');
        }
        
        final gameData = gameSnap.data() as Map<String, dynamic>;
        final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);
        
        if (calledNumbers.contains(number)) {
          throw Exception('Number $number has already been called.');
        }
        
        // Add number with timestamp for better synchronization
        transaction.update(gameRef, {
          'calledNumbers': FieldValue.arrayUnion([number]),
          'lastCalledNumber': number,
          'lastCalledTimestamp': FieldValue.serverTimestamp(),
        });
      });
      
      debugPrint('Number $number called successfully in game $gameId');
      
      // Check for winners after each number call
      await _checkAndNotifyWinners(gameId);
      
    } catch (e) {
      debugPrint('Error calling number: $e');
      throw Exception('Failed to call number: ${e.toString()}');
    }
  }

  Future<void> callRandomNumber(String gameId) async {
    try {
      final random = Random();
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      final calledNumbers = List<int>.from(gameDoc.data()!['calledNumbers'] ?? []);

      int number;
      int attempts = 0;
      final maxAttempts = 75; // Prevent infinite loop
      
      do {
        number = random.nextInt(75) + 1;
        attempts++;
        if (attempts >= maxAttempts) {
          throw Exception('All numbers have been called.');
        }
      } while (calledNumbers.contains(number));

      await callSpecificNumber(gameId, number);
    } catch (e) {
      debugPrint('Error calling random number: $e');
      throw Exception('Failed to call random number: ${e.toString()}');
    }
  }

  Future<void> _checkAndNotifyWinners(String gameId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);
      final gameSnap = await gameRef.get();
      
      if (!gameSnap.exists) return;
      
      final gameData = gameSnap.data() as Map<String, dynamic>;
      final status = gameData['status'] as String? ?? 'pending';
      
      if (status != 'ongoing' && status != 'flag_selection_complete') return;
      
      final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);
      final winningPattern = gameData['winningPattern'] as String;
      final patternIndices = _getIndicesForPattern(winningPattern);
      
      if (patternIndices.isEmpty) return;
      
      final playerDataCollection = await gameRef.collection('playerData').get();
      final List<Map<String, dynamic>> winners = [];
      
      for (final playerDoc in playerDataCollection.docs) {
        final playerData = playerDoc.data();
        final List<dynamic> cards = playerData['cards'] ?? [];
        
        for (final card in cards) {
          if (_doesCardWin(List<int>.from(card), calledNumbers, patternIndices)) {
            winners.add({
              'playerId': playerData['playerId'],
              'winningCard': card,
              'winningTimestamp': FieldValue.serverTimestamp(),
            });
            break; // Only need one winning card per player
          }
        }
      }
      
      if (winners.isNotEmpty) {
        await gameRef.update({
          'status': 'completed',
          'winners': winners,
          'gameEndTime': FieldValue.serverTimestamp(),
        });
        
        debugPrint('Game completed! Winners: ${winners.map((w) => w['playerId']).toList()}');
      }
    } catch (e) {
      debugPrint('Error checking winners: $e');
    }
  }

  Future<void> addCashToPlayer({
    required String playerId,
    required double amount,
    required String reason,
    String type = 'manual',
  }) async {
    final playerRef = _firestore.collection('players').doc(playerId);
    final transactionRef = playerRef.collection('transactions').doc();

    try {
      await _firestore.runTransaction((transaction) async {
          final playerSnap = await transaction.get(playerRef);
          if (!playerSnap.exists) throw Exception("Player not found.");
          transaction.update(playerRef, {'balance': FieldValue.increment(amount)});
          transaction.set(transactionRef, {
            'amount': amount,
            'type': type,
            'reason': reason,
            'date': FieldValue.serverTimestamp(),
          });
      });
    } on FirebaseException catch (e) {
        debugPrint('Firebase error adding cash: ${e.message}');
        throw Exception('A database error occurred: ${e.message}');
    } catch (e) {
        debugPrint('Unknown error adding cash: $e');
        throw Exception('An unknown error occurred while updating your balance.');
    }
  }

  Future<void> deductCashFromPlayer({
    required String playerId,
    required double amount,
    required String reason,
    String type = 'manual',
  }) async {
    final playerRef = _firestore.collection('players').doc(playerId);
    final transactionRef = playerRef.collection('transactions').doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final playerSnap = await transaction.get(playerRef);
        if (!playerSnap.exists) throw Exception('Player not found.');
        double currentBalance = (playerSnap.data() as Map<String, dynamic>)?['balance'] ?? 0.0;
        if (currentBalance < amount) throw Exception("Insufficient balance.");
        transaction.update(playerRef, {'balance': FieldValue.increment(-amount)});
        transaction.set(transactionRef, {
          'amount': -amount,
          'type': type,
          'reason': reason,
          'date': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
        debugPrint('Firebase error deducting cash: ${e.message}');
        throw Exception('A database error occurred: ${e.message}');
    } catch (e) {
        debugPrint('Unknown error deducting cash: $e');
        throw Exception('An unknown error occurred while updating your balance.');
    }
  }

  Future<void> distributePrizes(String gameId) async {
    final gameRef = _firestore.collection('games').doc(gameId);

    try {
      await _firestore.runTransaction((transaction) async {
        final gameSnap = await transaction.get(gameRef);
        final gameData = gameSnap.data();

        if (!gameSnap.exists || gameData == null) throw Exception("Game not found.");
        if (gameData['prizeDistributed'] == true) throw Exception("Prizes have already been distributed for this game.");
        
        final winners = List<Map<String, dynamic>>.from(gameData['winners'] ?? []);
        final totalCards = gameData['totalCardsSold'] as int? ?? 0;
        final cardCost = (gameData['cardCost'] as num?)?.toDouble() ?? 0.0;
        final totalPool = totalCards * cardCost;

        if (winners.isEmpty) {
          transaction.update(gameRef, {'prizeDistributed': false, 'status': 'completed'});
          return;
        }

        final winnerShare = GameConfig.calculateWinnerShare(totalPool);
        final adminShare = GameConfig.calculateAdminShare(totalPool);
        final prizePerWinner = GameConfig.calculatePrizePerWinner(totalPool, winners.length);

        for (final winner in winners) {
          final playerId = winner['playerId'];
          if (playerId == null) continue;

          final playerRef = _firestore.collection('players').doc(playerId);
          final playerTransactionRef = playerRef.collection('transactions').doc();
          transaction.update(playerRef, {'balance': FieldValue.increment(prizePerWinner)});
          transaction.set(playerTransactionRef, {
              'amount': prizePerWinner,
              'type': 'game_win',
              'reason': 'Winnings from game: ${gameData['gameName'] ?? gameId}',
              'date': FieldValue.serverTimestamp(),
          });
        }

        final adminId = gameData['adminId'];
        if (adminId != null) {
          final adminRef = _firestore.collection('players').doc(adminId);
          final adminTransactionRef = adminRef.collection('transactions').doc();

          final adminSnap = await transaction.get(adminRef);
          if (adminSnap.exists) {
            transaction.update(adminRef, {'balance': FieldValue.increment(adminShare)});
            transaction.set(adminTransactionRef, {
                'amount': adminShare,
                'type': 'game_profit',
                'reason': 'Admin profit from game: ${gameData['gameName'] ?? gameId}',
                'date': FieldValue.serverTimestamp(),
            });
          }
        }
        
        transaction.update(gameRef, {'prizeDistributed': true});
      });
    } on FirebaseException catch (e) {
      debugPrint('Firebase error distributing prizes: ${e.message}');
    } catch (e) {
      debugPrint('Unknown error distributing prizes: $e');
    }
  }
}
