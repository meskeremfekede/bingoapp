import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class DataTypeDebugger extends StatefulWidget {
  const DataTypeDebugger({super.key});

  @override
  State<DataTypeDebugger> createState() => _DataTypeDebuggerState();
}

class _DataTypeDebuggerState extends State<DataTypeDebugger> {
  bool _isChecking = false;
  Map<String, dynamic> _playerData = {};
  Map<String, dynamic> _gameData = {};
  String _error = '';

  Future<void> _checkDataTypes() async {
    setState(() {
      _isChecking = true;
      _playerData = {};
      _gameData = {};
      _error = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Please login first';
          _isChecking = false;
        });
        return;
      }

      developer.log('🔍 Checking data types for user: ${user.uid}');

      // 1. Check player data
      developer.log('\n🔍 Step 1: Checking player data...');
      final playerDoc = await FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .get();

      if (!playerDoc.exists) {
        setState(() {
          _error = 'Player document not found';
          _isChecking = false;
        });
        return;
      }

      final playerData = playerDoc.data()!;
      developer.log('✅ Player data found');
      developer.log('Raw player data: $playerData');

      // Check each field type
      Map<String, dynamic> playerAnalysis = {};
      playerData.forEach((key, value) {
        playerAnalysis[key] = {
          'value': value,
          'type': value.runtimeType.toString(),
          'isSafe': _isSafeType(value),
          'isCorrectType': _isCorrectFieldType(key, value),
        };
        developer.log('Player field "$key": ${value.runtimeType} = $value');
      });

      // 2. Find a game and check game data
      developer.log('\n🔍 Step 2: Finding a game...');
      final gamesQuery = await FirebaseFirestore.instance
          .collection('games')
          .limit(1)
          .get();

      if (gamesQuery.docs.isEmpty) {
        setState(() {
          _error = 'No games found';
          _isChecking = false;
        });
        return;
      }

      final gameDoc = gamesQuery.docs.first;
      final gameData = gameDoc.data()!;
      developer.log('✅ Game data found');
      developer.log('Raw game data: $gameData');

      // Check each field type
      Map<String, dynamic> gameAnalysis = {};
      gameData.forEach((key, value) {
        gameAnalysis[key] = {
          'value': value,
          'type': value.runtimeType.toString(),
          'isSafe': _isSafeType(value),
          'isCorrectType': _isCorrectFieldType(key, value),
        };
        developer.log('Game field "$key": ${value.runtimeType} = $value');
      });

      // 3. Check for potential issues
      List<String> issues = [];
      
      // Check balance field
      if (playerData.containsKey('balance')) {
        final balance = playerData['balance'];
        if (!_isNumericType(balance)) {
          issues.add('Balance field is not numeric: ${balance.runtimeType}');
        }
      }

      // Check game cost field
      if (gameData.containsKey('cardCost')) {
        final cardCost = gameData['cardCost'];
        if (!_isNumericType(cardCost)) {
          issues.add('Card cost field is not numeric: ${cardCost.runtimeType}');
        }
      }

      // Check timestamp fields
      if (gameData.containsKey('createdAt')) {
        final createdAt = gameData['createdAt'];
        if (!_isTimestampType(createdAt)) {
          issues.add('CreatedAt field is not timestamp: ${createdAt.runtimeType}');
        }
      }

      if (playerData.containsKey('joinDate')) {
        final joinDate = playerData['joinDate'];
        if (!_isTimestampType(joinDate)) {
          issues.add('JoinDate field is not timestamp: ${joinDate.runtimeType}');
        }
      }

      setState(() {
        _playerData = playerAnalysis;
        _gameData = gameAnalysis;
        if (issues.isNotEmpty) {
          _error = 'Issues found: ${issues.join(', ')}';
        }
        _isChecking = false;
      });

    } catch (e) {
      developer.log('❌ Error checking data types: $e');
      setState(() {
        _error = 'Error: $e';
        _isChecking = false;
      });
    }
  }

  bool _isSafeType(dynamic value) {
    return value == null || 
           value is String || 
           value is num || 
           value is bool || 
           value is List || 
           value is Map ||
           value is Timestamp ||  // Add Timestamp as safe type
           value is DateTime;      // Add DateTime as safe type
  }

  bool _isNumericType(dynamic value) {
    return value is num || (value is String && double.tryParse(value) != null);
  }

  bool _isTimestampType(dynamic value) {
    return value is Timestamp || 
           value is DateTime ||
           (value is String && DateTime.tryParse(value) != null);
  }

  bool _isCorrectFieldType(String fieldName, dynamic value) {
    switch (fieldName.toLowerCase()) {
      case 'balance':
        return _isNumericType(value);
      case 'joindate':
      case 'createdat':
      case 'date':
        return _isTimestampType(value);
      case 'name':
      case 'email':
      case 'phonenumber':
        return value is String;
      case 'maxcards':
      case 'cardcost':
        return _isNumericType(value);
      default:
        return _isSafeType(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: const Text('Data Type Debugger'),
        backgroundColor: const Color(0xFF0A0A1A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isChecking ? null : _checkDataTypes,
              icon: _isChecking 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.bug_report),
              label: Text(_isChecking ? 'Checking...' : 'Check Data Types'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            if (_playerData.isNotEmpty) ...[
              const Text(
                'Player Data Types:',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildDataTable(_playerData, 'Player'),
                ),
              ),
            ],
            if (_gameData.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Game Data Types:',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildDataTable(_gameData, 'Game'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(Map<String, dynamic> data, String title) {
    return Card(
      color: const Color(0xFF1C1C3A),
      child: Column(
        children: data.entries.map((entry) {
          final fieldInfo = entry.value as Map<String, dynamic>;
          final fieldName = entry.key;
          final value = fieldInfo['value'];
          final type = fieldInfo['type'];
          final isSafe = fieldInfo['isSafe'];
          final isCorrectType = fieldInfo['isCorrectType'];

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCorrectType ? Icons.check_circle : Icons.error,
                      color: isCorrectType ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    if (!isCorrectType)
                      Icon(
                        isSafe ? Icons.warning : Icons.error,
                        color: isSafe ? Colors.orange : Colors.red,
                        size: 16,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fieldName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCorrectType ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Value: $value',
                  style: TextStyle(
                    color: isCorrectType ? Colors.green[300] : Colors.red[300],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
