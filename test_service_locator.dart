import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';
import 'lib/core/service_locator.dart';
import 'lib/services/calendar_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
    
    print('Setting up service locator...');
    await setupServiceLocator();
    print('Service locator setup successfully');
    
    print('Testing CalendarService registration...');
    final calendarService = getIt<CalendarService>();
    print('CalendarService retrieved successfully: $calendarService');
    
    print('\nAll services registered:');
    print('FirebaseAuth: ${getIt.isRegistered<FirebaseAuth>()}');
    print('FirebaseFirestore: ${getIt.isRegistered<FirebaseFirestore>()}');
    print('CalendarRepository: ${getIt.isRegistered<CalendarRepository>()}');
    print('UserRepository: ${getIt.isRegistered<UserRepository>()}');
    print('ClassRepository: ${getIt.isRegistered<ClassRepository>()}');
    print('CalendarService: ${getIt.isRegistered<CalendarService>()}');
    
  } catch (e, stack) {
    print('Error: $e');
    print('Stack trace: $stack');
  }
}