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
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (state == AppLifecycleState.resumed) {
      // App coming to foreground - check if we need to lock
      final backgroundTime = prefs.getInt('background_time');
      
      if (backgroundTime != null) {
        final backgroundDateTime = DateTime.fromMillisecondsSinceEpoch(backgroundTime);
        final now = DateTime.now();
        final difference = now.difference(backgroundDateTime);
        
        if (difference.inMinutes >= 15) {
          // Been away for 15+ minutes, require password
          await prefs.setBool('app_unlocked', false);
          setState(() {
            _isUnlocked = false;
          });
        }
        // Clear the background time since we're now active
        await prefs.remove('background_time');
      }
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.inactive) {
      // App going to background - just save the timestamp, don't lock yet
      await prefs.setInt('background_time', DateTime.now().millisecondsSinceEpoch);
    }
  }
  
  Future<void> _checkUnlockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isUnlocked = prefs.getBool('app_unlocked') ?? false;
    
    setState(() {
      _isUnlocked = isUnlocked;
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