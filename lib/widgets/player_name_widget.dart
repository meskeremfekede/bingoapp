import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerNameWidget extends StatelessWidget {
  final String playerId;
  final TextStyle? textStyle; // Added optional textStyle

  const PlayerNameWidget({super.key, required this.playerId, this.textStyle});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('players').doc(playerId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text('Loading...', style: textStyle);
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Text(playerId, style: textStyle); // Fallback to ID
        }
        final playerData = snapshot.data!.data() as Map<String, dynamic>;
        // Use provided style or default bold
        final finalStyle = textStyle ?? const TextStyle(fontWeight: FontWeight.bold);
        return Text(playerData['name'] ?? playerId, style: finalStyle);
      },
    );
  }
}
