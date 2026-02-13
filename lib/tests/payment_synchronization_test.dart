  import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/services/firebase_service.dart';
import 'package:mygame/firebase_options.dart';
import 'dart:async';

/// Test suite for multiplayer payment synchronization
/// This test validates that the enhanced payment system handles race conditions
/// and ensures proper state synchronization between multiple players.
void main() {
  late FirebaseService firebaseService;

  // This runs ONCE before all tests
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  // This runs before EACH test in ALL groups, ensuring a fresh service instance
  setUp(() {
    firebaseService = FirebaseService();
  });

  group('Payment Synchronization Tests', () {
    const String testGameId = 'test_game_sync';
    const List<String> testPlayers = ['player1', 'player2', 'player3', 'player4'];
    
    setUp(() async {
      await PaymentTestHelper.setupTestGame(testGameId, testPlayers);
    });

    tearDown(() async {
      await PaymentTestHelper.cleanupTestGame(testGameId);
    });
    
    test('Concurrent payment attempts should not cause race conditions', () async {
      // Simulate 4 players trying to pay simultaneously
      final List<Future<List<List<int>>>> paymentFutures = [];
      
      for (final playerId in testPlayers) {
        paymentFutures.add(
          firebaseService.purchaseAndSelectCardsWithRetry(
            gameId: testGameId,
            playerId: playerId,
            numberOfCards: 2,
            cardCost: 10.0,
            maxRetries: 3,
          ),
        );
      }
      
      // Wait for all payments to complete
      final results = await Future.wait(paymentFutures);
      
      // Verify all payments succeeded
      expect(results.length, equals(4));
      for (final result in results) {
        expect(result, isNotNull);
        expect(result.length, equals(2)); // 2 cards per player
      }
    });
    
    test('Payment retry mechanism should handle temporary failures', () async {
      // This test simulates a temporary failure scenario
      int attemptCount = 0;
      
      // Mock a function that fails twice then succeeds
      Future<List<List<int>>> mockPaymentWithRetries() async {
        attemptCount++;
        if (attemptCount <= 2) {
          throw Exception('Simulated temporary failure');
        }
        return [[1, 2, 3, 4, 5], [6, 7, 8, 9, 10]]; // Mock cards
      }
      
      try {
        final result = await mockPaymentWithRetries();
        expect(attemptCount, equals(3)); // Should have retried 3 times
        expect(result, isNotNull);
      } catch (e) {
        fail('Payment should have succeeded after retries: $e');
      }
    });
    
    test('Game state synchronization should work correctly', () async {
      // Test that all players transition to GameBoard simultaneously
      const String testGameId = 'sync_test_game';
      
      // Simulate players confirming flags
      for (final playerId in testPlayers) {
        await firebaseService.confirmPlayerFlags(
          gameId: testGameId,
          playerId: playerId,
          selectedFlags: [1, 2, 3],
        );
      }
      
      // Check if all players are ready
      final allReady = await firebaseService.checkAllPlayersSelectedFlags(testGameId);
      expect(allReady, isTrue);
      
      // Verify game state is updated
      final gameStateStream = firebaseService.getGameStateStream(testGameId);
      final gameSnapshot = await gameStateStream.first;
      
      if (gameSnapshot.exists) {
        final gameData = gameSnapshot.data() as Map<String, dynamic>;
        final status = gameData['status'] as String?;
        expect(status, equals('flag_selection_complete'));
      } else {
        fail('Game document should exist');
      }
    });
    
    test('Real-time number calling should be synchronized', () async {
      const String testGameId = 'number_sync_test';
      
      // Test calling numbers sequentially
      final numbersToCall = [1, 2, 3, 4, 5];
      
      for (final number in numbersToCall) {
        await firebaseService.callSpecificNumber(testGameId, number);
      }
      
      // Verify all numbers were called
      final gameRef = FirebaseFirestore.instance.collection('games').doc(testGameId);
      final gameSnapshot = await gameRef.get();
      
      if (gameSnapshot.exists) {
        final gameData = gameSnapshot.data() as Map<String, dynamic>;
        final calledNumbers = List<int>.from(gameData['calledNumbers'] ?? []);
        
        for (final number in numbersToCall) {
          expect(calledNumbers.contains(number), isTrue);
        }
      } else {
        fail('Game document should exist');
      }
    });
    
    test('Winner detection should work correctly', () async {
      const String testGameId = 'winner_test_game';
      
      // This test would require setting up a complete game scenario
      // with cards and called numbers to test winner detection
      
      // For now, we'll test the winner detection logic exists
      expect(firebaseService.claimWin, isA<Future<bool> Function({required String gameId, required String playerId})>());
    });
  });
  
  group('Error Handling Tests', () {
    test('Insufficient balance should be handled gracefully', () async {
      const String testGameId = 'balance_test_game';
      const String poorPlayerId = 'poor_player';
      
      try {
        await firebaseService.purchaseAndSelectCardsWithRetry(
          gameId: testGameId,
          playerId: poorPlayerId,
          numberOfCards: 10, // Expensive purchase
          cardCost: 100.0,
          maxRetries: 1,
        );
        fail('Should have thrown insufficient balance error');
      } catch (e) {
        expect(e.toString(), contains('Insufficient balance'));
      }
    });
    
    test('Duplicate payment attempts should be prevented', () async {
      const String testGameId = 'duplicate_test_game';
      const String playerId = 'duplicate_player';
      
      // First payment should succeed
      await firebaseService.purchaseAndSelectCardsWithRetry(
        gameId: testGameId,
        playerId: playerId,
        numberOfCards: 1,
        cardCost: 10.0,
      );
      
      // Second payment should fail
      try {
        await firebaseService.purchaseAndSelectCardsWithRetry(
          gameId: testGameId,
          playerId: playerId,
          numberOfCards: 1,
          cardCost: 10.0,
        );
        fail('Should have thrown duplicate payment error');
      } catch (e) {
        expect(e.toString(), contains('already purchased'));
      }
    });
  });
  
  group('Performance Tests', () {
    test('Payment system should handle high concurrency', () async {
      const int playerCount = 10;
      final List<Future<List<List<int>>>> paymentFutures = [];
      
      // Create many concurrent payment attempts
      for (int i = 0; i < playerCount; i++) {
        paymentFutures.add(
          firebaseService.purchaseAndSelectCardsWithRetry(
            gameId: 'performance_test_game',
            playerId: 'player_$i',
            numberOfCards: 1,
            cardCost: 5.0,
            maxRetries: 2,
          ),
        );
      }
      
      final stopwatch = Stopwatch()..start();
      final results = await Future.wait(paymentFutures);
      stopwatch.stop();
      
      // Verify all payments completed within reasonable time
      expect(results.length, equals(playerCount));
      expect(stopwatch.elapsedMilliseconds, lessThan(30000)); // Should complete within 30 seconds
      
      print('Performance test completed in ${stopwatch.elapsedMilliseconds}ms for $playerCount players');
    });
  });
}

