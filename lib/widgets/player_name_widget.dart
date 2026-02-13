import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerNameWidget extends StatelessWidget {
  final String playerId;

  const PlayerNameWidget({super.key, required this.playerId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('players').doc(playerId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading...');
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Text(playerId); // Fallback to ID
        }
        final playerData = snapshot.data!.data() as Map<String, dynamic>;
        return Text(playerData['name'] ?? playerId, style: const TextStyle(fontWeight: FontWeight.bold));
      },
    );
  }
}
