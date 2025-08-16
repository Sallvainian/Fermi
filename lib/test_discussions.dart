import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'shared/services/logger_service.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  try {
    // Create test discussion boards
    LoggerService.info('Creating test discussion boards...', tag: 'TestDiscussions');
    
    // Board 1
    final board1Ref = await firestore.collection('discussion_boards').add({
      'title': 'General Discussion',
      'description': 'General topics and announcements for all students',
      'createdBy': 'teacher123',
      'createdAt': Timestamp.now(),
      'threadCount': 0,
      'isPinned': true,
      'tags': ['general', 'announcements'],
    });
    LoggerService.info('Created board: ${board1Ref.id}', tag: 'TestDiscussions');

    // Board 2  
    final board2Ref = await firestore.collection('discussion_boards').add({
      'title': 'Study Groups',
      'description': 'Organize and join study groups with your classmates',
      'createdBy': 'teacher123',
      'createdAt': Timestamp.now(),
      'threadCount': 0,
      'isPinned': false,
      'tags': ['study', 'collaboration'],
    });
    LoggerService.info('Created board: ${board2Ref.id}', tag: 'TestDiscussions');

    // Add some test threads to board 1
    LoggerService.info('Adding test threads...', tag: 'TestDiscussions');
    
    final thread1Ref = await firestore
        .collection('discussion_boards')
        .doc(board1Ref.id)
        .collection('threads')
        .add({
      'boardId': board1Ref.id,
      'title': 'Welcome to the class!',
      'content': 'Hello everyone! Welcome to our online discussion board. Feel free to introduce yourself here.',
      'authorId': 'teacher123',
      'authorName': 'Prof. Smith',
      'createdAt': Timestamp.now(),
      'replyCount': 0,
      'likeCount': 5,
      'isPinned': true,
      'isLocked': false,
    });
    LoggerService.info('Created thread: ${thread1Ref.id}', tag: 'TestDiscussions');

    final thread2Ref = await firestore
        .collection('discussion_boards')
        .doc(board1Ref.id)
        .collection('threads')
        .add({
      'boardId': board1Ref.id,
      'title': 'Homework questions',
      'content': 'If you have any questions about the homework, please post them here.',
      'authorId': 'student456',
      'authorName': 'Jane Doe',
      'createdAt': Timestamp.now(),
      'replyCount': 3,
      'likeCount': 2,
      'isPinned': false,
      'isLocked': false,
    });
    LoggerService.info('Created thread: ${thread2Ref.id}', tag: 'TestDiscussions');

    // Add a comment to thread 1
    await firestore
        .collection('discussion_boards')
        .doc(board1Ref.id)
        .collection('threads')
        .doc(thread1Ref.id)
        .collection('comments')
        .add({
      'content': 'Hi everyone! I\'m excited to be in this class!',
      'authorId': 'student789',
      'authorName': 'John Smith',
      'createdAt': Timestamp.now(),
    });
    LoggerService.info('Added comment to thread', tag: 'TestDiscussions');

    // Update thread count
    await firestore.collection('discussion_boards').doc(board1Ref.id).update({
      'threadCount': 2,
    });

    LoggerService.info('✅ Test discussion data created successfully!', tag: 'TestDiscussions');
    LoggerService.info('Board 1 ID: ${board1Ref.id}', tag: 'TestDiscussions');
    LoggerService.info('Board 2 ID: ${board2Ref.id}', tag: 'TestDiscussions');
    
  } catch (e) {
    LoggerService.error('❌ Error creating test data', tag: 'TestDiscussions', error: e);
  }
}