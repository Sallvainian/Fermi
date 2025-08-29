import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/presentation/screens/app_password_screen.dart';

class AppPasswordWrapper extends StatefulWidget {
  final Widget child;
  
  const AppPasswordWrapper({
    super.key,
    required this.child,
  });

  @override
  State<AppPasswordWrapper> createState() => _AppPasswordWrapperState();
}

class _AppPasswordWrapperState extends State<AppPasswordWrapper> with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _isChecking = true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkUnlockStatus();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check when app comes to foreground
      _checkUnlockStatus();
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.inactive) {
      // Lock app when it goes to background
      _lockApp();
    }
  }
  
  Future<void> _checkUnlockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isUnlocked = prefs.getBool('app_unlocked') ?? false;
    final unlockTime = prefs.getInt('unlock_time');
    
    bool shouldRemainUnlocked = false;
    
    if (isUnlocked && unlockTime != null) {
      // Check if unlock is still valid (expires after 4 hours)
      final unlockDateTime = DateTime.fromMillisecondsSinceEpoch(unlockTime);
      final now = DateTime.now();
      final difference = now.difference(unlockDateTime);
      
      if (difference.inHours < 4) {
        shouldRemainUnlocked = true;
      } else {
        // Session expired, need to re-authenticate
        await prefs.setBool('app_unlocked', false);
      }
    }
    
    setState(() {
      _isUnlocked = shouldRemainUnlocked;
      _isChecking = false;
    });
  }
  
  Future<void> _lockApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_unlocked', false);
    
    if (mounted) {
      setState(() {
        _isUnlocked = false;
      });
    }
  }
  
  void _onPasswordSuccess() {
    setState(() {
      _isUnlocked = true;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // Show loading indicator while checking unlock status
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    if (!_isUnlocked) {
      // Show password screen
      return MaterialApp(
        title: 'Fermi+',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: AppPasswordScreen(
          onSuccess: _onPasswordSuccess,
        ),
      );
    }
    
    // App is unlocked, show the main content
    return widget.child;
  }
}