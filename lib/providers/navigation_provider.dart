import 'package:flutter/foundation.dart';
import '../services/navigation_service.dart';
import '../models/nav_item.dart';

/// Provider for managing navigation favorites and customization
class NavigationProvider extends ChangeNotifier {
  List<String> _favoriteIds = [];
  bool _isLoading = false;
  String _currentRole = 'student';

  List<String> get favoriteIds => _favoriteIds;
  bool get isLoading => _isLoading;
  
  List<NavItem> get favoriteItems => NavigationService.getFavoriteItems(_favoriteIds);
  List<NavItem> get availableItems => NavigationService.getItemsForRole(_currentRole);

  NavigationProvider() {
    _loadFavorites();
  }

  /// Set the current user role
  void setRole(String role) {
    if (_currentRole != role) {
      _currentRole = role;
      _loadFavorites();
    }
  }

  /// Load favorites from storage
  Future<void> _loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      final savedFavorites = await NavigationService.loadFavorites();
      
      if (savedFavorites.isEmpty) {
        // Use defaults if no saved favorites
        _favoriteIds = NavigationService.getDefaultFavorites(_currentRole);
      } else {
        // Filter saved favorites to only include items available for current role
        final availableIds = NavigationService.getItemsForRole(_currentRole)
            .map((item) => item.id)
            .toSet();
        _favoriteIds = savedFavorites
            .where((id) => availableIds.contains(id))
            .take(NavigationService.maxFavorites)
            .toList();
        
        // If we have less than 4 favorites after filtering, add defaults
        if (_favoriteIds.length < NavigationService.maxFavorites) {
          final defaults = NavigationService.getDefaultFavorites(_currentRole);
          for (final defaultId in defaults) {
            if (!_favoriteIds.contains(defaultId) && 
                _favoriteIds.length < NavigationService.maxFavorites) {
              _favoriteIds.add(defaultId);
            }
          }
        }
      }
    } catch (e) {
      print('Error loading favorites: $e');
      _favoriteIds = NavigationService.getDefaultFavorites(_currentRole);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add item to favorites
  Future<bool> addFavorite(String itemId) async {
    if (_favoriteIds.contains(itemId) || 
        _favoriteIds.length >= NavigationService.maxFavorites) {
      return false;
    }

    _favoriteIds.add(itemId);
    notifyListeners();

    return await NavigationService.saveFavorites(_favoriteIds);
  }

  /// Remove item from favorites
  Future<bool> removeFavorite(String itemId) async {
    if (!_favoriteIds.contains(itemId)) {
      return false;
    }

    _favoriteIds.remove(itemId);
    notifyListeners();

    return await NavigationService.saveFavorites(_favoriteIds);
  }

  /// Reorder favorites
  Future<bool> reorderFavorites(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _favoriteIds.length ||
        newIndex < 0 || newIndex > _favoriteIds.length) {
      return false;
    }

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = _favoriteIds.removeAt(oldIndex);
    _favoriteIds.insert(newIndex, item);
    notifyListeners();

    return await NavigationService.saveFavorites(_favoriteIds);
  }

  /// Replace a favorite at a specific index
  Future<bool> replaceFavorite(int index, String newItemId) async {
    if (index < 0 || index >= _favoriteIds.length) {
      return false;
    }

    _favoriteIds[index] = newItemId;
    notifyListeners();

    return await NavigationService.saveFavorites(_favoriteIds);
  }

  /// Reset to default favorites
  Future<bool> resetToDefaults() async {
    _favoriteIds = NavigationService.getDefaultFavorites(_currentRole);
    notifyListeners();

    return await NavigationService.saveFavorites(_favoriteIds);
  }

  /// Check if an item is a favorite
  bool isFavorite(String itemId) {
    return _favoriteIds.contains(itemId);
  }
}