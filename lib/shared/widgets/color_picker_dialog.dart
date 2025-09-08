import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/theme_provider.dart';

class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({super.key});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late String _selectedTheme;

  @override
  void initState() {
    super.initState();
    final themeProvider = context.read<ThemeProvider>();
    _selectedTheme = themeProvider.colorThemeId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Choose Theme Color'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: AppColors.availableThemes.length,
          itemBuilder: (context, index) {
            final themeId = AppColors.availableThemes.keys.elementAt(index);
            final colorTheme = AppColors.availableThemes[themeId]!;
            final isSelected = _selectedTheme == themeId;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedTheme = themeId;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? (isSelected
                            ? colorTheme.primary.withOpacity(0.3)
                            : Colors.grey[900])
                      : (isSelected
                            ? colorTheme.primary.withOpacity(0.2)
                            : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? colorTheme.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorTheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorTheme.primary.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        colorTheme.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      colorTheme.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? colorTheme.primary : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final themeProvider = context.read<ThemeProvider>();
            await themeProvider.setColorTheme(_selectedTheme);
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Theme changed to ${AppColors.availableThemes[_selectedTheme]!.name}',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
