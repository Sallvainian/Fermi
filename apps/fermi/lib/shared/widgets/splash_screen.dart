import 'package:flutter/material.dart';

/// Splash screen shown during app initialization
class SplashScreen extends StatelessWidget {
  final String? message;
  final double? progress;

  const SplashScreen({
    super.key,
    this.message,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or icon
              const Icon(
                Icons.school,
                size: 80,
                color: Color(0xFF2196F3),
              ),
              const SizedBox(height: 24),

              // App title
              const Text(
                'Teacher Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 48),

              // Progress indicator
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    if (progress != null)
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                      )
                    else
                      const CircularProgressIndicator(),
                    const SizedBox(height: 16),

                    // Status message
                    Text(
                      message ?? 'Loading...',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF757575),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
