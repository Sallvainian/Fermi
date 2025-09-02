# State Management Architecture

## Table of Contents
- [Overview](#overview)
- [Provider Pattern Implementation](#provider-pattern-implementation)
- [Central Provider Configuration](#central-provider-configuration)
- [State Management Patterns](#state-management-patterns)
- [Provider Lifecycle](#provider-lifecycle)
- [Feature-Specific Providers](#feature-specific-providers)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)
- [Performance Considerations](#performance-considerations)
- [Migration Guide](#migration-guide)

## Overview

Fermi uses the **Provider pattern** (version 6.1.5+) for state management, following a centralized configuration with feature-specific providers. This approach provides:

- **Predictable State Flow**: Unidirectional data flow with clear state updates
- **Separation of Concerns**: Business logic separated from UI components
- **Testability**: Providers can be easily mocked and tested
- **Scalability**: Feature-based provider organization scales with application growth
- **Performance**: Efficient widget rebuilding with targeted state updates

### Why Provider Over Other Solutions
- **Simplicity**: Easier learning curve compared to Bloc or Riverpod
- **Flutter Integration**: Native Flutter team recommendation
- **Mature Ecosystem**: Well-established patterns and community support
- **Performance**: Efficient change notification and widget rebuilding

## Provider Pattern Implementation

### Core Provider Structure
```dart
class FeatureProvider extends ChangeNotifier {
  // Private state variables
  List<ItemModel> _items = [];
  bool _isLoading = false;
  String? _error;

  // Public getters (read-only access)
  List<ItemModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  // Repository dependency
  final FeatureRepository _repository;

  FeatureProvider({required FeatureRepository repository})
      : _repository = repository;

  // Business logic methods
  Future<void> loadItems() async {
    _setLoading(true);
    _clearError();
    
    try {
      final items = await _repository.getItems();
      _items = items;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Private state update methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
```

## Central Provider Configuration

### App Providers (`lib/shared/core/app_providers.dart`)

The central provider configuration manages all application-wide providers:

```dart
class AppProviders {
  static Widget create({required Widget child}) {
    return MultiProvider(
      providers: [
        // Authentication
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            repository: FirebaseAuthRepository(),
          ),
        ),

        // Theme Management
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),

        // Notifications
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(
            service: FirebaseNotificationService(),
          ),
        ),

        // Feature-Specific Providers
        ChangeNotifierProvider<AssignmentProvider>(
          create: (_) => AssignmentProvider(
            repository: AssignmentRepositoryImpl(),
          ),
        ),

        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(
            repository: ChatRepositoryImpl(),
          ),
        ),

        ChangeNotifierProvider<ClassProvider>(
          create: (_) => ClassProvider(
            repository: ClassRepositoryImpl(),
          ),
        ),

        // Simplified Providers
        ChangeNotifierProvider<SimpleDiscussionProvider>(
          create: (_) => SimpleDiscussionProvider(),
        ),
      ],
      child: child,
    );
  }
}
```

### Usage in Main App (`lib/main.dart`)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  runApp(
    AppProviders.create(
      child: MyApp(),
    ),
  );
}
```

## State Management Patterns

### 1. Loading States Pattern
```dart
class LoadingStateProvider extends ChangeNotifier {
  LoadingState _state = LoadingState.initial;
  String? _error;
  
  LoadingState get state => _state;
  bool get isLoading => _state == LoadingState.loading;
  bool get hasError => _state == LoadingState.error;
  bool get isSuccess => _state == LoadingState.success;
  String? get error => _error;

  Future<void> executeOperation(Future<void> Function() operation) async {
    _setState(LoadingState.loading);
    
    try {
      await operation();
      _setState(LoadingState.success);
    } catch (e) {
      _setError(e.toString());
    }
  }

  void _setState(LoadingState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _state = LoadingState.error;
    notifyListeners();
  }
}

enum LoadingState { initial, loading, success, error }
```

### 2. List Management Pattern
```dart
class ListManagerProvider<T> extends ChangeNotifier {
  List<T> _items = [];
  Set<String> _selectedIds = {};
  
  List<T> get items => List.unmodifiable(_items);
  List<T> get selectedItems => _items.where((item) => 
    _selectedIds.contains(_getItemId(item))).toList();
  bool get hasSelection => _selectedIds.isNotEmpty;
  int get selectedCount => _selectedIds.length;

  void addItem(T item) {
    _items.add(item);
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => _getItemId(item) == id);
    _selectedIds.remove(id);
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  String _getItemId(T item); // Abstract method to be implemented
}
```

### 3. Form Management Pattern
```dart
class FormProvider extends ChangeNotifier {
  final Map<String, dynamic> _formData = {};
  final Map<String, String> _errors = {};
  bool _isValid = false;

  Map<String, dynamic> get formData => Map.unmodifiable(_formData);
  Map<String, String> get errors => Map.unmodifiable(_errors);
  bool get isValid => _isValid;
  bool get hasErrors => _errors.isNotEmpty;

  void updateField(String key, dynamic value) {
    _formData[key] = value;
    _validateField(key, value);
    _validateForm();
    notifyListeners();
  }

  void _validateField(String key, dynamic value) {
    _errors.remove(key);
    
    final validator = _validators[key];
    if (validator != null) {
      final error = validator(value);
      if (error != null) {
        _errors[key] = error;
      }
    }
  }

  void _validateForm() {
    _isValid = _errors.isEmpty && _requiredFields.every((field) => 
      _formData.containsKey(field) && _formData[field] != null);
  }
}
```

## Provider Lifecycle

### Initialization Flow
```
Application Start → Firebase Init → Provider Creation → Dependency Injection
                                                    → Initial State Setup
                                                    → Ready for UI Consumption
```

### State Update Flow
```
User Action → Provider Method → Repository Call → Firebase Operation
                             → State Update   → notifyListeners()
                             → Widget Rebuild → UI Update
```

### Cleanup Flow
```
Widget Disposal → Provider.dispose() → Stream Subscriptions Cancel
                                    → Resource Cleanup
                                    → Memory Deallocation
```

## Feature-Specific Providers

### Authentication Provider (`AuthProvider`)
```dart
class AuthProvider extends ChangeNotifier {
  User? _user;
  AuthState _authState = AuthState.unknown;
  UserRole? _userRole;

  User? get user => _user;
  AuthState get authState => _authState;
  UserRole? get userRole => _userRole;
  bool get isAuthenticated => _user != null;
  bool get needsEmailVerification => _user != null && !_user!.emailVerified;

  Future<void> signInWithEmail(String email, String password) async {
    _setAuthState(AuthState.loading);
    
    try {
      final credential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await _handleAuthUser(credential.user);
      _setAuthState(AuthState.authenticated);
    } catch (e) {
      _setAuthState(AuthState.error);
      rethrow;
    }
  }

  Future<void> _handleAuthUser(User? user) async {
    _user = user;
    if (user != null) {
      _userRole = await _getUserRole(user.uid);
    }
    notifyListeners();
  }
}
```

### Chat Provider (`ChatProvider`)
```dart
class ChatProvider extends ChangeNotifier {
  List<ChatRoom> _chatRooms = [];
  List<Message> _currentMessages = [];
  StreamSubscription? _messagesSubscription;
  PresenceStatus _presenceStatus = PresenceStatus.offline;

  List<ChatRoom> get chatRooms => _chatRooms;
  List<Message> get currentMessages => _currentMessages;
  PresenceStatus get presenceStatus => _presenceStatus;

  void listenToMessages(String roomId) {
    _messagesSubscription?.cancel();
    _messagesSubscription = _repository
        .getMessagesStream(roomId)
        .listen((messages) {
      _currentMessages = messages;
      notifyListeners();
    });
  }

  Future<void> sendMessage(String roomId, String content) async {
    final message = Message(
      content: content,
      senderId: _authProvider.user!.uid,
      timestamp: DateTime.now(),
    );
    
    await _repository.sendMessage(roomId, message);
    // No need to notify listeners - stream will update automatically
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
```

### Simple Discussion Provider (Simplified Pattern)
```dart
class SimpleDiscussionProvider extends ChangeNotifier {
  List<DiscussionBoard> _boards = [];
  bool _isLoading = false;

  List<DiscussionBoard> get boards => _boards;
  bool get isLoading => _isLoading;

  Future<void> loadBoards() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Direct Firestore call - often more reliable than complex abstractions
      final querySnapshot = await FirebaseFirestore.instance
          .collection('discussion_boards')
          .orderBy('createdAt', descending: true)
          .get();

      _boards = querySnapshot.docs
          .map((doc) => DiscussionBoard.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error loading boards: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

## Best Practices

### 1. Provider Design Principles
- **Single Responsibility**: Each provider manages one specific domain
- **Immutable State**: Expose read-only getters, modify through methods
- **Error Handling**: Always handle and expose errors appropriately
- **Resource Management**: Dispose of streams and subscriptions properly

### 2. State Update Guidelines
```dart
// ✅ Good: Batch related updates
void updateUserProfile(String name, String email) {
  _user = _user.copyWith(name: name, email: email);
  _isProfileComplete = _validateProfile(_user);
  notifyListeners(); // Single notification for related changes
}

// ❌ Bad: Multiple notifications for related changes
void updateUserProfile(String name, String email) {
  _user = _user.copyWith(name: name);
  notifyListeners();
  _user = _user.copyWith(email: email);
  notifyListeners();
  _isProfileComplete = _validateProfile(_user);
  notifyListeners();
}
```

### 3. Consumer Widget Usage
```dart
// ✅ Good: Targeted consumption
Consumer<AuthProvider>(
  builder: (context, authProvider, child) {
    if (authProvider.isLoading) {
      return CircularProgressIndicator();
    }
    
    return Text('Welcome ${authProvider.user?.displayName}');
  },
)

// ✅ Good: Selector for specific properties
Selector<AuthProvider, bool>(
  selector: (context, authProvider) => authProvider.isAuthenticated,
  builder: (context, isAuthenticated, child) {
    return isAuthenticated ? DashboardScreen() : LoginScreen();
  },
)
```

### 4. Provider Testing
```dart
void main() {
  group('AuthProvider Tests', () {
    late AuthProvider authProvider;
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = MockAuthRepository();
      authProvider = AuthProvider(repository: mockRepository);
    });

    test('should update state when signing in successfully', () async {
      // Arrange
      when(mockRepository.signInWithEmail(any, any))
          .thenAnswer((_) async => mockUser);

      // Act
      await authProvider.signInWithEmail('test@test.com', 'password');

      // Assert
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.user, mockUser);
    });
  });
}
```

## Performance Considerations

### 1. Efficient Widget Rebuilding
```dart
// ✅ Good: Use Selector for specific property watching
Selector<ChatProvider, int>(
  selector: (context, chatProvider) => chatProvider.unreadCount,
  builder: (context, unreadCount, child) {
    return Badge(
      count: unreadCount,
      child: Icon(Icons.chat),
    );
  },
)

// ❌ Bad: Entire provider consumption for single property
Consumer<ChatProvider>(
  builder: (context, chatProvider, child) {
    // Rebuilds whenever ANY property in ChatProvider changes
    return Badge(
      count: chatProvider.unreadCount,
      child: Icon(Icons.chat),
    );
  },
)
```

### 2. Lazy Loading and Pagination
```dart
class PaginatedProvider extends ChangeNotifier {
  static const int _pageSize = 20;
  List<Item> _items = [];
  bool _hasMoreItems = true;
  bool _isLoadingMore = false;

  Future<void> loadMoreItems() async {
    if (_isLoadingMore || !_hasMoreItems) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final newItems = await _repository.getItems(
        offset: _items.length,
        limit: _pageSize,
      );

      if (newItems.length < _pageSize) {
        _hasMoreItems = false;
      }

      _items.addAll(newItems);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
```

### 3. Memory Management
```dart
class StreamProvider extends ChangeNotifier {
  StreamSubscription? _subscription;

  void startListening() {
    _subscription = _service.dataStream.listen((data) {
      // Handle data updates
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel(); // Prevent memory leaks
    super.dispose();
  }
}
```

## Common Patterns

### 1. Repository Pattern Integration
```dart
class FeatureProvider extends ChangeNotifier {
  final FeatureRepository _repository;
  
  FeatureProvider({required FeatureRepository repository})
      : _repository = repository;

  Future<void> performAction() async {
    try {
      final result = await _repository.performOperation();
      // Update state based on result
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }
}
```

### 2. Cross-Provider Communication
```dart
class DependentProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  
  DependentProvider({required AuthProvider authProvider})
      : _authProvider = authProvider {
    _authProvider.addListener(_onAuthStateChanged);
  }

  void _onAuthStateChanged() {
    if (_authProvider.isAuthenticated) {
      _loadUserSpecificData();
    } else {
      _clearData();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthStateChanged);
    super.dispose();
  }
}
```

## Migration Guide

### Legacy Provider Migration
The project is gradually migrating from individual provider files to the centralized configuration:

#### Old Pattern (Legacy)
```dart
// lib/features/auth/providers/auth_provider.dart
// Multiple separate provider files scattered across features
```

#### New Pattern (Current)
```dart
// lib/shared/core/app_providers.dart
// Centralized provider configuration with dependency injection
```

### Migration Steps
1. **Identify Legacy Providers**: Find providers not yet in `app_providers.dart`
2. **Update Import Paths**: Change imports to use new provider locations
3. **Add to Central Config**: Include providers in `AppProviders.create()`
4. **Test Integration**: Verify providers work with centralized configuration
5. **Remove Legacy Files**: Clean up old provider files after migration

### Best Practices for New Features
- Always add new providers to `app_providers.dart`
- Use constructor dependency injection for repositories
- Follow the established provider patterns and naming conventions
- Implement proper error handling and loading states
- Include comprehensive documentation and examples

## [Code Examples Section]
[Detailed code examples showing advanced provider patterns and implementations]

## [Troubleshooting Section]
[Common provider issues, debugging techniques, and performance optimization strategies]

## [Testing Strategies Section]
[Comprehensive testing approaches for provider-based state management]