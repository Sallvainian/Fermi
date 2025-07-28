#!/usr/bin/env python3
"""
Example: Integrating Zep Cloud context tracking into Flutter development workflow
This script demonstrates practical usage patterns for the teacher dashboard project.
"""

from zep_dev_context import DevContextManager
from datetime import datetime

def track_feature_implementation():
    """Example: Track a complete feature implementation"""
    manager = DevContextManager()
    
    # 1. Record the initial design decision
    manager.add_development_decision(
        decision_type="feature_design",
        description="Implementing video call feature using WebRTC for teacher-student communication",
        context={
            "requirements": [
                "Low latency video/audio",
                "Screen sharing capability",
                "Recording functionality",
                "Works across platforms (iOS, Android, Web)"
            ],
            "technology_choice": "flutter_webrtc package with Firebase signaling",
            "alternatives_considered": {
                "Agora SDK": "Good but expensive for scale",
                "Jitsi Meet": "Less control over UI/UX",
                "Custom WebRTC": "More flexible, better integration"
            }
        }
    )
    
    # 2. Track the main implementation
    manager.track_code_change(
        file_path="lib/features/chat/data/services/webrtc_service.dart",
        change_type="feature",
        description="Implemented WebRTC service with peer connection management",
        code_snippet="""
class WebRTCService {
  final FirebaseFirestore _firestore;
  RTCPeerConnection? _peerConnection;
  
  Future<void> createOffer(String roomId) async {
    // Implementation details...
  }
}
        """
    )
    
    # 3. Add related TODOs
    manager.add_todo_item(
        task="Add connection quality indicator to video call UI",
        priority="medium",
        category="enhancement"
    )
    
    manager.add_todo_item(
        task="Implement call recording with cloud storage",
        priority="low",
        category="feature"
    )
    
    # 4. Document any issues encountered
    manager.add_error_context(
        error_message="DOMException: Failed to execute 'getUserMedia' on 'MediaDevices'",
        file_path="lib/features/chat/presentation/screens/call_screen.dart",
        stack_trace="at WebRTCService.initializeMedia()",
        resolution="Added proper permission handling for camera/microphone access on Web platform"
    )
    
    print("[WORKFLOW] Feature implementation tracked successfully!")

def track_bug_fix():
    """Example: Track a bug fix with full context"""
    manager = DevContextManager()
    
    # Record the bug discovery
    manager.add_error_context(
        error_message="StateError: Stream has already been listened to",
        file_path="lib/features/calendar/presentation/providers/calendar_provider.dart",
        stack_trace="""
StreamProvider<List<CalendarEvent>>((ref) {
  return FirebaseFirestore.instance
    .collection('calendar_events')
    .snapshots() // <-- This stream was being listened to multiple times
    .map((snapshot) => ...);
});
        """,
        resolution="Changed to use StreamProvider.autoDispose to properly clean up stream subscriptions"
    )
    
    # Track the fix
    manager.track_code_change(
        file_path="lib/features/calendar/presentation/providers/calendar_provider.dart",
        change_type="bugfix",
        description="Fixed stream subscription leak by using autoDispose",
        code_snippet="""
// Before: StreamProvider<List<CalendarEvent>>
// After: StreamProvider.autoDispose<List<CalendarEvent>>
        """
    )
    
    print("[WORKFLOW] Bug fix tracked successfully!")

def track_performance_optimization():
    """Example: Track performance optimization work"""
    manager = DevContextManager()
    
    # Document the performance issue
    manager.add_development_decision(
        decision_type="performance",
        description="Optimizing student list loading time from 3s to <500ms",
        context={
            "problem": "Loading 200+ students causes UI freeze",
            "root_cause": "Fetching all student data upfront including unused fields",
            "solution": "Implement pagination and selective field loading",
            "metrics": {
                "before": "3.2s average load time",
                "after_target": "<500ms with pagination"
            }
        }
    )
    
    # Track the implementation
    manager.track_code_change(
        file_path="lib/features/students/data/repositories/student_repository.dart",
        change_type="optimization",
        description="Implemented cursor-based pagination for student list",
        code_snippet="""
Stream<List<Student>> getStudentsPaginated({
  int pageSize = 20,
  DocumentSnapshot? lastDocument,
}) {
  Query query = _firestore
    .collection('students')
    .orderBy('lastName')
    .limit(pageSize);
    
  if (lastDocument != null) {
    query = query.startAfterDocument(lastDocument);
  }
  
  return query.snapshots().map(...);
}
        """
    )
    
    print("[WORKFLOW] Performance optimization tracked successfully!")

def search_past_decisions():
    """Example: Search for past decisions before making new ones"""
    manager = DevContextManager()
    
    print("\n[SEARCH] Looking for past state management decisions...")
    results = manager.search_context("state management provider riverpod", limit=5)
    
    print("\n[SEARCH] Finding all performance-related work...")
    results = manager.search_context("performance optimization", limit=5)
    
    print("\n[SEARCH] Checking for similar errors...")
    results = manager.search_context("Stream already listened StateError", limit=5)

def generate_weekly_report():
    """Example: Generate a development progress report"""
    manager = DevContextManager()
    
    print(f"\n{'='*60}")
    print(f"WEEKLY DEVELOPMENT REPORT - {datetime.now().strftime('%Y-%m-%d')}")
    print(f"{'='*60}")
    
    print("\nRECENT DECISIONS:")
    manager.get_recent_decisions()
    
    print("\nPENDING TODOS:")
    manager.get_todos()
    
    print("\nERROR HISTORY:")
    manager.get_error_history()

if __name__ == "__main__":
    # Run examples
    print("=== Zep Cloud Flutter Integration Examples ===\n")
    
    # Example 1: Track a feature implementation
    print("1. Tracking feature implementation...")
    track_feature_implementation()
    
    # Example 2: Track a bug fix
    print("\n2. Tracking bug fix...")
    track_bug_fix()
    
    # Example 3: Track performance optimization
    print("\n3. Tracking performance optimization...")
    track_performance_optimization()
    
    # Example 4: Search past decisions
    print("\n4. Searching past decisions...")
    search_past_decisions()
    
    # Example 5: Generate weekly report
    print("\n5. Generating weekly report...")
    generate_weekly_report()
    
    print("\n=== All examples completed! ===")