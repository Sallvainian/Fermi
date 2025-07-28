#!/usr/bin/env python3
"""
Test script for Zep Cloud MCP server integration
"""

import os
import sys
import json

# Add the MCP server path to Python path
sys.path.append('C:\\Users\\frank\\Projects\\mcp-server-zep-cloud')

from core.zep_cloud_client import ZepCloudClient

def test_zep_cloud():
    """Test Zep Cloud client operations"""
    print("[TEST] Starting Zep Cloud client tests...")
    
    # Initialize client
    client = ZepCloudClient()
    
    # Test 1: List users
    print("\n[TEST 1] Listing users...")
    users = client.list_users()
    print(f"Found {len(users)} users")
    for user in users[:5]:  # Show first 5
        print(f"  - User ID: {user.get('user_id')}")
    
    # Test 2: Get our project user
    print("\n[TEST 2] Getting project user...")
    user = client.get_user("teacher-dashboard-flutter")
    if user:
        print(f"  - Found user: {user['user_id']}")
        print(f"  - Metadata: {json.dumps(user.get('metadata', {}), indent=2)}")
    else:
        print("  - User not found")
    
    # Test 3: Search graph
    print("\n[TEST 3] Searching graph...")
    results = client.search_graph(
        user_id="teacher-dashboard-flutter",
        query="development_decision architecture provider state management",
        limit=5
    )
    
    if results:
        print(f"  - Search successful: {results.get('summary', 'No summary')}")
        if results.get('edges'):
            print(f"  - Found {len(results['edges'])} edges/facts")
            for edge in results['edges'][:3]:
                print(f"    * Fact: {edge.get('fact', 'No fact')[:100]}...")
        if results.get('nodes'):
            print(f"  - Found {len(results['nodes'])} nodes")
    else:
        print("  - Search failed")
    
    # Test 4: Add new data
    print("\n[TEST 4] Adding new graph data...")
    test_data = {
        "type": "test_entry",
        "description": "Testing Zep Cloud MCP server integration",
        "timestamp": "2025-01-22T10:00:00Z",
        "status": "successful"
    }
    
    result = client.add_graph_data(
        user_id="teacher-dashboard-flutter",
        data=json.dumps(test_data),
        data_type="json"
    )
    
    if result and result.get('success'):
        print("  - Successfully added test data")
        print(f"  - UUID: {result.get('response', {}).get('uuid', 'Unknown')}")
    else:
        print(f"  - Failed to add data: {result}")
    
    print("\n[TEST] All tests completed!")

if __name__ == "__main__":
    test_zep_cloud()