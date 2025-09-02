import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Simple test screen to verify navigation to user selection works
class TestUserSelectionNavigation extends StatelessWidget {
  const TestUserSelectionNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Navigation'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Click button below to test user selection screen'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                debugPrint('Navigating to /chat/user-selection');
                context.push('/chat/user-selection');
              },
              child: const Text('Go to User Selection'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
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
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Show New Chat Dialog'),
            ),
          ],
        ),
      ),
    );
  }
}