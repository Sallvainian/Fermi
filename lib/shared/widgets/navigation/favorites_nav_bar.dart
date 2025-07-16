import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/navigation_provider.dart';
import '../../models/nav_item.dart';
import '../../services/navigation_service.dart';
import 'bottom_nav_bar.dart';

/// Customizable bottom navigation bar with favorites
class FavoritesNavBar extends StatelessWidget {
  const FavoritesNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final favoriteItems = navigationProvider.favoriteItems;
    final currentRoute = GoRouterState.of(context).matchedLocation;

    if (navigationProvider.isLoading) {
      // Show loading indicator
      return Container(
        height: 60,
        color: Theme.of(context).colorScheme.surface,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (favoriteItems.isEmpty) {
      // Fallback to default navigation
      return const BottomNavBar();
    }

    // Find current index
    int currentIndex =
        favoriteItems.indexWhere((item) => item.route == currentRoute);
    if (currentIndex == -1) currentIndex = 0;

    return GestureDetector(
      onLongPress: () => _showCustomizationSheet(context),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subtle hint bar with pulsing animation on first use
            _HintBar(),
            BottomNavigationBar(
              items: favoriteItems
                  .map((item) => BottomNavigationBarItem(
                        icon: Icon(item.icon),
                        activeIcon: Icon(item.activeIcon),
                        label: item.title,
                        tooltip: item.title,
                      ))
                  .toList(),
              currentIndex: currentIndex,
              type: BottomNavigationBarType.fixed,
              onTap: (index) {
                if (index < favoriteItems.length) {
                  context.go(favoriteItems[index].route);
                }
              },
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              showUnselectedLabels: true,
              selectedFontSize: 12,
              unselectedFontSize: 12,
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomizationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NavigationCustomizationSheet(),
    );
  }
}

/// Floating action button for customizing navigation
class CustomizeNavFab extends StatelessWidget {
  const CustomizeNavFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      onPressed: () => _showCustomizationSheet(context),
      tooltip: 'Customize Navigation',
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
      child: const Icon(Icons.edit),
    );
  }

  void _showCustomizationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NavigationCustomizationSheet(),
    );
  }
}

/// Bottom sheet for customizing navigation favorites
class NavigationCustomizationSheet extends StatefulWidget {
  const NavigationCustomizationSheet({super.key});

  @override
  State<NavigationCustomizationSheet> createState() =>
      _NavigationCustomizationSheetState();
}

