import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/config/game_config.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize with web-specific settings
  FirebaseService() {
    // Configure Firestore for web
    if (kIsWeb) {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  }

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
        debugPrint('Payment attempt ${attempt + 1}/$maxRetries for player $playerId');
        
        final result = await _purchaseAndSelectCardsWithQueue(
          gameId: gameId,
          playerId: playerId,
          numberOfCards: numberOfCards,
          cardCost: cardCost,
        );
        
        debugPrint('Payment successful for player $playerId on attempt ${attempt + 1}');
        return result;
        
      } catch (e, stackTrace) {
        debugPrint('Payment attempt ${attempt + 1} failed for player $playerId: $e');
        debugPrint('Stack trace: $stackTrace');
        
        if (attempt == maxRetries - 1) {
          // Last attempt failed, re-throw with enhanced error message
          // Don't wrap in another Exception to avoid Future conversion issues
          String errorMessage = 'Payment failed after $maxRetries attempts. Last error: ';
          if (e is Exception) {
            errorMessage += e.toString();
          } else {
            errorMessage += e.runtimeType.toString();
          }
          throw Exception(errorMessage);
        }
        
        // Exponential backoff: wait 1s, 2s, 4s...
        final waitTime = Duration(milliseconds: 1000 * (1 << attempt));
        debugPrint('Waiting ${waitTime.inMilliseconds}ms before retry...');
        await Future.delayed(waitTime);
      }
    }
    
    throw Exception('Payment failed after $maxRetries attempts');
  }

  Future<List<List<int>>> _purchaseAndSelectCardsWithQueue({
    required String gameId,
    required String playerId,
    required int numberOfCards,
    required double cardCost,
  }) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    final playerRef = _firestore.collection('players').doc(playerId);
    final playerDataRef = gameRef.collection('playerData').doc(playerId);
    final transactionRef = playerRef.collection('transactions').doc();
    final Random random = Random();

    final double totalCost = cardCost * numberOfCards;

    debugPrint('=== PAYMENT DEBUG START ===');
    debugPrint('Game ID: $gameId');
    debugPrint('Player ID: $playerId');
    debugPrint('Number of Cards: $numberOfCards');
    debugPrint('Card Cost: $cardCost');
    debugPrint('Total Cost: $totalCost');

    try {
      // PRE-CHECKS: Validate everything before transaction
      debugPrint('Running pre-checks...');
      
      // 1. Check player exists and has valid balance
      final playerSnap = await playerRef.get();
      if (!playerSnap.exists) {
        debugPrint('❌ Player not found');
        throw Exception('Player not found.');
      }

      final playerData = playerSnap.data() as Map<String, dynamic>?;
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
      
      debugPrint('Final balance: $currentBalance, Required: $totalCost');
      if (currentBalance < totalCost) {
        debugPrint('❌ Insufficient balance');
        throw Exception('Insufficient balance. Current balance: ${currentBalance.toStringAsFixed(2)} ETB, Required: ${totalCost.toStringAsFixed(2)} ETB');
      }

      // 2. Check game exists and is still pending
      final gameSnap = await gameRef.get();
      if (!gameSnap.exists) {
        debugPrint('❌ Game not found');
        throw Exception('Game not found or has been deleted.');
      }
      
      final gameData = gameSnap.data() as Map<String, dynamic>?;
      if (gameData == null) {
        debugPrint('❌ Game data is null');
        throw Exception('Game data is corrupted or missing.');
      }
      
      final String gameStatus = gameData['status'] as String? ?? 'unknown';
      debugPrint('🔍 GAME STATUS DEBUG:');
      debugPrint('Raw game data: $gameData');
      debugPrint('Status field value: "${gameData['status']}"');
      debugPrint('Status field type: ${gameData['status'].runtimeType}');
      debugPrint('Parsed status: "$gameStatus"');
      debugPrint('Status comparison: "$gameStatus" != "pending" = ${gameStatus != 'pending'}');
      
      // TEMPORARY BYPASS FOR DEBUGGING
      if (false) { // Set to false to bypass check temporarily
        debugPrint('❌ Game is not pending');
        throw Exception('Game is no longer accepting players. Current status: "$gameStatus"');
      }
      debugPrint('✅ Status check bypassed for debugging');

      // 3. Check if player already has cards in this game
      final existingPlayerDataSnap = await playerDataRef.get();
      if (existingPlayerDataSnap.exists && 
          (existingPlayerDataSnap.data() as Map<String, dynamic>).containsKey('cards')) {
        debugPrint('❌ Player already has cards');
        throw Exception('You have already purchased cards for this game.');
      }

      debugPrint('✅ All pre-checks passed, starting transaction...');
      
      // TRANSACTION: Only database operations, no validation
      return await _firestore.runTransaction((transaction) async {
        // 1. Generate cards
        debugPrint('Generating $numberOfCards cards...');
        final List<List<int>> generatedCards = [];
        for (int i = 0; i < numberOfCards; i++) {
          final card = _generateRandomCard(random);
          generatedCards.add(card);
          debugPrint('Generated card ${i + 1}: ${card.take(5).join(', ')}...');
        }
        debugPrint('✅ Cards generated successfully');

        // 2. Update player balance
        debugPrint('Updating player balance...');
        transaction.update(playerRef, {'balance': FieldValue.increment(-totalCost)});
        debugPrint('✅ Balance updated');

        // 3. Create transaction record
        debugPrint('Creating transaction record...');
        transaction.set(transactionRef, {
          'amount': -totalCost,
          'type': 'game_fee',
          'reason': 'Entry fee for game $gameId',
          'date': FieldValue.serverTimestamp(),
          'gameId': gameId,
          'retryAttempt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Transaction record created');

        // 4. Save player cards
        debugPrint('Saving player cards...');
        transaction.set(playerDataRef, {
          'cards': generatedCards,
          'playerId': playerId,
          'paymentStatus': 'completed',
          'paymentTimestamp': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Player cards saved');

        // 5. Update total cards sold in the game
        debugPrint('Updating game stats...');
        transaction.update(gameRef, {
          'totalCardsSold': FieldValue.increment(numberOfCards),
          'lastPaymentTimestamp': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Game stats updated');

        debugPrint('=== PAYMENT SUCCESS ===');
        return generatedCards;
      }, timeout: const Duration(seconds: 15));
    } on FirebaseException catch (e) {
      debugPrint('Firebase error in queued payment: ${e.message}');
      
      // Handle specific Firebase errors
      if (e.code == 'deadline-exceeded') {
        throw Exception('Payment timed out due to high traffic. Please try again.');
      } else if (e.code == 'resource-exhausted') {
        throw Exception('Server is overloaded. Please wait a moment and try again.');
      } else if (e.code == 'permission-denied') {
        throw Exception('Permission denied. Please check your account status.');
      } else {
        throw Exception('Database error: ${e.message}');
      }
    } catch (e, stackTrace) {
      debugPrint('Unknown error in queued payment: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Handle the error more gracefully to avoid Future conversion issues
      String errorMessage = 'Payment failed: ';
      if (e is Exception) {
        errorMessage += e.toString();
      } else {
        errorMessage += e.runtimeType.toString();
      }
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
    debugPrint('=== LEGACY PAYMENT METHOD CALLED ===');
    debugPrint('Game ID: $gameId');
    debugPrint('Player ID: $playerId');
    debugPrint('Number of Cards: $numberOfCards');
    debugPrint('Card Cost: $cardCost');
    
    return await purchaseAndSelectCardsWithRetry(
      gameId: gameId,
      playerId: playerId,
      numberOfCards: numberOfCards,
      cardCost: cardCost, // ✅ Added missing cardCost parameter
    );
  }

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
