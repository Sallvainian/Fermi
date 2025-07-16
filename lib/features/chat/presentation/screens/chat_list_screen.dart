import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../domain/models/chat_room.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      final authProvider = context.read<AuthProvider>();
      chatProvider.setAuthProvider(authProvider);
      chatProvider.initializeChatRooms();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      title: 'Messages',
      showBackButton: true,
      onBackPressed: () => context.go('/dashboard'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            _showSearchDialog();
          },
        ),
        IconButton(
          icon: const Icon(Icons.group_add),
          onPressed: () {
            _showNewChatDialog(context);
          },
        ),
      ],
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${chatProvider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => chatProvider.initializeChatRooms(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final allChatRooms = chatProvider.chatRooms;

          // Filter chat rooms based on search query
          final chatRooms = _searchQuery.isEmpty
              ? allChatRooms
              : allChatRooms.where((room) {
                  return room.name
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      (room.lastMessage
                              ?.toLowerCase()
                              .contains(_searchQuery.toLowerCase()) ??
                          false);
                }).toList();

          if (chatRooms.isEmpty && _searchQuery.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64),
                  const SizedBox(height: 16),
                  Text('No chats found for "$_searchQuery"'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    child: const Text('Clear search'),
                  ),
                ],
              ),
            );
          }

          if (chatRooms.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64),
                  SizedBox(height: 16),
                  Text('No conversations yet'),
                  SizedBox(height: 8),
                  Text('Start a new chat to begin messaging'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoom = chatRooms[index];
              return _buildChatRoomTile(context, chatRoom);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatRoomTile(BuildContext context, ChatRoom chatRoom) {
    final theme = Theme.of(context);
    final hasUnread = chatRoom.unreadCount > 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          chatRoom.name.isNotEmpty ? chatRoom.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chatRoom.name,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (chatRoom.lastMessageTime != null)
            Text(
              _formatTime(chatRoom.lastMessageTime!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasUnread
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              chatRoom.lastMessage ?? 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasUnread
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                chatRoom.unreadCount.toString(),
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        context.read<ChatProvider>().setCurrentChatRoom(chatRoom);
        context.push('/chat/${chatRoom.id}');
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(time);
    } else {
      return DateFormat('dd/MM/yy').format(time);
    }
  }

  void _showNewChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Direct Message'),
              onTap: () {
                Navigator.pop(context);
                context.push('/chat/user-selection');
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Group Chat'),
              onTap: () {
                Navigator.pop(context);
                context.push('/chat/group-creation');
              },
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Class Chat'),
              onTap: () {
                Navigator.pop(context);
                context.push('/chat/class-selection');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Chats'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by name or message content',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
