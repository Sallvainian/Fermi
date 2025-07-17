import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

/// Debug screen to update user display name
class UpdateDisplayNameScreen extends StatefulWidget {
  const UpdateDisplayNameScreen({super.key});

  @override
  State<UpdateDisplayNameScreen> createState() => _UpdateDisplayNameScreenState();
}

class _UpdateDisplayNameScreenState extends State<UpdateDisplayNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current values
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.userModel;
    if (user != null) {
      _displayNameController.text = user.displayName;
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.updateProfile(
        displayName: _displayNameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update profile'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Display Name'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Email: ${user?.email ?? 'N/A'}'),
                      Text('Display Name: "${user?.displayName ?? ''}"'),
                      Text('First Name: "${user?.firstName ?? ''}"'),
                      Text('Last Name: "${user?.lastName ?? ''}"'),
                      Text('Role: ${user?.role?.toString().split('.').last ?? 'N/A'}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Update form
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'How you want to appear in the app',
                  helperText: 'This is what other users will see',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a display name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Update Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}