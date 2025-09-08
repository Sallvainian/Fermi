import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/common/app_card.dart';
import '../../data/services/user_management_service.dart';
import '../widgets/user_edit_dialog.dart';
import '../widgets/class_assignment_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserManagementService _userService = UserManagementService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  
  String _roleFilter = 'all';
  String _searchQuery = '';
  List<UserModel> _users = [];
  Map<String, dynamic> _userStats = {};
  bool _isLoading = true;
  bool _selectAll = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  
  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadUserStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _lastDocument = null;
        _hasMore = true;
        _users.clear();
      });
    }

    try {
      final users = await _userService.getUsers(
        roleFilter: _roleFilter == 'all' ? null : _roleFilter,
        searchQuery: _searchQuery,
        startAfter: loadMore ? _lastDocument : null,
      );
      
      setState(() {
        if (loadMore) {
          _users.addAll(users);
        } else {
          _users = users;
        }
        _hasMore = users.length >= 25;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $e')),
      );
    }
  }

  Future<void> _loadUserStats() async {
    final stats = await _userService.getUserStats();
    setState(() => _userStats = stats);
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _loadUsers();
  }

  void _onRoleFilterChanged(String? role) {
    setState(() => _roleFilter = role ?? 'all');
    _loadUsers();
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
      _selectAll = _selectedUserIds.length == _users.length;
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selectedUserIds.addAll(_users.map((u) => u.uid));
      } else {
        _selectedUserIds.clear();
      }
    });
  }

  Future<void> _editUser(UserModel user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => UserEditDialog(user: user),
    );
    
    if (result == true) {
      _loadUsers();
      _loadUserStats();
    }
  }

  Future<void> _resetPassword(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Reset password for ${user.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final newPassword = await _userService.resetUserPassword(user.uid);
    if (!mounted) return;
    
    if (newPassword != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password Reset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New password for ${user.displayName}:'),
              const SizedBox(height: 8),
              SelectableText(
                newPassword,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reset password')),
      );
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.displayName}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _userService.deleteUser(user.uid);
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.displayName} deleted successfully')),
      );
      _loadUsers();
      _loadUserStats();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete user')),
      );
    }
  }

  Future<void> _bulkAssignClasses() async {
    if (_selectedUserIds.isEmpty) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ClassAssignmentDialog(
        userIds: _selectedUserIds.toList(),
      ),
    );
    
    if (result == true) {
      setState(() => _selectedUserIds.clear());
      _loadUsers();
    }
  }

  Future<void> _bulkResetPasswords() async {
    if (_selectedUserIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Reset Passwords'),
        content: Text('Reset passwords for ${_selectedUserIds.length} selected users?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final results = <String, String>{};
    for (final userId in _selectedUserIds) {
      final user = _users.firstWhere((u) => u.uid == userId);
      final newPassword = await _userService.resetUserPassword(userId);
      if (newPassword != null) {
        results[user.displayName ?? user.email ?? userId] = newPassword;
      }
    }

    if (!mounted) return;
    
    if (results.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Passwords Reset'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('New passwords:'),
                const SizedBox(height: 16),
                ...results.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SelectableText(
                        entry.value,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      setState(() => _selectedUserIds.clear());
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedUserIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Delete Users'),
        content: Text('Delete ${_selectedUserIds.length} selected users? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _userService.bulkDeleteUsers(_selectedUserIds.toList());
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedUserIds.length} users deleted')),
      );
      setState(() => _selectedUserIds.clear());
      _loadUsers();
      _loadUserStats();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete users')),
      );
    }
  }

  Future<void> _exportUsers() async {
    final csvContent = await _userService.exportUsersToCSV(_users);
    if (csvContent.isEmpty) return;
    
    final bytes = utf8.encode(csvContent);
    final blob = Uint8List.fromList(bytes);
    
    try {
      await FilePicker.platform.saveFile(
        fileName: 'users_export.csv',
        bytes: blob,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Users exported successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting users: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1200;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadUsers();
              _loadUserStats();
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(51),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(51),
                ),
              ),
            ),
            child: Row(
              children: [
                _StatChip(
                  label: 'Total',
                  value: _userStats['total']?.toString() ?? '0',
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                _StatChip(
                  label: 'Students',
                  value: _userStats['students']?.toString() ?? '0',
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _StatChip(
                  label: 'Teachers',
                  value: _userStats['teachers']?.toString() ?? '0',
                  color: Colors.orange,
                ),
                const SizedBox(width: 16),
                _StatChip(
                  label: 'Admins',
                  value: _userStats['admins']?.toString() ?? '0',
                  color: Colors.purple,
                ),
                const SizedBox(width: 16),
                _StatChip(
                  label: 'Online',
                  value: _userStats['online']?.toString() ?? '0',
                  color: Colors.green,
                ),
              ],
            ),
          ),
          
          // Filters and Search
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or username...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    value: _roleFilter,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'student', child: Text('Students')),
                      DropdownMenuItem(value: 'teacher', child: Text('Teachers')),
                      DropdownMenuItem(value: 'admin', child: Text('Admins')),
                    ],
                    onChanged: _onRoleFilterChanged,
                  ),
                ),
                if (_selectedUserIds.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _bulkAssignClasses,
                    icon: const Icon(Icons.class_),
                    label: Text('Assign Classes (${_selectedUserIds.length})'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _bulkResetPasswords,
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Reset Passwords'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _bulkDelete,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Data Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : isDesktop
                        ? _buildDataTable()
                        : _buildCardList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(
              label: Checkbox(
                value: _selectAll,
                onChanged: _toggleSelectAll,
              ),
            ),
            const DataColumn(label: Text('Avatar')),
            const DataColumn(label: Text('Name')),
            const DataColumn(label: Text('Email/Username')),
            const DataColumn(label: Text('Role')),
            const DataColumn(label: Text('Grade')),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Created')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: _users.map((user) {
            final isSelected = _selectedUserIds.contains(user.uid);
            return DataRow(
              selected: isSelected,
              cells: [
                DataCell(
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleUserSelection(user.uid),
                  ),
                ),
                DataCell(
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _getRoleColor(user.role?.name ?? 'student'),
                    child: Text(
                      user.displayName?.substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                DataCell(
                  Text(user.displayName ?? 'No Name'),
                  onTap: () => _editUser(user),
                ),
                DataCell(Text(user.email ?? user.username ?? '')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(user.role?.name ?? 'student').withAlpha(51),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      user.role?.name.toUpperCase() ?? 'STUDENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(user.role?.name ?? 'student'),
                      ),
                    ),
                  ),
                ),
                DataCell(Text(user.gradeLevel ?? '-')),
                DataCell(
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: user.lastActive != null &&
                                  user.lastActive!.isAfter(DateTime.now().subtract(const Duration(minutes: 5)))
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.lastActive != null &&
                                user.lastActive!.isAfter(DateTime.now().subtract(const Duration(minutes: 5)))
                            ? 'Online'
                            : 'Offline',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    user.createdAt != null
                        ? '${user.createdAt!.month}/${user.createdAt!.day}/${user.createdAt!.year}'
                        : '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'password',
                        child: Row(
                          children: [
                            Icon(Icons.lock_reset, size: 18),
                            SizedBox(width: 8),
                            Text('Reset Password'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _editUser(user);
                          break;
                        case 'password':
                          _resetPassword(user);
                          break;
                        case 'delete':
                          _deleteUser(user);
                          break;
                      }
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCardList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _users.length) {
          return Center(
            child: ElevatedButton(
              onPressed: () => _loadUsers(loadMore: true),
              child: const Text('Load More'),
            ),
          );
        }
        
        final user = _users[index];
        final isSelected = _selectedUserIds.contains(user.uid);
        
        return AppCard(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(user.role?.name ?? 'student'),
                  child: Text(
                    user.displayName?.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(user.displayName ?? 'No Name'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email ?? user.username ?? ''),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleColor(user.role?.name ?? 'student').withAlpha(51),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user.role?.name.toUpperCase() ?? 'STUDENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(user.role?.name ?? 'student'),
                        ),
                      ),
                    ),
                    if (user.gradeLevel != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Grade ${user.gradeLevel}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  value: 'password',
                  child: Text('Reset Password'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _editUser(user);
                    break;
                  case 'password':
                    _resetPassword(user);
                    break;
                  case 'delete':
                    _deleteUser(user);
                    break;
                }
              },
            ),
            onTap: () => _editUser(user),
            onLongPress: () => _toggleUserSelection(user.uid),
            selected: isSelected,
          ),
          ),
        );
      },
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'teacher':
        return Colors.orange;
      case 'student':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}