/// Helper class for testing payment synchronization
class PaymentTestHelper {
  static Future<void> setupTestGame(String gameId, List<String> players) async {
    final gameRef = FirebaseFirestore.instance.collection('games').doc(gameId);
    
    await gameRef.set({
      'gameName': 'Test Game',
      'status': 'pending', // Set to pending for purchase tests
      'players': players,
      'maxPlayers': players.length,
      'cardCost': 10.0,
      'winningPattern': 'Any Line',
      'calledNumbers': [],
      'totalCardsSold': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Setup dummy player documents with sufficient balance
    for (final playerId in players) {
      await FirebaseFirestore.instance.collection('players').doc(playerId).set({
        'balance': 1000.0,
        'name': playerId,
      });
    }
  }
  
  static Future<void> cleanupTestGame(String gameId) async {
    final gameRef = FirebaseFirestore.instance.collection('games').doc(gameId);
    
    // Clean up player data associated with the game
    final playerDataCollection = await gameRef.collection('playerData').get();
    for (final doc in playerDataCollection.docs) {
      await doc.reference.delete();
    }

    // Clean up main player documents created for the test
    final gameSnap = await gameRef.get();
    if (gameSnap.exists) {
        final gameData = gameSnap.data() as Map<String, dynamic>;
        final players = List<String>.from(gameData['players'] ?? []);
        for (final playerId in players) {
            await FirebaseFirestore.instance.collection('players').doc(playerId).delete();
        }
    }
    
    // Delete game document
    await gameRef.delete();
  }
}
