import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';

class GroupCreationScreen extends StatefulWidget {
  const GroupCreationScreen({super.key});

  @override
  State<GroupCreationScreen> createState() => _GroupCreationScreenState();
}

class _GroupCreationScreenState extends State<GroupCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<UserModel> _selectedUsers = {};
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final currentUserId = context.read<AuthProvider>().userModel?.uid;
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => user.uid != currentUserId)
          .toList();

      setState(() {
        _searchResults = users;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching users: $e')));
      }
    }
  }

  Future<void> _createGroupChat() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one user')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final currentUser = context.read<AuthProvider>().userModel!;
      final chatProvider = context.read<SimpleChatProvider>();

      // Prepare participants list
      final participantIds = [
        currentUser.uid,
        ..._selectedUsers.map((u) => u.uid),
      ];
      final participants = [
        {
          'id': currentUser.uid,
          'name': currentUser.name,
          'role': currentUser.role?.name ?? 'user',
          'photoUrl': currentUser.photoUrl,
        },
        ..._selectedUsers.map(
          (user) => {
            'id': user.uid,
            'name': user.name,
            'role': user.role?.name ?? 'user',
            'photoUrl': user.photoUrl,
          },
        ),
      ];

      final chatRoom = await chatProvider.createGroupChat(
        name: _groupNameController.text.trim(),
        type: 'group',
        participantIds: participantIds,
        participants: participants,
      );

      if (mounted) {
        context.go('/chat/${chatRoom['id']}');
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Create Group Chat',
      showBackButton: true,
      onBackPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/messages');
        }
      },
      actions: [
        TextButton(
          onPressed: _isCreating ? null : _createGroupChat,
          child: const Text('Create'),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'Enter group name',
                  prefixIcon: Icon(Icons.group),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Users',
                  hintText: 'Search by name',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: (value) => _searchUsers(value),
              ),
            ),
            if (_selectedUsers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _selectedUsers.elementAt(index);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        avatar: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            user.name[0].toUpperCase(),
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        label: Text(user.name),
                        onDeleted: () {
                          setState(() => _selectedUsers.remove(user));
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  final isSelected = _selectedUsers.contains(user);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: user.photoUrl != null
                          ? CachedNetworkImageProvider(user.photoUrl!)
                          : null,
                      child: user.photoUrl == null
                          ? Text(
                              user.name[0].toUpperCase(),
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                    title: Text(user.name),
                    subtitle: Text(user.role?.name ?? 'user'),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value ?? false) {
                            _selectedUsers.add(user);
                          } else {
                            _selectedUsers.remove(user);
                          }
                        });
                      },
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedUsers.remove(user);
                        } else {
                          _selectedUsers.add(user);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
