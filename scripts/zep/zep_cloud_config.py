"""
Zep Cloud Configuration for Teacher Dashboard Development Memory
"""
import os
from zep_cloud.client import Zep
import uuid

# Configuration
API_KEY = os.environ.get('ZEP_API_KEY') or 'z_YOUR_API_KEY_HERE'  # Replace with your actual API key
PROJECT_USER_ID = "teacher-dashboard-dev"
PROJECT_SESSION_ID = uuid.uuid4().hex

def initialize_zep_client():
    """Initialize Zep Cloud client"""
    client = Zep(api_key=API_KEY)
    
    # Create or get user
    try:
        user = client.user.get(user_id=PROJECT_USER_ID)
        print(f"Found existing user: {PROJECT_USER_ID}")
    except:
        user = client.user.add(
            user_id=PROJECT_USER_ID,
            email="dev@teacherdashboard.local",
            first_name="Development",
            last_name="Memory",
            metadata={
                "project": "teacher-dashboard-flutter-firebase",
                "purpose": "development-memory",
                "type": "codebase-context"
            }
        )
        print(f"Created new user: {PROJECT_USER_ID}")
    
    # Create session
    try:
        client.memory.add_session(
            session_id=PROJECT_SESSION_ID,
            user_id=PROJECT_USER_ID,
            metadata={
                "project": "teacher-dashboard",
                "environment": "development"
            }
        )
        print(f"Created session: {PROJECT_SESSION_ID}")
    except:
        print(f"Session already exists: {PROJECT_SESSION_ID}")
    
    return client, PROJECT_SESSION_ID

def add_development_memory(client, session_id, role, content, metadata=None):
    """Add development context to Zep Cloud memory"""
    from zep_cloud.types import Message
    
    message = Message(
        role=role,
        content=content,
        role_type="user" if role == "developer" else "assistant",
        metadata=metadata or {}
    )
    
    client.memory.add(session_id, messages=[message])
    print(f"Added memory: {content[:50]}...")

def search_development_memory(client, query, limit=5):
    """Search development memory"""
    results = client.memory.search(
        session_id=PROJECT_SESSION_ID,
        query=query,
        limit=limit
    )
    return results

if __name__ == "__main__":
    # Example usage
    client, session_id = initialize_zep_client()
    
    # Add some initial development context
    add_development_memory(
        client, 
        session_id,
        "developer",
        "This is the Teacher Dashboard Flutter Firebase project. It uses Flutter for the frontend and Firebase for backend services including Authentication, Firestore, and Cloud Functions.",
        {"type": "project-overview"}
    )
    
    add_development_memory(
        client,
        session_id,
        "developer", 
        "The project structure includes: /lib for Flutter code, /functions for Cloud Functions, /android and /ios for platform-specific code.",
        {"type": "architecture"}
    )
    
    print("\nZep Cloud is configured and ready for development memory!")
    print(f"Session ID: {session_id}")