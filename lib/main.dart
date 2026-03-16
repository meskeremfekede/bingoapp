import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _isAdmin = false;
  bool _isLoading = true;
  bool _hasCheckedAdmin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAdminStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed && _hasCheckedAdmin) {
      // App resumed - refresh admin status from cache first
      _loadAdminStatus();
    }
  }

  Future<void> _loadAdminStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAdminStatus = prefs.getBool('isAdmin') ?? false;
      
      setState(() {
        _isAdmin = cachedAdminStatus;
        _isLoading = false;
      });

      // Verify with Firebase in background
      _verifyAdminStatusWithFirebase();
    } catch (e) {
      debugPrint('🔍 AuthWrapper: Error loading admin status: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAdminStatusWithFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('players').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          final isAdminUser = (data['isAdmin'] as bool? ?? false) == true || 
                             (data['role'] as String? ?? 'player') == 'admin';
          
          // Cache the result
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isAdmin', isAdminUser);
          
          if (mounted && isAdminUser != _isAdmin) {
            setState(() => _isAdmin = isAdminUser);
          }
          
          _hasCheckedAdmin = true;
          debugPrint('🔍 AuthWrapper: Admin status verified: $isAdminUser');
        }
      }
    } catch (e) {
      debugPrint('🔍 AuthWrapper: Firebase admin check failed: $e');
    }
  }

  Future<void> _clearAdminCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isAdmin');
      setState(() {
        _isAdmin = false;
        _hasCheckedAdmin = false;
      });
    } catch (e) {
      debugPrint('🔍 AuthWrapper: Error clearing admin cache: $e');
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
          // User is logged in
          if (_isLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          // Use cached admin status first, then verify in background
          if (_isAdmin) {
            return const AppShell(); // Admin Dashboard
          } else {
            return const PlayerAppShell(); // Player Dashboard
          }
        } else {
          // User logged out - clear admin cache
          _clearAdminCache();
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
