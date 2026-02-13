import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { manual, game }

class Transaction {
  final String id;
  final double amount;
  final TransactionType type;
  final String? gameId;
  final DateTime date;
  final String? reason;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.date,
    this.gameId,
    this.reason,
  });

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Transaction(
      id: doc.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0, // Safe conversion
      // Safely check the type
      type: (data['type'] == 'game') ? TransactionType.game : TransactionType.manual,
      // Safely read gameId, which can be null for manual transactions
      gameId: data.containsKey('gameId') ? data['gameId'] as String? : null,
      // Safely handle the date
      date: data.containsKey('date') && data['date'] is Timestamp 
            ? (data['date'] as Timestamp).toDate() 
            : DateTime.now(), // Provide a fallback date
      reason: data['reason'] as String?,
    );
  }
}
