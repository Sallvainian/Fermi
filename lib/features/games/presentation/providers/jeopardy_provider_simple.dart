import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simplified Jeopardy provider - stub implementation
class SimpleJeopardyProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _games = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get games => _games;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load games - stub for now
  Future<void> loadGames() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Stub - would query Firestore when feature is implemented
      _games = [];
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}