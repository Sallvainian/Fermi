import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';

class ClassSelectionScreen extends StatefulWidget {
  const ClassSelectionScreen({super.key});

  @override
  State<ClassSelectionScreen> createState() => _ClassSelectionScreenState();
}

class _ClassSelectionScreenState extends State<ClassSelectionScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _classes = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userModel?.uid;
      final userRole = authProvider.userModel?.role;

      if (userId == null || userRole == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      Query query;
      if (userRole == UserRole.teacher) {
        // Teachers see classes they created
        query = FirebaseFirestore.instance
            .collection('classes')
            .where('teacherId', isEqualTo: userId);
      } else {
        // Students see classes they're enrolled in
        query = FirebaseFirestore.instance
            .collection('classes')
            .where('students', arrayContains: userId);
      }

      final querySnapshot = await query.get();
      final classes = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Class',
          'teacherName': data['teacherName'] ?? '',
          'studentCount': (data['students'] as List?)?.length ?? 0,
          'hasChatRoom': data['chatRoomId'] != null,
          'chatRoomId': data['chatRoomId'],
          ...data,
        };
      }).toList();

      setState(() {
        _classes = classes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createOrJoinClassChat(Map<String, dynamic> classData) async {
    try {
      final chatProvider = context.read<SimpleChatProvider>();

      if (classData['hasChatRoom'] && classData['chatRoomId'] != null) {
        // Chat room already exists, navigate to it
        context.go('/chat/${classData['chatRoomId']}');
      } else {
        // Create new class chat room
        setState(() => _isLoading = true);

        // Get all class participants
        final classDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(classData['id'])
            .get();

        final classInfo = classDoc.data()!;
        final studentIds = List<String>.from(classInfo['students'] ?? []);
        final teacherId = classInfo['teacherId'] as String;

        // Get user details for all participants
        final userIds = [teacherId, ...studentIds];
        final userDocs = await Future.wait(
          userIds.map(
            (id) =>
                FirebaseFirestore.instance.collection('users').doc(id).get(),
          ),
        );

        final participants = userDocs.where((doc) => doc.exists).map((doc) {
          final data = doc.data()!;
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'role': data['role'] ?? 'student',
            'photoUrl': data['photoUrl'],
          };
        }).toList();

        // Create the chat room
        final chatRoom = await chatProvider.createGroupChat(
          name: '${classData['name']} - Class Chat',
          type: 'class',
          participantIds: userIds,
          participants: participants,
          classId: classData['id'],
        );

        // Update class document with chat room ID
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(classData['id'])
            .update({'chatRoomId': chatRoom['id']});

        if (mounted) {
          context.go('/chat/${chatRoom['id']}');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating class chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTeacher =
        context.read<AuthProvider>().userModel?.role == UserRole.teacher;

    return AdaptiveLayout(
      title: 'Select Class for Chat',
      showBackButton: true,
      onBackPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/messages');
        }
      },
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadClasses,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isTeacher
                        ? 'No classes created yet'
                        : 'Not enrolled in any classes',
                    style: theme.textTheme.titleMedium,
                  ),
                  if (isTeacher) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => context.go('/teacher/classes'),
                      child: const Text('Create a Class'),
                    ),
                  ],
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final classData = _classes[index];
                final hasChatRoom = classData['hasChatRoom'] as bool;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.school,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(classData['name']),
                    subtitle: Text(
                      isTeacher
                          ? '${classData['studentCount']} students'
                          : 'Teacher: ${classData['teacherName']}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasChatRoom)
                          Chip(
                            label: const Text('Active Chat'),
                            backgroundColor: theme.colorScheme.primaryContainer,
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios),
                      ],
                    ),
                    onTap: () => _createOrJoinClassChat(classData),
                  ),
                );
              },
            ),
    );
  }
}
