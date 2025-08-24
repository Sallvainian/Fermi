import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class SimpleUserList extends StatelessWidget {
  const SimpleUserList({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('DEBUG: SimpleUserList build() called');
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('DEBUG: Current user ID: $currentUserId');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a User'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs
              .where((doc) => doc.id != currentUserId) // Don't show current user
              .toList();

          if (users.isEmpty) {
            return const Center(
              child: Text('No users found'),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              final displayName = user['displayName'] ?? user['email'] ?? 'User $userId';
              
              return ListTile(
                leading: CircleAvatar(
                  child: Text(displayName[0].toUpperCase()),
                ),
                title: Text(displayName),
                subtitle: Text(user['email'] ?? ''),
                onTap: () async {
                  // Check if chat exists
                  final currentUser = FirebaseAuth.instance.currentUser!;
                  
                  // Look for existing chat
                  final existingChats = await FirebaseFirestore.instance
                      .collection('chatRooms')
                      .where('type', isEqualTo: 'direct')
                      .where('participantIds', arrayContains: currentUser.uid)
                      .get();
                  
                  String? existingChatId;
                  for (var chat in existingChats.docs) {
                    final participants = List<String>.from(chat.data()['participantIds']);
                    if (participants.contains(userId) && participants.length == 2) {
                      existingChatId = chat.id;
                      break;
                    }
                  }
                  
                  if (existingChatId != null) {
                    // Go to existing chat
                    if (context.mounted) {
                      context.go('/simple-chat/$existingChatId?title=${Uri.encodeComponent(displayName)}');
                    }
                  } else {
                    // Create new chat
                    final newChat = await FirebaseFirestore.instance.collection('chatRooms').add({
                      'type': 'direct',
                      'participantIds': [currentUser.uid, userId],
                      'participants': [
                        {
                          'id': currentUser.uid,
                          'name': currentUser.displayName ?? currentUser.email ?? 'You',
                          'role': '',
                        },
                        {
                          'id': userId,
                          'name': displayName,
                          'role': '',
                        },
                      ],
                      'createdAt': FieldValue.serverTimestamp(),
                      'createdBy': currentUser.uid,
                      'lastMessage': null,
                      'lastMessageTime': null,
                      'lastMessageSenderId': null,
                    });
                    
                    if (context.mounted) {
                      context.go('/simple-chat/${newChat.id}?title=${Uri.encodeComponent(displayName)}');
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}