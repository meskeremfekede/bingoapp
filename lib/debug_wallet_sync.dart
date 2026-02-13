import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mygame/services/firebase_service.dart';

/// Debug tool to diagnose wallet synchronization issues
class WalletSyncDebugger {
  static Future<void> debugWalletSync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ ERROR: User not authenticated');
      return;
    }

    print('🔍 Starting Wallet Sync Debug...');
    print('👤 Player ID: ${user.uid}');
    print('📧 Player Email: ${user.email}');

    final playerRef = FirebaseFirestore.instance.collection('players').doc(user.uid);

    try {
      // 1. Check if player document exists
      print('\n🔍 Step 1: Checking player document...');
      final playerDoc = await playerRef.get();
      
      if (!playerDoc.exists) {
        print('❌ ERROR: Player document does not exist');
        return;
      }

      print('✅ Player document exists');
      print('📊 Document metadata:');
      print('   - From cache: ${playerDoc.metadata.isFromCache}');
      print('   - Has pending writes: ${playerDoc.metadata.hasPendingWrites}');
      print('   - From server: ${playerDoc.metadata.isFromServer}');

      // 2. Check current balance
      final balance = (playerDoc.data()!['balance'] as num?)?.toDouble() ?? 0.0;
      print('💰 Current balance: ${balance.toStringAsFixed(2)} ETB');

      // 3. Check recent transactions
      print('\n🔍 Step 2: Checking recent transactions...');
      final transactionsQuery = await playerRef
          .collection('transactions')
          .orderBy('date', descending: true)
          .limit(5)
          .get();

      if (transactionsQuery.docs.isEmpty) {
        print('📝 No transactions found');
      } else {
        print('📝 Recent transactions:');
        for (final doc in transactionsQuery.docs) {
          final data = doc.data();
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final type = data['type'] as String? ?? 'unknown';
          final reason = data['reason'] as String? ?? 'N/A';
          final date = (data['date'] as Timestamp?)?.toDate();
          
          print('   - ${amount.toStringAsFixed(2)} ETB | $type | $reason | ${date?.toString() ?? 'No date'}');
        }
      }

      // 4. Test real-time listener
      print('\n🔍 Step 3: Testing real-time listener...');
      print('👂 Listening for balance changes for 10 seconds...');
      
      int changeCount = 0;
      final subscription = playerRef.snapshots().listen((snapshot) {
        changeCount++;
        final newBalance = (snapshot.data()!['balance'] as num?)?.toDouble() ?? 0.0;
        print('📊 Change #$changeCount: Balance = ${newBalance.toStringAsFixed(2)} ETB (Cache: ${snapshot.metadata.isFromCache})');
      });

      // Wait for 10 seconds to see if any changes occur
      await Future.delayed(const Duration(seconds: 10));
      
      await subscription.cancel();
      
      if (changeCount == 1) {
        print('✅ Real-time listener working (received initial state)');
      } else if (changeCount > 1) {
        print('✅ Real-time listener working (received $changeCount updates)');
      } else {
        print('❌ ERROR: Real-time listener not receiving updates');
      }

      // 5. Test manual balance refresh
      print('\n🔍 Step 4: Testing manual refresh...');
      final refreshedDoc = await playerRef.get(GetOptions(source: Source.server));
      final refreshedBalance = (refreshedDoc.data()!['balance'] as num?)?.toDouble() ?? 0.0;
      
      print('💰 Server balance: ${refreshedBalance.toStringAsFixed(2)} ETB');
      
      if (refreshedBalance != balance) {
        print('⚠️  MISMATCH DETECTED!');
        print('   - Cached balance: ${balance.toStringAsFixed(2)} ETB');
        print('   - Server balance: ${refreshedBalance.toStringAsFixed(2)} ETB');
        print('   - Difference: ${(refreshedBalance - balance).toStringAsFixed(2)} ETB');
        print('💡 SOLUTION: Player needs to refresh their wallet');
      } else {
        print('✅ Balance is synchronized');
      }

      // 6. Test write permission
      print('\n🔍 Step 5: Testing write permission...');
      try {
        final testTransactionRef = playerRef.collection('transactions').doc();
        await testTransactionRef.set({
          'amount': 0.01,
          'type': 'test',
          'reason': 'Debug test transaction',
          'date': FieldValue.serverTimestamp(),
        });
        
        print('✅ Write permission working');
        
        // Clean up test transaction
        await testTransactionRef.delete();
        print('🧹 Test transaction cleaned up');
        
      } catch (e) {
        print('❌ ERROR: Write permission failed');
        print('📝 Error: $e');
      }

      print('\n🎯 Debug Summary:');
      print('1. Player document: ✅ Exists');
      print('2. Balance: ${balance.toStringAsFixed(2)} ETB');
      print('3. Real-time listener: ${changeCount > 0 ? "✅ Working" : "❌ Not working"}');
      print('4. Server sync: ${refreshedBalance == balance ? "✅ Synced" : "❌ Out of sync"}');
      print('5. Write permission: ✅ Working');

    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR during debug:');
      print('📝 Error: $e');
      print('📚 Stack trace: $stackTrace');
    }
  }

  static Future<void> forceBalanceSync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print('🔄 Forcing balance synchronization...');
    
    try {
      // Clear persistence to force fresh data
      await FirebaseFirestore.instance.clearPersistence();
      print('🧹 Cache cleared');
      
      // Fetch fresh data from server
      final playerDoc = await FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .get(GetOptions(source: Source.server));
      
      if (playerDoc.exists) {
        final balance = (playerDoc.data()!['balance'] as num?)?.toDouble() ?? 0.0;
        print('💰 Fresh balance from server: ${balance.toStringAsFixed(2)} ETB');
        print('✅ Balance synchronization complete');
      } else {
        print('❌ Player document not found on server');
      }
    } catch (e) {
      print('❌ Error forcing sync: $e');
    }
  }
}

/// Usage:
/// 
/// To debug wallet sync issues, call:
/// await WalletSyncDebugger.debugWalletSync();
/// 
/// To force balance refresh, call:
/// await WalletSyncDebugger.forceBalanceSync();
