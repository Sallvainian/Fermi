import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models/notification_model.dart';
import '../../data/services/firebase_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseNotificationService _notificationService =
      FirebaseNotificationService();

  List<NotificationModel> _notifications = [];
  List<NotificationModel> _filteredNotifications = [];
  bool _isLoading = false;
  String _error = '';
  String _searchQuery = '';
  String _selectedFilter = 'All';
  StreamSubscription<List<NotificationModel>>? _notificationSubscription;

  // Getters
  List<NotificationModel> get notifications => _notifications;
  List<NotificationModel> get filteredNotifications => _filteredNotifications;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedFilter => _selectedFilter;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Initialize and start listening to notifications
  void initialize() {
    _loadNotifications();
  }

  // Load notifications from Firebase
  void _loadNotifications() {
    _isLoading = true;
    _error = '';
    notifyListeners();

    _notificationSubscription?.cancel();
    _notificationSubscription =
        _notificationService.getUserNotifications().listen(
      (notifications) {
        _notifications = notifications;
        _applyFilters();
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Apply search and filter
  void _applyFilters() {
    _filteredNotifications = _notifications.where((notification) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!notification.title.toLowerCase().contains(query) &&
            !notification.message.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Apply type filter
      if (_selectedFilter != 'All') {
        switch (_selectedFilter) {
          case 'Grades':
            if (notification.type != NotificationType.grade) return false;
            break;
          case 'Assignments':
            if (notification.type != NotificationType.assignment) return false;
            break;
          case 'Messages':
            if (notification.type != NotificationType.message) return false;
            break;
          case 'System':
            if (notification.type != NotificationType.system) return false;
            break;
        }
      }

      return true;
    }).toList();
  }

  // Update search query
  void updateSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  // Update filter
  void updateFilter(String filter) {
    _selectedFilter = filter;
    _applyFilters();
    notifyListeners();
  }

  // Get notifications by tab
  List<NotificationModel> getNotificationsByTab(String tab) {
    switch (tab) {
      case 'all':
        return filteredNotifications;
      case 'unread':
        return filteredNotifications.where((n) => !n.isRead).toList();
      case 'academic':
        return filteredNotifications
            .where((n) =>
                n.type == NotificationType.grade ||
                n.type == NotificationType.assignment ||
                n.type == NotificationType.submission)
            .toList();
      default:
        return filteredNotifications;
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
      // Update local state immediately for better UX
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _applyFilters();
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to mark as read: $e';
      notifyListeners();
    }
  }

  // Mark notification as unread
  Future<void> markAsUnread(String notificationId) async {
    try {
      await _notificationService.markAsUnread(notificationId);
      // Update local state immediately for better UX
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: false);
        _applyFilters();
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to mark as unread: $e';
      notifyListeners();
    }
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      // Update local state
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _applyFilters();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to mark all as read: $e';
      notifyListeners();
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);
      // Remove from local state
      _notifications.removeWhere((n) => n.id == notificationId);
      _applyFilters();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete notification: $e';
      notifyListeners();
    }
  }

  // Delete all read notifications
  Future<void> deleteAllRead() async {
    try {
      await _notificationService.deleteAllRead();
      // Remove from local state
      _notifications.removeWhere((n) => n.isRead);
      _applyFilters();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete read notifications: $e';
      notifyListeners();
    }
  }

  // Get notification settings
  Future<Map<String, bool>> getNotificationSettings() async {
    try {
      return await _notificationService.getNotificationSettings();
    } catch (e) {
      _error = 'Failed to get settings: $e';
      notifyListeners();
      return {};
    }
  }

  // Update notification settings
  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    try {
      await _notificationService.updateNotificationSettings(settings);
    } catch (e) {
      _error = 'Failed to update settings: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
