import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  try {
    // Create test discussion boards
    print('Creating test discussion boards...');
    
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
    print('Created board: ${board1Ref.id}');

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
    print('Created board: ${board2Ref.id}');

    // Add some test threads to board 1
    print('Adding test threads...');
    
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
    print('Created thread: ${thread1Ref.id}');

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
    print('Created thread: ${thread2Ref.id}');

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
    print('Added comment to thread');

    // Update thread count
    await firestore.collection('discussion_boards').doc(board1Ref.id).update({
      'threadCount': 2,
    });

    print('✅ Test discussion data created successfully!');
    print('Board 1 ID: ${board1Ref.id}');
    print('Board 2 ID: ${board2Ref.id}');
    
  } catch (e) {
    print('❌ Error creating test data: $e');
  }
}