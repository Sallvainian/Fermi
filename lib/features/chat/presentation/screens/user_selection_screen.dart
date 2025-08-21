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
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Get users with optimized query - limit to avoid loading too many at once
      final allUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(50) // Limit to avoid loading all users at once
          .get();

      // Filter out current user and process in chunks to avoid blocking UI
      final users = <UserModel>[];
      for (final doc in allUsersSnapshot.docs) {
        if (doc.id != currentUserId) {
          users.add(UserModel.fromFirestore(doc));
        }
        // Yield control back to the UI thread after every 10 users
        if (users.length % 10 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      if (mounted) {
        setState(() {
          _users = users;
          _filteredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = user.displayName?.toLowerCase() ?? '';
        final email = user.email?.toLowerCase() ?? '';
        return name.contains(query) || email.contains(query);
      }).toList();
    });
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
            name: currentUser.displayName ?? '',
            role: '',
          ),
          ParticipantInfo(
            id: otherUser.uid,
            name: otherUser.displayName ?? '',
            role: '',
          ),
        ];

        final chatRoom = await chatProvider.createGroupChat(
          name: otherUser.displayName ?? '',
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
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_search, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'No users found'
                            : 'No users match your search',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.photoURL != null
                            ? NetworkImage(user.photoURL!)
                            : null,
                        child: user.photoURL == null
                            ? Text(user.displayName?.isNotEmpty == true
                                ? user.displayName![0]
                                : '?')
                            : null,
                      ),
                      title: Text(user.displayName ?? 'Unknown User'),
                      subtitle: Text(user.email ?? ''),
                      trailing: Chip(
                        label: Text(
                          user.role?.toString().split('.').last ?? 'user',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      onTap: () => _startChat(user),
                    );
                  },
                ),
    );
  }
}
