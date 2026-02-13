import 'package:cloud_firestore/cloud_firestore.dart';

class Player {
  final String id;
  final String name;
  final String phoneNumber;
  final DateTime? joinDate; // Make joinDate nullable
  final double balance;

  Player({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.joinDate,
    this.balance = 0.0,
  });

  factory Player.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    return Player(
      id: doc.id,
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      // Handle the case where joinDate might not exist in the document
      joinDate: data.containsKey('joinDate') && data['joinDate'] is Timestamp 
                ? (data['joinDate'] as Timestamp).toDate() 
                : null,
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0, // Safely handle balance
    );
  }
}
