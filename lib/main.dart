import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mygame/screens/game_screen.dart';
import 'package:mygame/screens/login_screen.dart';
import 'package:mygame/screens/players_screen.dart';
import 'package:mygame/screens/wallet_screen.dart';
import 'package:mygame/screens/admin/admin_profile_screen.dart';
import 'package:mygame/screens/player_app_shell.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mygame',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _isAdmin(User user) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('players').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data()!['role'] as String? ?? 'player') == 'admin';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (authSnapshot.hasData && authSnapshot.data != null) {
          return FutureBuilder<bool>(
            future: _isAdmin(authSnapshot.data!),
            builder: (context, isAdminSnapshot) {
              if (isAdminSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              if (isAdminSnapshot.hasData && isAdminSnapshot.data == true) {
                return const AppShell(); // Admin Dashboard
              } else {
                return const PlayerAppShell(); // Player Dashboard
              }
            },
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    GameScreen(),
    PlayersScreen(),
    WalletScreen(),
    AdminProfileScreen(),
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
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Game'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Players'),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
