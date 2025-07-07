import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teacher_dashboard_flutter/firebase_options.dart';
import 'package:teacher_dashboard_flutter/core/service_locator.dart';
import 'package:teacher_dashboard_flutter/services/calendar_service.dart';
import 'package:teacher_dashboard_flutter/repositories/calendar_repository.dart';
import 'package:teacher_dashboard_flutter/repositories/user_repository.dart';
import 'package:teacher_dashboard_flutter/repositories/class_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Setup service locator
    await setupServiceLocator();
    
    
    
    // Check all services registered
    debugPrint('\nAll services registered:');
    debugPrint('FirebaseAuth: ${getIt.isRegistered<FirebaseAuth>()}');
    debugPrint('FirebaseFirestore: ${getIt.isRegistered<FirebaseFirestore>()}');
    debugPrint('CalendarRepository: ${getIt.isRegistered<CalendarRepository>()}');
    debugPrint('UserRepository: ${getIt.isRegistered<UserRepository>()}');
    debugPrint('ClassRepository: ${getIt.isRegistered<ClassRepository>()}');
    debugPrint('CalendarService: ${getIt.isRegistered<CalendarService>()}');
    
  } catch (e, stack) {
    debugPrint('Error: $e');
    debugPrint('Stack trace: $stack');
  }
}