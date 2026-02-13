import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import firestore
import 'package:mygame/screens/login_screen.dart';
import 'package:mygame/screens/player/player_games_screen.dart';
import 'package:mygame/screens/player/player_wallet_screen.dart';
import 'package:mygame/screens/player/completed_games_screen.dart';

class PlayerAppShell extends StatefulWidget {
  const PlayerAppShell({super.key});

  @override
  State<PlayerAppShell> createState() => _PlayerAppShellState();
}

class _PlayerAppShellState extends State<PlayerAppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _playerScreens = <Widget>[
    PlayerGamesScreen(),
    CompletedGamesScreen(),
    PlayerWalletScreen(),
    PlayerProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bingo Game'),
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF0A0A1A),
        elevation: 0,
      ),
      body: Center(
        child: _playerScreens.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0A0A1A),
        selectedItemColor: Colors.purple.shade300,
        unselectedItemColor: Colors.white70,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Games'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'My Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class PlayerProfileScreen extends StatelessWidget {
  const PlayerProfileScreen({super.key});

  String _getRank(double totalWinnings) {
    if (totalWinnings >= 10000) return 'Gold';
    if (totalWinnings >= 5000) return 'Silver';
    if (totalWinnings >= 1000) return 'Bronze';
    return 'Rookie';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not logged in', style: TextStyle(color: Colors.white)));

    // Corrected to use the 'players' collection
    final Stream<QuerySnapshot> transactionsStream = FirebaseFirestore.instance
        .collection('players').doc(user.uid).collection('transactions')
        .where('amount', isGreaterThan: 0)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Player Profile', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Card(
              color: const Color(0xFF1C1C3A),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.email, color: Colors.white70),
                      title: const Text('Email', style: TextStyle(color: Colors.white70)),
                      subtitle: Text(user.email ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const Divider(color: Colors.white24),
                    StreamBuilder<QuerySnapshot>(
                      stream: transactionsStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final totalWinnings = snapshot.data!.docs.fold(0.0, (sum, doc) => sum + (doc['amount'] as num));
                        final rank = _getRank(totalWinnings);

                        return ListTile(
                          leading: const Icon(Icons.military_tech, color: Colors.amber),
                          title: const Text('Rank', style: TextStyle(color: Colors.white70)),
                          subtitle: Text(rank, style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password reset email sent.')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                },
                icon: const Icon(Icons.lock_reset),
                label: const Text('Reset Password'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade300),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
