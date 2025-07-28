#!/usr/bin/env python3
"""
Zep Cloud Development Context Manager
This script demonstrates how to use Zep Cloud for managing development context,
tracking code changes, and maintaining memory across development sessions.
"""

import os
import json
from datetime import datetime
from zep_cloud.client import Zep
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class DevContextManager:
    """Manages development context using Zep Cloud"""
    
    def __init__(self):
        """Initialize the Zep Cloud client"""
        self.api_key = os.getenv("ZEP_API_KEY")
        if not self.api_key:
            raise ValueError("ZEP_API_KEY environment variable not set")
        
        self.client = Zep(api_key=self.api_key)
        self.project_user_id = "teacher-dashboard-flutter"
        
    def setup_project_user(self):
        """Create or get the project user in Zep Cloud"""
        try:
            # Try to get existing user
            user = self.client.user.get(user_id=self.project_user_id)
            print(f"[SUCCESS] Found existing project user: {self.project_user_id}")
        except:
            # Create new user if doesn't exist
            user = self.client.user.add(
                user_id=self.project_user_id,
                metadata={
                    "project_type": "Flutter Firebase Application",
                    "created_at": datetime.now().isoformat(),
                    "description": "Teacher Dashboard with real-time communication features"
                }
            )
            print(f"[SUCCESS] Created new project user: {self.project_user_id}")
        return user
    
    def add_development_decision(self, decision_type, description, context=None):
        """Track important development decisions"""
        data = {
            "type": "development_decision",
            "decision_type": decision_type,
            "description": description,
            "timestamp": datetime.now().isoformat(),
            "context": context or {}
        }
        
        # Add to graph as JSON data
        response = self.client.graph.add(
            user_id=self.project_user_id,
            type="json",
            data=json.dumps(data)
        )
        print(f"[SUCCESS] Added {decision_type} decision to development context")
        return response
    
    def track_code_change(self, file_path, change_type, description, code_snippet=None):
        """Track significant code changes"""
        data = {
            "type": "code_change",
            "file_path": file_path,
            "change_type": change_type,
            "description": description,
            "timestamp": datetime.now().isoformat()
        }
        
        if code_snippet:
            data["code_snippet"] = code_snippet
        
        # Add to graph as JSON data
        response = self.client.graph.add(
            user_id=self.project_user_id,
            type="json",
            data=json.dumps(data)
        )
        print(f"[SUCCESS] Tracked code change in {file_path}")
        return response
    
    def add_todo_item(self, task, priority="medium", category="general"):
        """Add a development todo item"""
        data = {
            "type": "todo",
            "task": task,
            "priority": priority,
            "category": category,
            "status": "pending",
            "created_at": datetime.now().isoformat()
        }
        
        response = self.client.graph.add(
            user_id=self.project_user_id,
            type="json",
            data=json.dumps(data)
        )
        print(f"[SUCCESS] Added todo: {task}")
        return response
    
    def add_error_context(self, error_message, file_path, stack_trace=None, resolution=None):
        """Track errors and their resolutions"""
        data = {
            "type": "error_context",
            "error_message": error_message,
            "file_path": file_path,
            "timestamp": datetime.now().isoformat()
        }
        
        if stack_trace:
            data["stack_trace"] = stack_trace
        if resolution:
            data["resolution"] = resolution
            
        response = self.client.graph.add(
            user_id=self.project_user_id,
            type="json",
            data=json.dumps(data)
        )
        print(f"[SUCCESS] Tracked error context for {file_path}")
        return response
    
    def search_context(self, query, limit=10):
        """Search development context"""
        results = self.client.graph.search(
            user_id=self.project_user_id,
            query=query,
            limit=limit
        )
        
        print(f"\n[SEARCH] Search results for '{query}':")
        if hasattr(results, 'edges') and results.edges:
            for i, edge in enumerate(results.edges, 1):
                print(f"\n{i}. {edge.fact if hasattr(edge, 'fact') else 'Result'}")
                if hasattr(edge, 'created_at'):
                    print(f"   Created: {edge.created_at}")
        else:
            print("   No results found")
            
        return results
    
    def get_recent_decisions(self):
        """Get recent development decisions"""
        return self.search_context("development_decision", limit=20)
    
    def get_todos(self):
        """Get pending todo items"""
        return self.search_context("todo pending", limit=20)
    
    def get_error_history(self):
        """Get error history"""
        return self.search_context("error_context", limit=20)


# Example usage
if __name__ == "__main__":
    # Initialize the context manager
    manager = DevContextManager()
    
    # Setup project user
    manager.setup_project_user()
    
    # Example: Track a development decision
    manager.add_development_decision(
        decision_type="architecture",
        description="Using Provider for state management instead of Riverpod for simplicity",
        context={
            "alternatives_considered": ["Riverpod", "Bloc", "GetX"],
            "reason": "Provider is simpler and well-integrated with Flutter"
        }
    )
    
    # Example: Track a code change
    manager.track_code_change(
        file_path="lib/features/calendar/presentation/providers/calendar_provider.dart",
        change_type="feature",
        description="Added real-time event synchronization using Firestore streams",
        code_snippet="StreamProvider<List<CalendarEvent>>((ref) => FirebaseFirestore.instance...)"
    )
    
    # Example: Add a todo
    manager.add_todo_item(
        task="Implement offline support for calendar events",
        priority="high",
        category="feature"
    )
    
    # Example: Track an error and resolution
    manager.add_error_context(
        error_message="FirebaseException: [cloud_firestore/permission-denied]",
        file_path="lib/features/calendar/data/services/calendar_service.dart",
        resolution="Updated Firestore security rules to allow authenticated users to read/write their own calendar events"
    )
    
    # Search for recent decisions
    print("\n" + "="*50)
    manager.get_recent_decisions()
    
    # Get todos
    print("\n" + "="*50)
    manager.get_todos()