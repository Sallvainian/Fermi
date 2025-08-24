import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/chat_provider_simple.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
      final chatProvider = context.read<SimpleChatProvider>();
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
      body: Consumer<SimpleChatProvider>(
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
                  final authProvider = context.read<AuthProvider>();
                  final currentUserId = authProvider.userModel?.uid ?? '';
                  final displayName = _getDisplayName(room, currentUserId);

                  return displayName
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      (room['lastMessage']
                              ?.toString()
                              .toLowerCase()
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 64),
                  const SizedBox(height: 16),
                  const Text('No conversations yet'),
                  const SizedBox(height: 8),
                  const Text('Start a new chat to begin messaging'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showNewChatDialog(context),
                    icon: const Icon(Icons.add_comment),
                    label: const Text('Start Your First Chat'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
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

  Widget _buildChatRoomTile(BuildContext context, Map<String, dynamic> chatRoom) {
    final theme = Theme.of(context);
    final hasUnread = (chatRoom['unreadCount'] ?? 0) > 0;
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userModel?.uid ?? '';

    // Get the display name and photo for this chat room from current user's perspective
    final String displayName = _getDisplayName(chatRoom, currentUserId);
    final String? displayPhotoUrl = _getDisplayPhotoUrl(chatRoom, currentUserId);

    return Dismissible(
      key: Key(chatRoom['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Chat'),
              content: Text('Are you sure you want to delete this chat with $displayName? This action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) async {
        await _deleteChat(chatRoom['id']);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chat with $displayName deleted'),
            ),
          );
        }
      },
      child: ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: displayPhotoUrl != null
            ? CachedNetworkImageProvider(displayPhotoUrl)
            : null,
        child: displayPhotoUrl == null
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (chatRoom['lastMessageTime'] != null)
            Text(
              _formatTime(chatRoom['lastMessageTime'].toDate()),
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
              chatRoom['lastMessage'] ?? 'No messages yet',
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
                (chatRoom['unreadCount'] ?? 0).toString(),
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
        context.read<SimpleChatProvider>().setCurrentChatRoom(chatRoom);
        // Use the new simple chat screen that actually works
        context.push(
            '/simple-chat/${chatRoom['id']}?title=${Uri.encodeComponent(displayName)}');
      },
      onLongPress: () {
        // Option to use old chat screen if needed
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Choose Chat Version'),
            content: const Text('Which chat interface would you like to use?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.push('/chat/${chatRoom['id']}');
                },
                child: const Text('Original (may have issues)'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.push(
                      '/simple-chat/${chatRoom['id']}?title=${Uri.encodeComponent(displayName)}');
                },
                child: const Text('Simple (recommended)'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _deleteChat(chatRoom['id']).then((_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Chat with $displayName deleted'),
                        ),
                      );
                    }
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Delete Chat'),
              ),
            ],
          ),
        );
      },
      ),
    );
  }
  
  Future<void> _deleteChat(String chatRoomId) async {
    try {
      // Use the provider's delete method which properly updates local state
      final chatProvider = context.read<SimpleChatProvider>();
      await chatProvider.deleteChatRoom(chatRoomId);
      debugPrint('Chat room $chatRoomId deleted successfully');
    } catch (e) {
      debugPrint('Error deleting chat: $e');
      rethrow;
    }
  }

  String _getDisplayName(Map<String, dynamic> chatRoom, String currentUserId) {
    // For direct chats, show the other participant's name
    if (chatRoom['type'] == 'direct') {
      // First check participantNames (new structure)
      final participantNames = chatRoom['participantNames'] as Map<String, dynamic>?;
      if (participantNames != null) {
        for (var entry in participantNames.entries) {
          if (entry.key != currentUserId) {
            return entry.value ?? 'Unknown User';
          }
        }
      }
      
      // Then check participants array (legacy structure)
      final participants = chatRoom['participants'] as List<dynamic>?;
      if (participants != null) {
        for (var participant in participants) {
          if (participant is Map<String, dynamic> && 
              participant['uid'] != currentUserId) {
            return participant['displayName'] ?? participant['email'] ?? 'Unknown User';
          }
        }
      }
      // Fallback: use participantIds if participants array not available
      final participantIds = chatRoom['participantIds'] as List<dynamic>?;
      if (participantIds != null && participantIds.length == 2) {
        final otherUserId = participantIds.firstWhere(
          (id) => id != currentUserId,
          orElse: () => null,
        );
        return chatRoom['name'] ?? otherUserId ?? 'Direct Chat';
      }
    }
    
    // For group/class chats, use the chat room name
    return chatRoom['name'] ?? 'Unnamed Chat';
  }

  String? _getDisplayPhotoUrl(Map<String, dynamic> chatRoom, String currentUserId) {
    // For direct chats, show the other participant's photo
    if (chatRoom['type'] == 'direct') {
      final participants = chatRoom['participants'] as List<dynamic>?;
      if (participants != null) {
        for (var participant in participants) {
          if (participant is Map<String, dynamic> && 
              participant['uid'] != currentUserId) {
            return participant['photoUrl'];
          }
        }
      }
    }
    
    // For group/class chats, could return a default group icon URL
    return null;
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

  void _showNewChatDialog(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Direct Message'),
              onTap: () {
                debugPrint('DEBUG: Direct Message clicked');
                // Close dialog FIRST
                Navigator.of(dialogContext).pop();
                
                // Navigate directly without delay - just GO there!
                debugPrint('DEBUG: About to navigate to user selection');
                parentContext.go('/messages/select-user'); // Try a different route
                debugPrint('DEBUG: Navigation command sent');
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Group Chat'),
              onTap: () {
                Navigator.of(dialogContext).pop();
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (parentContext.mounted) {
                    parentContext.go('/chat/group-creation');
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Class Chat'),
              onTap: () {
                Navigator.of(dialogContext).pop();
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (parentContext.mounted) {
                    parentContext.go('/chat/class-selection');
                  }
                });
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
