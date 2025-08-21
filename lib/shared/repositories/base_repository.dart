/// Base repository pattern for data access layer abstraction.
///
/// This abstract class defines the foundation for all repository
/// implementations in the education platform, providing a consistent
/// interface for resource management across different data sources.
library;

/// Base repository interface that all repositories should implement.
///
/// Repositories in this application follow the Repository pattern to:
/// - Abstract data access logic from business logic
/// - Enable easy switching between data sources
/// - Facilitate unit testing with mock implementations
/// - Provide a consistent API for data operations
///
/// All concrete repository implementations should extend this class
/// and implement domain-specific data access methods while inheriting
/// the common resource management functionality.
///
/// Example implementation:
/// ```dart
/// class UserRepository extends BaseRepository {
///   final FirebaseFirestore _firestore;
///   StreamSubscription? _subscription;
///
///   UserRepository(this._firestore);
///
///   Stream<User> getUser(String id) { ... }
///
///   @override
///   void dispose() {
///     _subscription?.cancel();
///     super.dispose();
///   }
/// }
/// ```
abstract class BaseRepository {
  /// Clean up any resources used by the repository.
  ///
  /// Override this method in concrete implementations to:
  /// - Cancel stream subscriptions
  /// - Close database connections
  /// - Clear caches or temporary data
  /// - Release any held resources
  ///
  /// Always call super.dispose() when overriding to ensure
  /// proper cleanup chain execution.
  void dispose() {}
}
