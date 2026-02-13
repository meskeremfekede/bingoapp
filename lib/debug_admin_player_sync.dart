import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';

/// Debug tool to test admin-player balance synchronization
class AdminPlayerSyncDebugger {
  static Future<void> testBalanceSync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ ERROR: Admin not authenticated');
      return;
    }

    print('🔍 Testing Admin-Player Balance Synchronization...');
    print('👤 Admin ID: ${user.uid}');

    try {
      // 1. Get a sample player for testing
      print('\n🔍 Step 1: Finding a test player...');
      final playersQuery = await FirebaseFirestore.instance
          .collection('players')
          .limit(1)
          .get();

      if (playersQuery.docs.isEmpty) {
        print('❌ ERROR: No players found for testing');
        return;
      }

      final testPlayer = playersQuery.docs.first;
      final playerId = testPlayer.id;
      final playerData = testPlayer.data();
      final initialBalance = (playerData['balance'] as num?)?.toDouble() ?? 0.0;

      print('✅ Found test player: $playerId');
      print('💰 Initial balance: ${initialBalance.toStringAsFixed(2)} ETB');

      // 2. Set up real-time listener to monitor changes
      print('\n🔍 Step 2: Setting up real-time listener...');
      int changeCount = 0;
      final subscription = FirebaseFirestore.instance
          .collection('players')
          .doc(playerId)
          .snapshots(includeMetadataChanges: true)
          .listen((snapshot) {
            changeCount++;
            final newBalance = (snapshot.data()!['balance'] as num?)?.toDouble() ?? 0.0;
            print('📊 Change #$changeCount: Balance = ${newBalance.toStringAsFixed(2)} ETB (Cache: ${snapshot.metadata.isFromCache})');
          });

      // 3. Add test amount
      print('\n🔍 Step 3: Adding test amount (10.00 ETB)...');
      final testAmount = 10.00;
      
      await FirebaseService().addCashToPlayer(
        playerId: playerId,
        amount: testAmount,
        reason: 'Debug sync test',
      );

      print('✅ Test amount added successfully');

      // 4. Wait for real-time updates
      print('\n🔍 Step 4: Waiting for real-time updates...');
      await Future.delayed(const Duration(seconds: 5));

      // 5. Verify final balance
      print('\n🔍 Step 5: Verifying final balance...');
      final finalDoc = await FirebaseFirestore.instance
          .collection('players')
          .doc(playerId)
          .get(GetOptions(source: Source.server));

      final finalBalance = (finalDoc.data()!['balance'] as num?)?.toDouble() ?? 0.0;
      final expectedBalance = initialBalance + testAmount;

      print('💰 Initial balance: ${initialBalance.toStringAsFixed(2)} ETB');
      print('➕ Test amount added: ${testAmount.toStringAsFixed(2)} ETB');
      print('💰 Expected balance: ${expectedBalance.toStringAsFixed(2)} ETB');
      print('💰 Actual balance: ${finalBalance.toStringAsFixed(2)} ETB');
      print('📊 Real-time changes detected: $changeCount');

      // 6. Clean up - remove test amount
      print('\n🔍 Step 6: Cleaning up test data...');
      await FirebaseService().addCashToPlayer(
        playerId: playerId,
        amount: -testAmount,
        reason: 'Debug sync test cleanup',
      );

      await subscription.cancel();

      // 7. Results
      print('\n🎯 Test Results:');
      if (finalBalance == expectedBalance) {
        print('✅ SUCCESS: Balance updated correctly');
      } else {
        print('❌ FAILED: Balance mismatch');
        print('   Expected: ${expectedBalance.toStringAsFixed(2)} ETB');
        print('   Actual: ${finalBalance.toStringAsFixed(2)} ETB');
      }

      if (changeCount >= 2) {
        print('✅ SUCCESS: Real-time sync working (detected $changeCount changes)');
      } else {
        print('⚠️  WARNING: Real-time sync may not be working optimally (only $changeCount changes detected)');
      }

    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR during sync test:');
      print('📝 Error: $e');
      print('📚 Stack trace: $stackTrace');
    }
  }

  static Future<void> compareAdminPlayerViews() async {
    print('\n🔍 Comparing Admin vs Player Views...');
    
    try {
      // Get all players with their balances
      final playersQuery = await FirebaseFirestore.instance
          .collection('players')
          .get();

      double totalBalance = 0.0;
      int playerCount = 0;

      for (final doc in playersQuery.docs) {
        final balance = (doc.data()!['balance'] as num?)?.toDouble() ?? 0.0;
        totalBalance += balance;
        playerCount++;
        
        if (playerCount <= 5) { // Show first 5 players
          print('👤 Player ${doc.id}: ${balance.toStringAsFixed(2)} ETB');
        }
      }

      print('\n📊 Summary:');
      print('👥 Total Players: $playerCount');
      print('💰 Total Balance: ${totalBalance.toStringAsFixed(2)} ETB');
      print('📈 Average Balance: ${(totalBalance / playerCount).toStringAsFixed(2)} ETB');

      // Check for negative balances
      final negativeBalances = playersQuery.docs
          .where((doc) => ((doc.data()!['balance'] as num?)?.toDouble() ?? 0.0) < 0)
          .length;

      if (negativeBalances > 0) {
        print('⚠️  WARNING: $negativeBalances players have negative balances');
      } else {
        print('✅ All players have non-negative balances');
      }

    } catch (e) {
      print('❌ Error comparing views: $e');
    }
  }
}

/// Usage:
/// 
/// To test balance synchronization:
/// await AdminPlayerSyncDebugger.testBalanceSync();
/// 
/// To compare admin vs player views:
/// await AdminPlayerSyncDebugger.compareAdminPlayerViews();
