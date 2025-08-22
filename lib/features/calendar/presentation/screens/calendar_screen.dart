import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../shared/widgets/common/responsive_layout.dart';
import '../providers/calendar_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/calendar_event.dart';
import '../../data/services/device_calendar_service_factory.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  EventType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);

    // Initialize calendar provider with current user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().userModel?.uid;
      if (userId != null) {
        context.read<CalendarProvider>().initialize(userId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Calendar',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateEventSheet(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Month'),
          Tab(text: 'Week'),
          Tab(text: 'Agenda'),
        ],
      ),
      body: Consumer<CalendarProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${provider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadUserEvents(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Calendar Controls
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Month/Year Navigation
                    Expanded(
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => provider.navigatePrevious(),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Text(
                              _formatMonthYear(provider.focusedDate),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            onPressed: () => provider.navigateNext(),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                    // Today Button
                    TextButton(
                      onPressed: () => provider.goToToday(),
                      child: const Text('Today'),
                    ),
                    const SizedBox(width: 8),
                    // Filter Button
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PopupMenuButton<EventType?>(
                        initialValue: _selectedFilter,
                        onSelected: (value) {
                          setState(() {
                            _selectedFilter = value;
                          });
                          provider.setFilterType(value);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: null,
                            child: Text('All Events'),
                          ),
                          ...EventType.values.map((type) => PopupMenuItem(
                                value: type,
                                child: Text(type.displayName),
                              )),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.filter_list, size: 20),
                              const SizedBox(width: 8),
                              Text(_selectedFilter?.displayName ?? 'All'),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Calendar Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMonthView(provider),
                    _buildWeekView(provider),
                    _buildAgendaView(provider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthView(CalendarProvider provider) {
    return ResponsiveContainer(
      child: Column(
        children: [
          // Calendar Header (Days of Week)
          _buildCalendarHeader(),
          // Calendar Grid
          Expanded(
            child: _buildCalendarGrid(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    final theme = Theme.of(context);
    const daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: daysOfWeek.map((day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(CalendarProvider provider) {
    final focusedDate = provider.focusedDate;
    final firstDayOfMonth = DateTime(focusedDate.year, focusedDate.month, 1);
    final firstDayOfCalendar =
        firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday % 7));

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: 42, // 6 weeks * 7 days
      itemBuilder: (context, index) {
        final date = firstDayOfCalendar.add(Duration(days: index));
        final isCurrentMonth = date.month == focusedDate.month;
        final isToday = _isSameDay(date, DateTime.now());
        final isSelected = _isSameDay(date, provider.selectedDate);
        final events = provider.getEventsForDate(date);
        final filteredEvents = _selectedFilter != null
            ? events.where((e) => e.type == _selectedFilter).toList()
            : events;

        return _buildCalendarDay(
          provider: provider,
          date: date,
          isCurrentMonth: isCurrentMonth,
          isToday: isToday,
          isSelected: isSelected,
          events: filteredEvents,
        );
      },
    );
  }

  Widget _buildCalendarDay({
    required CalendarProvider provider,
    required DateTime date,
    required bool isCurrentMonth,
    required bool isToday,
    required bool isSelected,
    required List<CalendarEvent> events,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        provider.setSelectedDate(date);
        if (events.isNotEmpty) {
          _showDayEventsSheet(date, events);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : isToday
                  ? theme.colorScheme.primaryContainer
                  : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Date Number
            Text(
              '${date.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : isToday
                        ? theme.colorScheme.onPrimaryContainer
                        : isCurrentMonth
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                fontWeight:
                    isToday || isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            // Event Indicators
            if (events.isNotEmpty) ...[
              const SizedBox(height: 2),
              Wrap(
                spacing: 2,
                children: events.take(3).map((event) {
                  return Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color(int.parse(event.displayColor.substring(1),
                              radix: 16) +
                          0xFF000000),
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
              if (events.length > 3)
                Text(
                  '+${events.length - 3}',
                  style: TextStyle(
                    fontSize: 8,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView(CalendarProvider provider) {
    return ResponsiveContainer(
      child: Column(
        children: [
          // Week Header
          _buildWeekHeader(provider),
          // Week Grid
          Expanded(
            child: _buildWeekGrid(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekHeader(CalendarProvider provider) {
    final theme = Theme.of(context);
    final selectedDate = provider.selectedDate;
    final startOfWeek =
        selectedDate.subtract(Duration(days: selectedDate.weekday % 7));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(7, (index) {
          final date = startOfWeek.add(Duration(days: index));
          final isToday = _isSameDay(date, DateTime.now());

          return Expanded(
            child: Column(
              children: [
                Text(
                  ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][index],
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isToday ? theme.colorScheme.primary : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isToday
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWeekGrid(CalendarProvider provider) {
    final selectedDate = provider.selectedDate;
    final startOfWeek =
        selectedDate.subtract(Duration(days: selectedDate.weekday % 7));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 24, // 24 hours
      itemBuilder: (context, hour) {
        return _buildHourRow(provider, hour, startOfWeek);
      },
    );
  }

  Widget _buildHourRow(
      CalendarProvider provider, int hour, DateTime startOfWeek) {
    final theme = Theme.of(context);

    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          // Hour Label
          SizedBox(
            width: 60,
            child: Text(
              _formatHour(hour),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Week Days
          Expanded(
            child: Row(
              children: List.generate(7, (dayIndex) {
                final date = startOfWeek.add(Duration(days: dayIndex));
                final events = _getEventsForDateAndHour(provider, date, hour);

                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: events.isNotEmpty
                        ? _buildEventBlock(events.first)
                        : null,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventBlock(CalendarEvent event) {
    final theme = Theme.of(context);
    final color = Color(
        int.parse(event.displayColor.substring(1), radix: 16) + 0xFF000000);

    return Container(
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        event.title,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildAgendaView(CalendarProvider provider) {
    final groupedEvents = provider.eventsByDate;
    final dates = groupedEvents.keys.toList()..sort();

    if (_selectedFilter != null) {
      // Filter dates that have events of the selected type
      dates.removeWhere((date) {
        final events = groupedEvents[date] ?? [];
        return !events.any((event) => event.type == _selectedFilter);
      });
    }

    return ResponsiveContainer(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          var dayEvents = groupedEvents[date] ?? [];

          if (_selectedFilter != null) {
            dayEvents =
                dayEvents.where((e) => e.type == _selectedFilter).toList();
          }

          return _buildAgendaDay(provider, date, dayEvents);
        },
      ),
    );
  }

  Widget _buildAgendaDay(
      CalendarProvider provider, DateTime date, List<CalendarEvent> events) {
    final theme = Theme.of(context);
    final isToday = _isSameDay(date, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                _formatAgendaDate(date),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isToday ? theme.colorScheme.primary : null,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Today',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Events
        ...events.map((event) => _buildAgendaEvent(provider, event)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAgendaEvent(CalendarProvider provider, CalendarEvent event) {
    final theme = Theme.of(context);
    final color = Color(
        int.parse(event.displayColor.substring(1), radix: 16) + 0xFF000000);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showEventDetails(provider, event),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Event Type Indicator
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Event Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!event.isAllDay) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeRange(event),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (event.location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Event Type Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  event.type.displayName,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Methods
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  String _formatAgendaDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    return '${days[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }

  String _formatTimeRange(CalendarEvent event) {
    final startTime = TimeOfDay.fromDateTime(event.startTime);
    if (event.endTime == null) {
      return startTime.format(context);
    }
    final endTime = TimeOfDay.fromDateTime(event.endTime!);
    return '${startTime.format(context)} - ${endTime.format(context)}';
  }

  List<CalendarEvent> _getEventsForDateAndHour(
      CalendarProvider provider, DateTime date, int hour) {
    final events = provider.getEventsForDate(date);
    return events.where((event) {
      if (event.isAllDay) return false;
      return event.startTime.hour == hour;
    }).toList();
  }

  void _showDayEventsSheet(DateTime date, List<CalendarEvent> events) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayEventsSheet(
        date: date,
        events: events,
        onEventTap: (event) =>
            _showEventDetails(context.read<CalendarProvider>(), event),
      ),
    );
  }

  void _showEventDetails(CalendarProvider provider, CalendarEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventDetailSheet(
        event: event,
        onEdit: () {
          Navigator.pop(context);
          _showEditEventSheet(provider, event);
        },
        onDelete: () async {
          Navigator.pop(context);
          try {
            await provider.deleteEvent(event.id);
            // Check if widget is still mounted before showing snackbar
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Event deleted successfully')),
              );
            }
          } catch (e) {
            // Check if widget is still mounted before showing snackbar
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error deleting event: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showCreateEventSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateEventSheet(
        onEventCreated: (event) async {
          final provider = context.read<CalendarProvider>();
          try {
            await provider.createEvent(
              title: event['title'],
              type: event['type'],
              startTime: event['startTime'],
              endTime: event['endTime'],
              description: event['description'],
              location: event['location'],
              isAllDay: event['isAllDay'] ?? false,
              hasReminder: event['hasReminder'] ?? false,
              reminderMinutes: event['reminderMinutes'],
              syncToDeviceCalendar: event['syncToDeviceCalendar'] ?? false,
            );
            // Check if widget is still mounted before showing snackbar
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Event created successfully')),
              );
            }
          } catch (e) {
            // Check if widget is still mounted before showing snackbar
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error creating event: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditEventSheet(CalendarProvider provider, CalendarEvent event) {
    // TODO: Implement edit event sheet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon')),
    );
  }
}

// Day Events Sheet
class DayEventsSheet extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> events;
  final Function(CalendarEvent) onEventTap;

  const DayEventsSheet({
    super.key,
    required this.date,
    required this.events,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(date),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Events List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _buildEventCard(context, event);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, CalendarEvent event) {
    final theme = Theme.of(context);
    final color = Color(
        int.parse(event.displayColor.substring(1), radix: 16) + 0xFF000000);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onEventTap(event);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!event.isAllDay) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTimeRange(context, event),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  event.type.displayName,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    return '${days[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }

  String _formatTimeRange(BuildContext context, CalendarEvent event) {
    final startTime = TimeOfDay.fromDateTime(event.startTime);
    if (event.endTime == null) {
      return startTime.format(context);
    }
    final endTime = TimeOfDay.fromDateTime(event.endTime!);
    return '${startTime.format(context)} - ${endTime.format(context)}';
  }
}

// Event Detail Sheet
class EventDetailSheet extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const EventDetailSheet({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(
        int.parse(event.displayColor.substring(1), radix: 16) + 0xFF000000);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            // Show dialog to sync to device calendar
                            final shouldSync = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Sync to Device Calendar'),
                                content: const Text(
                                    'Do you want to add this event to your device calendar?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Sync'),
                                  ),
                                ],
                              ),
                            );

                            if (shouldSync == true) {
                              try {
                                final deviceCalendarService =
                                    DeviceCalendarServiceFactory.create();
                                final eventId = await deviceCalendarService
                                    .addCalendarEvent(event: event);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(eventId != null
                                          ? 'Event synced to device calendar'
                                          : 'Failed to sync event to device calendar'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error syncing event: $e'),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.sync),
                          tooltip: 'Sync to Device Calendar',
                        ),
                        IconButton(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Event'),
                                content: const Text(
                                    'Are you sure you want to delete this event?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      onDelete();
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: theme.colorScheme.error,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        event.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Event Details
                      _buildDetailRow(
                        icon: Icons.category,
                        label: 'Type',
                        value: event.type.displayName,
                        color: color,
                      ),
                      if (!event.isAllDay)
                        _buildDetailRow(
                          icon: Icons.access_time,
                          label: 'Time',
                          value: _formatTimeRange(context, event),
                        ),
                      if (event.location != null)
                        _buildDetailRow(
                          icon: Icons.location_on,
                          label: 'Location',
                          value: event.location!,
                        ),
                      _buildDetailRow(
                        icon: Icons.calendar_today,
                        label: 'Date',
                        value: _formatDate(event.startTime),
                      ),
                      if (event.recurrence != RecurrenceType.none)
                        _buildDetailRow(
                          icon: Icons.repeat,
                          label: 'Recurrence',
                          value: _getRecurrenceText(event),
                        ),
                      if (event.hasReminder && event.reminderMinutes != null)
                        _buildDetailRow(
                          icon: Icons.notifications,
                          label: 'Reminder',
                          value: _getReminderText(event.reminderMinutes!),
                        ),
                      _buildDetailRow(
                        icon: Icons.person,
                        label: 'Created by',
                        value: event.createdByName,
                      ),
                      if (event.description != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Description',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.description!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color ?? Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTimeRange(BuildContext context, CalendarEvent event) {
    final startTime = TimeOfDay.fromDateTime(event.startTime);
    if (event.endTime == null) {
      return startTime.format(context);
    }
    final endTime = TimeOfDay.fromDateTime(event.endTime!);
    return '${startTime.format(context)} - ${endTime.format(context)}';
  }

  String _getRecurrenceText(CalendarEvent event) {
    switch (event.recurrence) {
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly on ${_getDayName(event.startTime.weekday)}';
      case RecurrenceType.monthly:
        return 'Monthly on day ${event.startTime.day}';
      case RecurrenceType.yearly:
        return 'Yearly on ${_formatMonthDay(event.startTime)}';
      case RecurrenceType.custom:
        return 'Custom';
      case RecurrenceType.none:
        return 'Does not repeat';
    }
  }

  String _formatMonthDay(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  String _getReminderText(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes before';
    } else if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} before';
    } else {
      final days = minutes ~/ 1440;
      return '$days ${days == 1 ? 'day' : 'days'} before';
    }
  }
}

// Create Event Sheet
class CreateEventSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onEventCreated;

  const CreateEventSheet({
    super.key,
    required this.onEventCreated,
  });

  @override
  State<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<CreateEventSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  EventType _selectedType = EventType.personal;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isAllDay = false;
  bool _hasReminder = false;
  int _reminderMinutes = 60;
  bool _syncToDeviceCalendar = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Event',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Field
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                      hintText: 'Enter event title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Type Dropdown
                  DropdownButtonFormField<EventType>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Event Type',
                      border: OutlineInputBorder(),
                    ),
                    items: EventType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // All Day Switch
                  SwitchListTile(
                    title: const Text('All Day Event'),
                    value: _isAllDay,
                    onChanged: (value) {
                      setState(() {
                        _isAllDay = value;
                        if (value) {
                          _startTime = null;
                          _endTime = null;
                        }
                      });
                    },
                  ),

                  if (!_isAllDay) ...[
                    // Start Time Picker
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _startTime = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Time',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _startTime?.format(context) ?? 'Select start time',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // End Time Picker
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime:
                              _endTime ?? _startTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _endTime = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Time (Optional)',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _endTime?.format(context) ?? 'Select end time',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Location Field
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location (Optional)',
                      hintText: 'Enter location',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reminder Switch
                  SwitchListTile(
                    title: const Text('Set Reminder'),
                    value: _hasReminder,
                    onChanged: (value) {
                      setState(() {
                        _hasReminder = value;
                      });
                    },
                  ),

                  if (_hasReminder) ...[
                    DropdownButtonFormField<int>(
                      initialValue: _reminderMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Reminder Time',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 15, child: Text('15 minutes before')),
                        DropdownMenuItem(
                            value: 30, child: Text('30 minutes before')),
                        DropdownMenuItem(
                            value: 60, child: Text('1 hour before')),
                        DropdownMenuItem(
                            value: 120, child: Text('2 hours before')),
                        DropdownMenuItem(
                            value: 1440, child: Text('1 day before')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _reminderMinutes = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Device Calendar Sync Switch
                  SwitchListTile(
                    title: const Text('Sync to Device Calendar'),
                    subtitle:
                        const Text('Add this event to your device calendar'),
                    value: _syncToDeviceCalendar,
                    onChanged: (value) {
                      setState(() {
                        _syncToDeviceCalendar = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description Field
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Enter event description',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (_titleController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter an event title'),
                          ),
                        );
                        return;
                      }

                      DateTime? startDateTime;
                      DateTime? endDateTime;

                      if (!_isAllDay && _startTime != null) {
                        startDateTime = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          _startTime!.hour,
                          _startTime!.minute,
                        );

                        if (_endTime != null) {
                          endDateTime = DateTime(
                            _selectedDate.year,
                            _selectedDate.month,
                            _selectedDate.day,
                            _endTime!.hour,
                            _endTime!.minute,
                          );
                        }
                      } else {
                        startDateTime = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                        );
                      }

                      widget.onEventCreated({
                        'title': _titleController.text,
                        'type': _selectedType,
                        'startTime': startDateTime,
                        'endTime': endDateTime,
                        'isAllDay': _isAllDay,
                        'location': _locationController.text.isEmpty
                            ? null
                            : _locationController.text,
                        'description': _descriptionController.text.isEmpty
                            ? null
                            : _descriptionController.text,
                        'hasReminder': _hasReminder,
                        'reminderMinutes':
                            _hasReminder ? _reminderMinutes : null,
                        'syncToDeviceCalendar': _syncToDeviceCalendar,
                      });

                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Create Event'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
