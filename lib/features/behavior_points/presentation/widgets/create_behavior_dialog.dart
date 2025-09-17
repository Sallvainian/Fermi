import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/behavior_point_provider.dart';

/// Dialog for creating behavior types with form validation and icon selection.
///
/// Features:
/// - Text field for behavior name
/// - Positive/Negative toggle switch
/// - Point value selector (1-10) with slider
/// - Icon picker from predefined icons
/// - Form validation
/// - Save and Cancel buttons
/// - Responsive design
class CreateBehaviorDialog extends StatefulWidget {
  /// Callback when behavior is created successfully
  final VoidCallback? onBehaviorCreated;

  /// Creates a behavior creation dialog
  const CreateBehaviorDialog({
    super.key,
    this.onBehaviorCreated,
  });

  @override
  State<CreateBehaviorDialog> createState() => _CreateBehaviorDialogState();
}

class _CreateBehaviorDialogState extends State<CreateBehaviorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _isPositive = true;
  int _pointValue = 5;
  IconData _selectedIcon = Icons.star_outline;
  bool _isLoading = false;

  // Predefined icons to choose from
  static final List<IconData> _availableIcons = [
    // Positive icons
    Icons.star,
    Icons.thumb_up,
    Icons.favorite,
    Icons.lightbulb,
    Icons.psychology,
    Icons.front_hand,
    Icons.people_outline,
    Icons.schedule,
    Icons.check_circle,
    Icons.emoji_emotions,
    Icons.school,
    Icons.assignment_turned_in,
    Icons.volunteer_activism,
    Icons.workspace_premium,
    Icons.trending_up,
    
    // Neutral/Negative icons
    Icons.warning,
    Icons.cancel,
    Icons.access_time,
    Icons.assignment_late,
    Icons.mood_bad,
    Icons.phonelink_off,
    Icons.backpack,
    Icons.record_voice_over,
    Icons.priority_high,
    Icons.error_outline,
    Icons.thumb_down,
    Icons.remove_circle_outline,
    Icons.block,
    Icons.notifications_off,
    Icons.trending_down,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isSmallScreen ? screenSize.width * 0.9 : 500,
          maxHeight: screenSize.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 24),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildNameField(theme),
                      const SizedBox(height: 24),
                      _buildTypeToggle(theme),
                      const SizedBox(height: 24),
                      _buildPointSelector(theme),
                      const SizedBox(height: 24),
                      _buildIconPicker(theme),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              _buildActionButtons(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the dialog header
  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add_circle_outline,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Behavior',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Design a new behavior type for your class',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the behavior name text field
  Widget _buildNameField(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Behavior Name',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g., Great Participation',
                filled: true,
                fillColor: theme.colorScheme.surface,
                prefixIcon: Icon(
                  _selectedIcon,
                  color: _isPositive ? Colors.green : Colors.orange,
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _isPositive ? Colors.green : Colors.orange,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a behavior name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
              onChanged: (value) {
                // Auto-suggest icon based on name
                _suggestIconFromName(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the positive/negative toggle
  Widget _buildTypeToggle(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Behavior Type',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTypeOption(
                    theme: theme,
                    isSelected: _isPositive,
                    title: 'Positive',
                    subtitle: 'Awards points',
                    icon: Icons.thumb_up,
                    color: Colors.green,
                    onTap: () => setState(() => _isPositive = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeOption(
                    theme: theme,
                    isSelected: !_isPositive,
                    title: 'Needs Work',
                    subtitle: 'Deducts points',
                    icon: Icons.build,
                    color: Colors.orange,
                    onTap: () => setState(() => _isPositive = false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds individual type option button
  Widget _buildTypeOption({
    required ThemeData theme,
    required bool isSelected,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the point value selector
  Widget _buildPointSelector(ThemeData theme) {
    final color = _isPositive ? Colors.green : Colors.orange;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Point Value',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_isPositive ? '+' : '-'}$_pointValue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.3),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.2),
                valueIndicatorColor: color,
                valueIndicatorTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Slider(
                value: _isPositive ? _pointValue.toDouble() : (11 - _pointValue).toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '${_isPositive ? '' : '-'}$_pointValue',
                onChanged: (value) {
                  setState(() {
                    if (_isPositive) {
                      _pointValue = value.round();
                    } else {
                      // Reverse the value for negative behaviors
                      _pointValue = (11 - value.round());
                    }
                  });
                  HapticFeedback.selectionClick();
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isPositive ? '1 point' : '-10 points',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _isPositive ? '10 points' : '-1 point',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the icon picker
  Widget _buildIconPicker(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Icon',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  final icon = _availableIcons[index];
                  final isSelected = icon == _selectedIcon;
                  final color = _isPositive ? Colors.green : Colors.orange;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIcon = icon;
                      });
                      HapticFeedback.selectionClick();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? color : theme.colorScheme.outline.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the action buttons
  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _isLoading ? null : _createBehavior,
            child: _isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create Behavior'),
          ),
        ),
      ],
    );
  }

  /// Auto-suggests icon based on behavior name
  void _suggestIconFromName(String name) {
    final lowerName = name.toLowerCase();
    IconData? suggestedIcon;

    // Positive behavior suggestions
    if (_isPositive) {
      if (lowerName.contains('participation') || lowerName.contains('participate')) {
        suggestedIcon = Icons.front_hand;
      } else if (lowerName.contains('help') || lowerName.contains('helping')) {
        suggestedIcon = Icons.people_outline;
      } else if (lowerName.contains('leadership') || lowerName.contains('leader')) {
        suggestedIcon = Icons.psychology;
      } else if (lowerName.contains('creative') || lowerName.contains('creativity')) {
        suggestedIcon = Icons.lightbulb;
      } else if (lowerName.contains('respect') || lowerName.contains('respectful')) {
        suggestedIcon = Icons.favorite;
      } else if (lowerName.contains('excellent') || lowerName.contains('great')) {
        suggestedIcon = Icons.star;
      } else if (lowerName.contains('homework') || lowerName.contains('assignment')) {
        suggestedIcon = Icons.assignment_turned_in;
      } else if (lowerName.contains('volunteer') || lowerName.contains('helping')) {
        suggestedIcon = Icons.volunteer_activism;
      }
    } else {
      // Negative behavior suggestions
      if (lowerName.contains('late') || lowerName.contains('tardy')) {
        suggestedIcon = Icons.access_time;
      } else if (lowerName.contains('missing') || lowerName.contains('incomplete')) {
        suggestedIcon = Icons.assignment_late;
      } else if (lowerName.contains('talking') || lowerName.contains('talk')) {
        suggestedIcon = Icons.record_voice_over;
      } else if (lowerName.contains('disrupting') || lowerName.contains('disruptive')) {
        suggestedIcon = Icons.warning;
      } else if (lowerName.contains('disrespectful') || lowerName.contains('rude')) {
        suggestedIcon = Icons.mood_bad;
      } else if (lowerName.contains('off task') || lowerName.contains('distracted')) {
        suggestedIcon = Icons.phonelink_off;
      } else if (lowerName.contains('unprepared') || lowerName.contains('materials')) {
        suggestedIcon = Icons.backpack;
      }
    }

    if (suggestedIcon != null && suggestedIcon != _selectedIcon) {
      setState(() {
        _selectedIcon = suggestedIcon!;
      });
    }
  }

  /// Creates the custom behavior
  Future<void> _createBehavior() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<BehaviorPointProvider>();
      
      final points = _isPositive ? _pointValue : -_pointValue;
      
      await provider.createCustomBehavior(
        name: _nameController.text.trim(),
        description: _nameController.text.trim(),  // Use name as description
        points: points,
        type: _isPositive ? 'positive' : 'negative',
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onBehaviorCreated?.call();
        
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Custom behavior "${_nameController.text.trim()}" created successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create behavior: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}