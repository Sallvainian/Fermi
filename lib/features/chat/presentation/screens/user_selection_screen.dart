import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/models/user_model.dart';
import '../../domain/models/chat_room.dart';
import '../providers/chat_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart' as app_auth;

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() =>
      _UserSelectionScreenState();
}

class _UserSelectionScreenState
    extends State<UserSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  Timer? _debounceTimer;
  String _searchQuery = '';
  DocumentSnapshot? _lastDocument;
  List<UserModel> _users = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 20;
  
  // Stream for real-time search
  Stream<QuerySnapshot>? _searchStream;

  @override
  void initState() {
    super.initState();
    print('UserSelectionScreen: initState called');
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _initializeSearch();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeSearch() {
    setState(() {
      _searchStream = _buildSearchQuery();
    });
  }

  Stream<QuerySnapshot> _buildSearchQuery() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      print('UserSelectionScreen: No current user ID');
      return const Stream.empty();
    }

    // Simple query - just get all users and filter client-side
    // This avoids Firestore index issues with inequality filters
    Query query = FirebaseFirestore.instance
        .collection('users')
        .orderBy('displayName');

    // For pagination on initial load
    if (_searchQuery.isEmpty && _lastDocument == null) {
      query = query.limit(_pageSize);
    }

    print('UserSelectionScreen: Building query for users');
    return query.snapshots();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
          _users.clear();
          _lastDocument = null;
          _hasMore = true;
          _initializeSearch();
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        _searchQuery.isEmpty) {
      _loadMoreUsers();
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      Query query = FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: currentUserId)
          .orderBy('displayName')
          .limit(_pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();
      
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final newUsers = snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();
        
        setState(() {
          _users.addAll(newUsers);
          _hasMore = snapshot.docs.length == _pageSize;
        });
      } else {
        setState(() {
          _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more users: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  List<UserModel> _filterUsers(List<UserModel> users) {
    if (_searchQuery.isEmpty) return users;
    
    final query = _searchQuery.toLowerCase();
    return users.where((user) {
      final name = user.displayName?.toLowerCase() ?? '';
      final email = user.email?.toLowerCase() ?? '';
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  Future<void> _startChat(UserModel otherUser) async {
    try {
      final chatProvider = context.read<ChatProvider>();
      final authProvider = context.read<app_auth.AuthProvider>();
      final currentUser = authProvider.userModel;

      if (currentUser == null) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Check if a direct chat already exists
      final existingChatRoom = await chatProvider.findDirectChat(otherUser.uid);

      if (existingChatRoom != null) {
        // Navigate to existing chat
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          context.go('/chat/${existingChatRoom.id}');
        }
      } else {
        // Create new chat room
        final participantIds = [currentUser.uid, otherUser.uid];
        final participantInfoList = [
          ParticipantInfo(
            id: currentUser.uid,
            name: currentUser.displayNameOrFallback,
            role: '',
          ),
          ParticipantInfo(
            id: otherUser.uid,
            name: otherUser.displayNameOrFallback,
            role: '',
          ),
        ];

        final chatRoom = await chatProvider.createGroupChat(
          name: otherUser.displayNameOrFallback,
          type: 'direct',
          participantIds: participantIds,
          participants: participantInfoList,
        );

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          context.go('/chat/${chatRoom.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/messages');
            }
          },
        ),
        title: const Text('Select User'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _initializeSearch();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _searchStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeSearch,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Convert documents to UserModel and filter out current user
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          final allUsers = snapshot.data!.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .where((user) => user.uid != currentUserId) // Filter out current user
              .toList();
          
          print('UserSelectionScreen: Loaded ${allUsers.length} users (excluding current user)');
          
          // If not searching, use paginated list; otherwise use filtered stream data
          final displayUsers = _searchQuery.isEmpty ? allUsers : _filterUsers(allUsers);

          // For initial non-search load, populate the users list
          if (_searchQuery.isEmpty && _users.isEmpty && allUsers.isNotEmpty) {
            _users = allUsers.take(_pageSize).toList();
            if (snapshot.data!.docs.isNotEmpty && allUsers.length == _pageSize) {
              _lastDocument = snapshot.data!.docs.last;
            }
          }

          if (displayUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _searchQuery.isEmpty ? Icons.people_outline : Icons.person_search,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No users found'
                        : 'No users match "$_searchQuery"',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Try a different search term',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _users.clear();
                _lastDocument = null;
                _hasMore = true;
                _initializeSearch();
              });
            },
            child: ListView.builder(
              controller: _scrollController,
              itemCount: displayUsers.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == displayUsers.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final user = displayUsers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: user.photoURL == null
                        ? Text(
                            user.displayName?.isNotEmpty == true
                                ? user.displayName![0].toUpperCase()
                                : user.email?.isNotEmpty == true
                                    ? user.email![0].toUpperCase()
                                    : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(user.displayNameOrFallback),
                  subtitle: Text(user.email ?? 'No email'),
                  trailing: Chip(
                    label: Text(
                      user.role?.toString().split('.').last ?? 'user',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  ),
                  onTap: () => _startChat(user),
                );
              },
            ),
          );
        },
      ),
    );
  }
}