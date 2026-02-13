import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';

/// Debug helper to test payment issues
class PaymentDebugger {
  static Future<void> debugPaymentFlow({
    required String gameId,
    required int numberOfCards,
    required double cardCost,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ ERROR: User not authenticated');
      return;
    }

    print('🔍 Starting Payment Debug...');
    print('📋 Game ID: $gameId');
    print('👤 Player ID: ${user.uid}');
    print('💳 Card Cost: $cardCost ETB');
    print('🎴 Number of Cards: $numberOfCards');
    print('💰 Total Cost: ${cardCost * numberOfCards} ETB');

    final firebaseService = FirebaseService();

    try {
      // Check player balance first
      print('\n🔍 Checking player balance...');
      final playerDoc = await FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .get();
      
      if (playerDoc.exists) {
        final balance = (playerDoc.data()!['balance'] as num?)?.toDouble() ?? 0.0;
        print('💰 Current Balance: $balance ETB');
        
        if (balance < cardCost * numberOfCards) {
          print('❌ INSUFFICIENT BALANCE: Need ${cardCost * numberOfCards}, have $balance');
          return;
        }
      } else {
        print('❌ ERROR: Player document not found');
        return;
      }

      // Check game exists
      print('\n🔍 Checking game status...');
      final gameDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(gameId)
          .get();
      
      if (!gameDoc.exists) {
        print('❌ ERROR: Game not found');
        return;
      }
      
      final gameData = gameDoc.data()!;
      print('🎮 Game Status: ${gameData['status']}');
      print('👥 Players in Game: ${gameData['players']}');

      // Check if already purchased
      print('\n🔍 Checking for existing purchase...');
      final existingPlayerData = await FirebaseFirestore.instance
          .collection('games')
          .doc(gameId)
          .collection('playerData')
          .doc(user.uid)
          .get();
      
      if (existingPlayerData.exists && existingPlayerData.data()!.containsKey('cards')) {
        print('❌ ERROR: Already purchased cards for this game');
        return;
      }

      print('\n✅ All pre-checks passed. Attempting payment...');
      
      // Attempt payment
      final cards = await firebaseService.purchaseAndSelectCards(
        gameId: gameId,
        playerId: user.uid,
        numberOfCards: numberOfCards,
        cardCost: cardCost,
      );

      print('✅ PAYMENT SUCCESSFUL!');
      print('🎴 Generated ${cards.length} cards');
      print('📋 Card numbers: ${cards.map((card) => card.take(5).toList()).toList()}...');
      
    } catch (e, stackTrace) {
      print('\n❌ PAYMENT FAILED!');
      print('🔍 Error Type: ${e.runtimeType}');
      print('📝 Error Message: $e');
      print('📚 Stack Trace: $stackTrace');
      
      // Analyze specific error types
      if (e.toString().contains('Insufficient balance')) {
        print('💡 SOLUTION: Add funds to wallet');
      } else if (e.toString().contains('already purchased')) {
        print('💡 SOLUTION: You already bought cards for this game');
      } else if (e.toString().contains('timed out')) {
        print('💡 SOLUTION: Check internet connection and try again');
      } else if (e.toString().contains('Permission denied')) {
        print('💡 SOLUTION: Check authentication status');
      } else if (e.toString().contains('Future')) {
        print('💡 SOLUTION: This is a Future conversion error - retry the payment');
      } else {
        print('💡 SOLUTION: Unknown error - contact support');
      }
    }
  }
}

/// Usage example in your payment screen:
/// 
/// In your _confirmSelection method, replace the payment call with:
/// 
/// await PaymentDebugger.debugPaymentFlow(
///   gameId: widget.gameId,
///   numberOfCards: _selectedNumberOfCards!,
///   cardCost: cardCost,
/// );
/// 
/// This will give you detailed information about what's failing.
