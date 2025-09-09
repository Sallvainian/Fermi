/// Behavior point management provider with direct Firestore integration.
///
/// Manages behaviors, student points, and awards/deductions with real-time updates.
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/services/logger_service.dart';
import '../../../../shared/models/user_model.dart';

/// Behavior definition model
class Behavior {
  final String id;
  final String name;
  final String description;
  final int defaultPoints;
  final String type; // 'positive' or 'negative'
  final String category;
  final bool isDefault;
  final String? classId;
  final String createdBy;
  final DateTime createdAt;

  Behavior({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultPoints,
    required this.type,
    required this.category,
    this.isDefault = false,
    this.classId,
    required this.createdBy,
    required this.createdAt,
  });

  factory Behavior.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Behavior(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      defaultPoints: data['defaultPoints'] ?? 0,
      type: data['type'] ?? 'positive',
      category: data['category'] ?? 'general',
      isDefault: data['isDefault'] ?? false,
      classId: data['classId'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'defaultPoints': defaultPoints,
      'type': type,
      'category': category,
      'isDefault': isDefault,
      'classId': classId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Student behavior point record
class BehaviorPoint {
  final String id;
  final String studentId;
  final String classId;
  final String behaviorId;
  final String behaviorName;
  final int points;
  final String reason;
  final String awardedBy;
  final String awardedByName;
  final DateTime awardedAt;

  BehaviorPoint({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.behaviorId,
    required this.behaviorName,
    required this.points,
    required this.reason,
    required this.awardedBy,
    required this.awardedByName,
    required this.awardedAt,
  });

  factory BehaviorPoint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BehaviorPoint(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      classId: data['classId'] ?? '',
      behaviorId: data['behaviorId'] ?? '',
      behaviorName: data['behaviorName'] ?? '',
      points: data['points'] ?? 0,
      reason: data['reason'] ?? '',
      awardedBy: data['awardedBy'] ?? '',
      awardedByName: data['awardedByName'] ?? 'Unknown',
      awardedAt: (data['awardedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'classId': classId,
      'behaviorId': behaviorId,
      'behaviorName': behaviorName,
      'points': points,
      'reason': reason,
      'awardedBy': awardedBy,
      'awardedByName': awardedByName,
      'awardedAt': Timestamp.fromDate(awardedAt),
    };
  }
}

/// Student point summary
class StudentPointSummary {
  final String studentId;
  final String studentName;
  final int totalPoints;
  final int positivePoints;
  final int negativePoints;
  final int recordCount;
  final DateTime? lastActivity;

  StudentPointSummary({
    required this.studentId,
    required this.studentName,
    required this.totalPoints,
    required this.positivePoints,
    required this.negativePoints,
    required this.recordCount,
    this.lastActivity,
  });
}

/// Behavior point provider with direct Firestore access
class BehaviorPointProvider with ChangeNotifier {
  static const String _tag = 'BehaviorPointProvider';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  List<Behavior> _behaviors = [];
  List<BehaviorPoint> _behaviorPoints = [];
  Map<String, StudentPointSummary> _studentSummaries = {};
  String? _currentClassId;
  bool _isLoading = false;
  String? _error;

  // Cache for user display name
  String? _cachedDisplayName;
  UserModel? _cachedUserModel;
  DateTime? _cacheTimestamp;
  static const Duration _cacheTTL = Duration(minutes: 5);
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _behaviorsSubscription;
  StreamSubscription<QuerySnapshot>? _behaviorPointsSubscription;

  // Mock data mode (for testing)
  bool _useMockData = true;

  // Default constructor for Provider
  BehaviorPointProvider();

  // Private constructor
  BehaviorPointProvider._();

  /// Factory constructor to handle async initialization
  static Future<BehaviorPointProvider> create() async {
    final provider = BehaviorPointProvider._();
    await provider._loadUserModel();
    return provider;
  }

  // Getters
  List<Behavior> get behaviors => _behaviors;
  List<BehaviorPoint> get behaviorPoints => _behaviorPoints;
  Map<String, StudentPointSummary> get studentSummaries => _studentSummaries;
  String? get currentClassId => _currentClassId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentUserId => _auth.currentUser?.uid ?? '';
  bool get useMockData => _useMockData;

  /// Current user's role (teacher or student)
  String _userRole = 'teacher';
  String get userRole => _userRole;

  /// Toggle mock data mode
  void toggleMockData() {
    _useMockData = !_useMockData;
    if (_currentClassId != null) {
      loadBehaviorsForClass(_currentClassId!);
      loadBehaviorPointsForClass(_currentClassId!);
    }
    notifyListeners();
  }

  /// Returns cached display name or fetches and caches it
  String get currentUserName {
    if (_cachedDisplayName != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheTTL) {
      return _cachedDisplayName!;
    }

    if (_cachedUserModel != null) {
      _cachedDisplayName = _cachedUserModel!.displayNameOrFallback;
      _cacheTimestamp = DateTime.now();
      return _cachedDisplayName!;
    }

    final user = _auth.currentUser;
    if (user != null) {
      final tempUser = UserModel(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
      );
      _cachedDisplayName = tempUser.displayNameOrFallback;
      _cacheTimestamp = DateTime.now();
      return _cachedDisplayName!;
    }

    return 'Unknown User';
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Load and cache the user model for display name
  Future<void> _loadUserModel() async {
    try {
      final userId = currentUserId;
      if (userId.isEmpty) return;

      await _userDocSubscription?.cancel();

      _userDocSubscription = _firestore
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen(
            (snapshot) {
              if (snapshot.exists) {
                _cachedUserModel = UserModel.fromFirestore(snapshot);
                _cachedDisplayName = _cachedUserModel!.displayNameOrFallback;
                _cacheTimestamp = DateTime.now();
                notifyListeners();
              }
            },
            onError: (error) {
              LoggerService.error(
                'Failed to listen to user document',
                tag: _tag,
                error: error,
              );
              final user = _auth.currentUser;
              if (user != null) {
                final tempUser = UserModel(
                  uid: user.uid,
                  email: user.email,
                  displayName: user.displayName,
                );
                _cachedDisplayName = tempUser.displayNameOrFallback;
                _cacheTimestamp = DateTime.now();
              }
            },
          );
    } catch (e) {
      LoggerService.error(
        'Failed to load user model for display name',
        tag: _tag,
        error: e,
      );
      final user = _auth.currentUser;
      if (user != null) {
        final tempUser = UserModel(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
        );
        _cachedDisplayName = tempUser.displayNameOrFallback;
        _cacheTimestamp = DateTime.now();
      }
    }
  }

  /// Clear cached user data
  void clearUserCache() {
    _cachedDisplayName = null;
    _cachedUserModel = null;
    _cacheTimestamp = null;
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
  }

  /// Load behaviors for a specific class
  Future<void> loadBehaviorsForClass(String classId) async {
    _currentClassId = classId;
    _setLoading(true);
    _error = null;

    try {
      if (_useMockData) {
        _behaviors = _generateMockBehaviors(classId);
        _setLoading(false);
        notifyListeners();
        return;
      }

      // Cancel existing subscription
      await _behaviorsSubscription?.cancel();

      // Listen to behaviors for this class (default + class-specific)
      _behaviorsSubscription = _firestore
          .collection('behaviors')
          .where('isDefault', isEqualTo: true)
          .snapshots()
          .listen(
            (defaultSnapshot) async {
              // Also get class-specific behaviors
              final classSnapshot = await _firestore
                  .collection('behaviors')
                  .where('classId', isEqualTo: classId)
                  .get();

              final allDocs = [...defaultSnapshot.docs, ...classSnapshot.docs];
              _behaviors = allDocs
                  .map((doc) => Behavior.fromFirestore(doc))
                  .toList();

              // Sort behaviors by type (positive first) and then by name
              _behaviors.sort((a, b) {
                if (a.type != b.type) {
                  return a.type == 'positive' ? -1 : 1;
                }
                return a.name.compareTo(b.name);
              });

              LoggerService.debug(
                'Loaded ${_behaviors.length} behaviors for class $classId',
                tag: _tag,
              );

              _setLoading(false);
              notifyListeners();
            },
            onError: (error) {
              LoggerService.error(
                'Failed to load behaviors for class $classId',
                tag: _tag,
                error: error,
              );
              _error = 'Failed to load behaviors';
              _setLoading(false);
              notifyListeners();
            },
          );
    } catch (e) {
      LoggerService.error(
        'Failed to setup behavior listener',
        tag: _tag,
        error: e,
      );
      _error = 'Failed to load behaviors';
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Load behavior points for a specific class
  Future<void> loadBehaviorPointsForClass(String classId) async {
    try {
      if (_useMockData) {
        _behaviorPoints = _generateMockBehaviorPoints(classId);
        _calculateStudentSummaries();
        notifyListeners();
        return;
      }

      // Cancel existing subscription
      await _behaviorPointsSubscription?.cancel();

      // Listen to behavior points for this class
      _behaviorPointsSubscription = _firestore
          .collection('behavior_points')
          .where('classId', isEqualTo: classId)
          .orderBy('awardedAt', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              _behaviorPoints = snapshot.docs
                  .map((doc) => BehaviorPoint.fromFirestore(doc))
                  .toList();

              LoggerService.debug(
                'Loaded ${_behaviorPoints.length} behavior points for class $classId',
                tag: _tag,
              );

              _calculateStudentSummaries();
              notifyListeners();
            },
            onError: (error) {
              LoggerService.error(
                'Failed to load behavior points for class $classId',
                tag: _tag,
                error: error,
              );
            },
          );
    } catch (e) {
      LoggerService.error(
        'Failed to setup behavior points listener',
        tag: _tag,
        error: e,
      );
    }
  }

  /// Award points to a student
  Future<void> awardPoints({
    required String studentId,
    required String behaviorId,
    required int points,
    String? customReason,
  }) async {
    if (_currentClassId == null) return;

    _setLoading(true);
    _error = null;

    try {
      final behavior = _behaviors.firstWhere((b) => b.id == behaviorId);
      final studentName = await _getStudentName(studentId);
      final teacherName = currentUserName;

      final behaviorPoint = BehaviorPoint(
        id: '', // Will be set by Firestore
        studentId: studentId,
        classId: _currentClassId!,
        behaviorId: behaviorId,
        behaviorName: behavior.name,
        points: points,
        reason: customReason ?? behavior.description,
        awardedBy: currentUserId,
        awardedByName: teacherName,
        awardedAt: DateTime.now(),
      );

      if (_useMockData) {
        // Add to mock data
        _behaviorPoints.insert(0, behaviorPoint.copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        ));
        _calculateStudentSummaries();
      } else {
        await _firestore
            .collection('behavior_points')
            .add(behaviorPoint.toFirestore());
      }

      LoggerService.info(
        'Awarded $points points to student $studentId for behavior ${behavior.name}',
        tag: _tag,
      );

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to award points', tag: _tag, error: e);
      _error = 'Failed to award points';
      _setLoading(false);
      notifyListeners();
      rethrow;
    }
  }

  /// Remove/deduct points from a student
  Future<void> removePoints({
    required String studentId,
    required String behaviorId,
    required int points,
    String? customReason,
  }) async {
    if (_currentClassId == null) return;

    final negativePoints = -points.abs(); // Ensure negative
    await awardPoints(
      studentId: studentId,
      behaviorId: behaviorId,
      points: negativePoints,
      customReason: customReason,
    );
  }

  /// Create a custom behavior
  Future<void> createCustomBehavior({
    required String name,
    required String description,
    required int defaultPoints,
    required String type,
    String category = 'custom',
  }) async {
    if (_currentClassId == null) return;

    _setLoading(true);
    _error = null;

    try {
      final behavior = Behavior(
        id: '', // Will be set by Firestore
        name: name,
        description: description,
        defaultPoints: defaultPoints,
        type: type,
        category: category,
        isDefault: false,
        classId: _currentClassId,
        createdBy: currentUserId,
        createdAt: DateTime.now(),
      );

      if (_useMockData) {
        // Add to mock data
        _behaviors.add(behavior.copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        ));
        // Re-sort behaviors
        _behaviors.sort((a, b) {
          if (a.type != b.type) {
            return a.type == 'positive' ? -1 : 1;
          }
          return a.name.compareTo(b.name);
        });
      } else {
        await _firestore.collection('behaviors').add(behavior.toFirestore());
      }

      LoggerService.info('Created custom behavior: $name', tag: _tag);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to create custom behavior', tag: _tag, error: e);
      _error = 'Failed to create behavior';
      _setLoading(false);
      notifyListeners();
      rethrow;
    }
  }

  /// Calculate total points for the class
  int calculateClassTotalPoints() {
    return _behaviorPoints.fold(0, (sum, point) => sum + point.points);
  }

  /// Get behavior points for a specific student
  List<BehaviorPoint> getBehaviorPointsForStudent(String studentId) {
    return _behaviorPoints.where((p) => p.studentId == studentId).toList();
  }

  /// Get positive behaviors
  List<Behavior> get positiveBehaviors => 
      _behaviors.where((b) => b.type == 'positive').toList();

  /// Get negative behaviors
  List<Behavior> get negativeBehaviors => 
      _behaviors.where((b) => b.type == 'negative').toList();

  /// Calculate student summaries from behavior points
  void _calculateStudentSummaries() {
    final summaries = <String, StudentPointSummary>{};

    // Group points by student
    final studentPoints = <String, List<BehaviorPoint>>{};
    for (final point in _behaviorPoints) {
      studentPoints.putIfAbsent(point.studentId, () => []).add(point);
    }

    // Calculate summaries for each student
    for (final entry in studentPoints.entries) {
      final studentId = entry.key;
      final points = entry.value;

      final totalPoints = points.fold(0, (sum, p) => sum + p.points);
      final positivePoints = points.where((p) => p.points > 0).fold(0, (sum, p) => sum + p.points);
      final negativePoints = points.where((p) => p.points < 0).fold(0, (sum, p) => sum + p.points);
      
      final lastActivity = points.isNotEmpty 
          ? points.reduce((a, b) => a.awardedAt.isAfter(b.awardedAt) ? a : b).awardedAt
          : null;

      summaries[studentId] = StudentPointSummary(
        studentId: studentId,
        studentName: _getStudentNameSync(studentId),
        totalPoints: totalPoints,
        positivePoints: positivePoints,
        negativePoints: negativePoints,
        recordCount: points.length,
        lastActivity: lastActivity,
      );
    }

    _studentSummaries = summaries;
  }

  /// Get student name (async)
  Future<String> _getStudentName(String studentId) async {
    try {
      // Try to get from cached summaries first
      if (_studentSummaries.containsKey(studentId)) {
        return _studentSummaries[studentId]!.studentName;
      }

      if (_useMockData) {
        final mockNames = ['Alice Johnson', 'Bob Smith', 'Charlie Brown', 'Diana Prince', 'Emma Watson'];
        final index = int.parse(studentId.substring(studentId.length - 1)) % mockNames.length;
        return mockNames[index];
      }

      // Get from Firestore
      final userDoc = await _firestore.collection('users').doc(studentId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final firstName = data['firstName'] as String?;
        final lastName = data['lastName'] as String?;
        if (firstName != null && lastName != null) {
          return '$firstName $lastName'.trim();
        }
        return data['displayName'] ?? data['email']?.split('@').first ?? 'Unknown Student';
      }
      return 'Unknown Student';
    } catch (e) {
      LoggerService.error('Failed to get student name', tag: _tag, error: e);
      return 'Unknown Student';
    }
  }

  /// Get student name (sync version for internal use)
  String _getStudentNameSync(String studentId) {
    if (_useMockData) {
      final mockNames = ['Alice Johnson', 'Bob Smith', 'Charlie Brown', 'Diana Prince', 'Emma Watson'];
      final index = int.parse(studentId.substring(studentId.length - 1)) % mockNames.length;
      return mockNames[index];
    }
    return 'Student $studentId';
  }

  /// Generate mock behaviors for testing
  List<Behavior> _generateMockBehaviors(String classId) {
    final now = DateTime.now();
    final random = Random();

    return [
      // Positive behaviors
      Behavior(
        id: 'pos1',
        name: 'Excellent Participation',
        description: 'Active participation in class discussions',
        defaultPoints: 10,
        type: 'positive',
        category: 'participation',
        isDefault: true,
        createdBy: 'system',
        createdAt: now.subtract(Duration(days: 30)),
      ),
      Behavior(
        id: 'pos2',
        name: 'Homework Completed',
        description: 'Completed homework on time',
        defaultPoints: 5,
        type: 'positive',
        category: 'academic',
        isDefault: true,
        createdBy: 'system',
        createdAt: now.subtract(Duration(days: 30)),
      ),
      Behavior(
        id: 'pos3',
        name: 'Helping Others',
        description: 'Helped a classmate with their work',
        defaultPoints: 8,
        type: 'positive',
        category: 'social',
        isDefault: true,
        createdBy: 'system',
        createdAt: now.subtract(Duration(days: 30)),
      ),
      Behavior(
        id: 'pos4',
        name: 'Leadership',
        description: 'Showed leadership during group activities',
        defaultPoints: 12,
        type: 'positive',
        category: 'leadership',
        isDefault: true,
        createdBy: 'system',
        createdAt: now.subtract(Duration(days: 30)),
      ),
      
      // Negative behaviors
      Behavior(
        id: 'neg1',
        name: 'Late to Class',
        description: 'Arrived late to class',
        defaultPoints: -3,
        type: 'negative',
        category: 'attendance',
        isDefault: true,
        createdBy: 'system',
        createdAt: now.subtract(Duration(days: 30)),
      ),
      Behavior(
        id: 'neg2',
        name: 'Missing Homework',
        description: 'Failed to submit homework',
        defaultPoints: -5,
        type: 'negative',
        category: 'academic',
        isDefault: true,
        createdBy: 'system',
        createdAt: now.subtract(Duration(days: 30)),
      ),
      Behavior(
        id: 'neg3',
        name: 'Disruptive Behavior',
        description: 'Disrupted class or other students',
        defaultPoints: -8,
        type: 'negative',
        category: 'behavior',
        isDefault: true,
        createdBy: 'system',
        createdAt: now.subtract(Duration(days: 30)),
      ),

      // Custom class behavior
      Behavior(
        id: 'custom1',
        name: 'Extra Credit Project',
        description: 'Completed optional extra credit assignment',
        defaultPoints: 15,
        type: 'positive',
        category: 'custom',
        isDefault: false,
        classId: classId,
        createdBy: currentUserId,
        createdAt: now.subtract(Duration(days: 5)),
      ),
    ];
  }

  /// Generate mock behavior points for testing
  List<BehaviorPoint> _generateMockBehaviorPoints(String classId) {
    final random = Random();
    final studentIds = ['student1', 'student2', 'student3', 'student4', 'student5'];
    final behaviorIds = ['pos1', 'pos2', 'pos3', 'pos4', 'neg1', 'neg2', 'neg3', 'custom1'];
    final points = <BehaviorPoint>[];

    // Generate 50 random behavior point records
    for (int i = 0; i < 50; i++) {
      final studentId = studentIds[random.nextInt(studentIds.length)];
      final behaviorId = behaviorIds[random.nextInt(behaviorIds.length)];
      final behavior = _behaviors.firstWhere((b) => b.id == behaviorId, 
          orElse: () => _behaviors.first);

      points.add(BehaviorPoint(
        id: 'point_$i',
        studentId: studentId,
        classId: classId,
        behaviorId: behaviorId,
        behaviorName: behavior.name,
        points: behavior.defaultPoints + random.nextInt(5) - 2, // Add some variation
        reason: behavior.description,
        awardedBy: currentUserId,
        awardedByName: currentUserName,
        awardedAt: DateTime.now().subtract(Duration(days: random.nextInt(30))),
      ));
    }

    // Sort by date descending
    points.sort((a, b) => b.awardedAt.compareTo(a.awardedAt));
    return points;
  }

  /// Clean up resources
  @override
  void dispose() {
    _behaviorsSubscription?.cancel();
    _behaviorPointsSubscription?.cancel();
    _userDocSubscription?.cancel();
    clearUserCache();
    super.dispose();
  }
}

/// Extension to help with copying BehaviorPoint with new ID
extension BehaviorPointCopy on BehaviorPoint {
  BehaviorPoint copyWith({
    String? id,
    String? studentId,
    String? classId,
    String? behaviorId,
    String? behaviorName,
    int? points,
    String? reason,
    String? awardedBy,
    String? awardedByName,
    DateTime? awardedAt,
  }) {
    return BehaviorPoint(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      classId: classId ?? this.classId,
      behaviorId: behaviorId ?? this.behaviorId,
      behaviorName: behaviorName ?? this.behaviorName,
      points: points ?? this.points,
      reason: reason ?? this.reason,
      awardedBy: awardedBy ?? this.awardedBy,
      awardedByName: awardedByName ?? this.awardedByName,
      awardedAt: awardedAt ?? this.awardedAt,
    );
  }
}

/// Extension to help with copying Behavior with new ID
extension BehaviorCopy on Behavior {
  Behavior copyWith({
    String? id,
    String? name,
    String? description,
    int? defaultPoints,
    String? type,
    String? category,
    bool? isDefault,
    String? classId,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Behavior(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      defaultPoints: defaultPoints ?? this.defaultPoints,
      type: type ?? this.type,
      category: category ?? this.category,
      isDefault: isDefault ?? this.isDefault,
      classId: classId ?? this.classId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}