class _NavigationCustomizationSheetState
    extends State<NavigationCustomizationSheet> {
  late List<String> _tempFavorites;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    final navProvider = context.read<NavigationProvider>();
    _tempFavorites = List<String>.from(navProvider.favoriteIds);
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final theme = Theme.of(context);
    final availableItems = navProvider.availableItems;

    // Get categories
    final categories = {'all': 'All'};
    for (final item in availableItems) {
      categories[item.category] = _getCategoryName(item.category);
    }

    // Filter items by category
    final filteredItems = _selectedCategory == 'all'
        ? availableItems
        : availableItems
            .where((item) => item.category == _selectedCategory)
            .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(102),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customize Navigation',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select up to 4 favorites for quick access',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _resetToDefaults(context),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),

          // Current favorites preview
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(4, (index) {
                if (index < _tempFavorites.length) {
                  final item = availableItems.firstWhere(
                    (item) => item.id == _tempFavorites[index],
                  );
                  return Expanded(
                    child: _FavoriteSlot(
                      item: item,
                      onRemove: () => _removeFavorite(index),
                    ),
                  );
                } else {
                  return Expanded(
                    child: _EmptySlot(index: index),
                  );
                }
              }),
            ),
          ),

          const Divider(height: 1),

          // Category filter
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: categories.entries.map((entry) {
                final isSelected = _selectedCategory == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = entry.key;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Available items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                final isFavorite = _tempFavorites.contains(item.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      isFavorite ? item.activeIcon : item.icon,
                      color: isFavorite
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(item.title),
                    subtitle: Text(_getCategoryName(item.category)),
                    trailing: isFavorite
                        ? IconButton(
                            icon: const Icon(Icons.star),
                            color: theme.colorScheme.primary,
                            onPressed: () => _removeFavoriteById(item.id),
                          )
                        : IconButton(
                            icon: const Icon(Icons.star_border),
                            onPressed: _tempFavorites.length < 4
                                ? () => _addFavorite(item.id)
                                : null,
                          ),
                    onTap: () {
                      if (isFavorite) {
                        _removeFavoriteById(item.id);
                      } else if (_tempFavorites.length < 4) {
                        _addFavorite(item.id);
                      }
                    },
                  ),
                );
              },
            ),
          ),

          // Save button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _saveFavorites(context),
                child: const Text('Save Changes'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'general':
        return 'General';
      case 'academic':
        return 'Academic';
      case 'communication':
        return 'Communication';
      case 'planning':
        return 'Planning';
      case 'teaching':
        return 'Teaching';
      case 'system':
        return 'System';
      default:
        return category;
    }
  }

  void _addFavorite(String itemId) {
    if (_tempFavorites.length < 4 && !_tempFavorites.contains(itemId)) {
      setState(() {
        _tempFavorites.add(itemId);
      });
    }
  }

  void _removeFavorite(int index) {
    if (index >= 0 && index < _tempFavorites.length) {
      setState(() {
        _tempFavorites.removeAt(index);
      });
    }
  }

  void _removeFavoriteById(String itemId) {
    setState(() {
      _tempFavorites.remove(itemId);
    });
  }

  void _resetToDefaults(BuildContext context) {
    final navProvider = context.read<NavigationProvider>();
    final role = navProvider.availableItems.first.roles.first;
    setState(() {
      _tempFavorites = NavigationService.getDefaultFavorites(role);
    });
  }

  void _saveFavorites(BuildContext context) async {
    final navProvider = context.read<NavigationProvider>();

    // Update favorites
    for (int i = 0; i < _tempFavorites.length; i++) {
      if (i < navProvider.favoriteIds.length) {
        await navProvider.replaceFavorite(i, _tempFavorites[i]);
      } else {
        await navProvider.addFavorite(_tempFavorites[i]);
      }
    }

    // Remove extras
    while (navProvider.favoriteIds.length > _tempFavorites.length) {
      await navProvider.removeFavorite(navProvider.favoriteIds.last);
    }

    if (mounted && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// Widget for displaying a favorite slot
class _FavoriteSlot extends StatelessWidget {
  final NavItem item;
  final VoidCallback onRemove;

  const _FavoriteSlot({
    required this.item,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.activeIcon,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: IconButton(
              icon: Icon(
                Icons.remove_circle,
                size: 20,
                color: theme.colorScheme.error,
              ),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying an empty favorite slot
class _EmptySlot extends StatelessWidget {
  final int index;

  const _EmptySlot({required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(77),
          width: 2,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.add,
          color: theme.colorScheme.outline.withAlpha(128),
        ),
      ),
    );
  }
}

/// Subtle hint bar that shows users they can customize navigation
class _HintBar extends StatefulWidget {
  @override
  State<_HintBar> createState() => _HintBarState();
}

class _HintBarState extends State<_HintBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _hasBeenShown = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.1,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Check if hint has been shown before
    _loadHintStatus();
  }

  Future<void> _loadHintStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _hasBeenShown = prefs.getBool('nav_hint_shown') ?? false;

    if (!_hasBeenShown) {
      _controller.repeat(reverse: true);
      // Mark as shown after first display
      prefs.setBool('nav_hint_shown', true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_hasBeenShown) {
      // Just show a static subtle bar
      return Container(
        width: double.infinity,
        height: 2,
        color: theme.colorScheme.primary.withAlpha(26),
      );
    }

    // Show animated hint for first-time users
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 3,
          color: theme.colorScheme.primary.withAlpha((255 * _animation.value).round()),
        );
      },
    );
  }
}
