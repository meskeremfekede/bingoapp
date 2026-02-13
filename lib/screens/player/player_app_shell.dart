import 'package:flutter/material.dart';
import 'package:mygame/screens/player/player_games_screen.dart';
import 'package:mygame/screens/player/player_wallet_screen.dart';
import 'package:mygame/screens/player/player_profile_screen.dart'; // Import the new screen
import 'package:mygame/comprehensive_payment_test.dart'; // Import payment test

class PlayerAppShell extends StatefulWidget {
  const PlayerAppShell({super.key});

  @override
  State<PlayerAppShell> createState() => _PlayerAppShellState();
}

class _PlayerAppShellState extends State<PlayerAppShell> {
  int _selectedIndex = 0;

  // Updated the list to use the new PlayerProfileScreen
  static const List<Widget> _playerScreens = <Widget>[
    PlayerGamesScreen(),
    PlayerWalletScreen(),
    PlayerProfileScreen(), // Use the new, data-driven profile screen
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
          BottomNavigationBarItem(
            icon: Icon(Icons.gamepad),
            label: 'Games',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'My Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
