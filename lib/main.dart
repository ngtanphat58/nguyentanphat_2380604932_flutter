
import 'package:flutter/material.dart';

import 'Models/app_models.dart';
import 'Screens/AuthScreen.dart';
import 'Screens/ChildScreen.dart';
import 'Screens/DashboardScreen.dart';
import 'Screens/DeviceScreen.dart';
import 'Screens/ManagementScreen.dart';
import 'Screens/ProfileScreen.dart';
import 'Services/api_client.dart';
import 'themes/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ParentShieldApp());
}

class ParentShieldApp extends StatelessWidget {
  const ParentShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParentShield',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const StartupScreen(),
        '/login': (context) => const AuthScreen(),
        '/home': (context) => const HomeRouterScreen(),
        '/devices': (context) => const DeviceScreen(),
        '/management': (context) => const ManagementScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }
  Future<void> _checkSession() async {
    try {
      final token = await ApiClient.getSavedToken();

      if (!mounted) return;

      // Có phiên đăng nhập: chuyển đến HomeRouterScreen.
      // Chưa có phiên: chuyển đến màn hình đăng nhập.
      if (token != null && token.isNotEmpty) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_rounded,
              size: 68,
              color: AppTheme.primary,
            ),
            SizedBox(height: 18),
            Text(
              'ParentShield',
              style: TextStyle(
                color: AppTheme.navy,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class HomeRouterScreen extends StatefulWidget {
  const HomeRouterScreen({super.key});

  @override
  State<HomeRouterScreen> createState() => _HomeRouterScreenState();
}

class _HomeRouterScreenState extends State<HomeRouterScreen> {
  bool _loading = true;
  bool _isChild = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final userJson = await ApiClient.getSavedUser();

      if (userJson != null) {
        final user = AppUser.fromJson(userJson);

        if (mounted) {
          setState(() {
            _isChild = user.isChild;
            _loading = false;
          });
        }
      } else {
        _goToLogin();
      }
    } catch (_) {
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _isChild
        ? const ChildScreen()
        : const DashboardScreen();
  }
}
