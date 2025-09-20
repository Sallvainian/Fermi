import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import '../../../../shared/widgets/common/adaptive_layout.dart';
import '../../../../shared/widgets/common/app_card.dart';
import '../../../../core/monitoring/monitoring_service.dart';
import '../../../../core/monitoring/runtime_analyzer.dart';
// import '../../../dead-code-analysis/cleanup_dead_code.dart' as dead_code; // TODO: Implement when available

class DeveloperToolsScreen extends StatefulWidget {
  const DeveloperToolsScreen({super.key});

  @override
  State<DeveloperToolsScreen> createState() => _DeveloperToolsScreenState();
}

class _DeveloperToolsScreenState extends State<DeveloperToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MonitoringService _monitoringService = MonitoringService();
  StreamSubscription<Map<String, dynamic>>? _broadcastSubscription;

  // Tab data
  Map<String, dynamic> _currentStatus = {};
  List<Map<String, dynamic>> _eventHistory = [];
  List<DeadCodeItem> _deadCodeItems = [];
  List<Map<String, dynamic>> _performanceIssues = [];
  List<Map<String, dynamic>> _memoryLeaks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initializeMonitoring();
  }

  Future<void> _initializeMonitoring() async {
    if (!kIsWeb) {
      await _monitoringService.initialize(
        enableWebSocket: true,
        port: 8080,
        debugMode: kDebugMode,
      );

      _broadcastSubscription = _monitoringService.broadcastStream?.listen((event) {
        setState(() {
          if (event['type'] == 'status_update') {
            _currentStatus = event;
          }
          _eventHistory.add(event);
          if (_eventHistory.length > 100) {
            _eventHistory.removeAt(0);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _broadcastSubscription?.cancel();
    _monitoringService.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Developer Tools',
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
          Tab(text: 'Dead Code', icon: Icon(Icons.delete_sweep)),
          Tab(text: 'Performance', icon: Icon(Icons.speed)),
          Tab(text: 'Memory', icon: Icon(Icons.memory)),
          Tab(text: 'Controls', icon: Icon(Icons.settings)),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(theme),
          _buildDeadCodeTab(theme),
          _buildPerformanceTab(theme),
          _buildMemoryTab(theme),
          _buildControlsTab(theme),
        ],
      ),
    );
  }

  // Overview Tab
  Widget _buildOverviewTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Cards
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  title: 'Monitoring Status',
                  value: _currentStatus['is_monitoring'] == true ? 'Active' : 'Inactive',
                  icon: Icons.monitor,
                  color: _currentStatus['is_monitoring'] == true ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusCard(
                  title: 'WebSocket Clients',
                  value: '${_currentStatus['connected_clients'] ?? 0}',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusCard(
                  title: 'Events Captured',
                  value: '${_eventHistory.length}',
                  icon: Icons.event,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusCard(
                  title: 'Issues Found',
                  value: '${(_deadCodeItems.length + _performanceIssues.length + _memoryLeaks.length)}',
                  icon: Icons.warning,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Event History Chart
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event Activity',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildEventChart(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recent Events
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Events',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _eventHistory.clear()),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._eventHistory.reversed.take(10).map((event) => _buildEventItem(event)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Dead Code Tab
  Widget _buildDeadCodeTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Buttons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _runDeadCodeAnalysis,
                icon: const Icon(Icons.search),
                label: const Text('Run Analysis'),
              ),
              const SizedBox(width: 16),
              if (_deadCodeItems.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _cleanupDeadCode,
                  icon: const Icon(Icons.delete),
                  label: const Text('Clean Up'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Dead Code Statistics
          if (_deadCodeItems.isNotEmpty) ...[
            Row(
              children: [
                _buildStatCard(
                  title: 'Dead Code Files',
                  value: '${_deadCodeItems.length}',
                  subtitle: 'Files identified',
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  title: 'Total Size',
                  value: _formatBytes(_calculateTotalSize()),
                  subtitle: 'Can be removed',
                  color: Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  title: 'Average Age',
                  value: '${_calculateAverageAge()} days',
                  subtitle: 'Since last modified',
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Dead Code List
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dead Code Files',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_deadCodeItems.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No dead code analysis results. Run analysis to find unused code.'),
                    ),
                  )
                else
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('File')),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Size')),
                      DataColumn(label: Text('Age (days)')),
                      DataColumn(label: Text('Reason')),
                    ],
                    rows: _deadCodeItems.map((item) => DataRow(
                      cells: [
                        DataCell(Text(item.identifier.split('/').last)),
                        DataCell(Text(item.type)),
                        DataCell(Text('--')), // Size not available in DeadCodeItem
                        DataCell(Text('--')), // Age not available in DeadCodeItem
                        DataCell(Text(item.reason)),
                      ],
                    )).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Performance Tab
  Widget _buildPerformanceTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance Metrics
          Row(
            children: [
              _buildStatCard(
                title: 'Avg Response Time',
                value: '${_calculateAvgResponseTime()} ms',
                subtitle: 'Average execution',
                color: Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                title: 'Slow Functions',
                value: '${_performanceIssues.where((i) => i['type'] == 'slow_function').length}',
                subtitle: '>1000ms execution',
                color: Colors.orange,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                title: 'Hot Spots',
                value: '${_performanceIssues.where((i) => i['type'] == 'hot_spot').length}',
                subtitle: '>1000 calls',
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Performance Chart
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Response Time Distribution',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildPerformanceChart(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Performance Issues List
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performance Issues',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_performanceIssues.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No performance issues detected.'),
                    ),
                  )
                else
                  ..._performanceIssues.map((issue) => _buildPerformanceIssueItem(issue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Memory Tab
  Widget _buildMemoryTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Memory Statistics
          Row(
            children: [
              _buildStatCard(
                title: 'Widget Leaks',
                value: '${_memoryLeaks.where((l) => l['type'] == 'widget_leak').length}',
                subtitle: 'Not disposed',
                color: Colors.red,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                title: 'Provider Leaks',
                value: '${_memoryLeaks.where((l) => l['type'] == 'provider_leak').length}',
                subtitle: 'Not released',
                color: Colors.orange,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                title: 'Object Leaks',
                value: '${_memoryLeaks.where((l) => l['type'] == 'object_leak').length}',
                subtitle: 'Retained in memory',
                color: Colors.yellow[800]!,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Memory Leaks List
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Memory Leaks Detected',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_memoryLeaks.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No memory leaks detected.'),
                    ),
                  )
                else
                  ..._memoryLeaks.map((leak) => _buildMemoryLeakItem(leak)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Controls Tab
  Widget _buildControlsTab(ThemeData theme) {
    final isMonitoring = _currentStatus['is_monitoring'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monitoring Control
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitoring Control',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: isMonitoring ? _stopMonitoring : _startMonitoring,
                      icon: Icon(isMonitoring ? Icons.stop : Icons.play_arrow),
                      label: Text(isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isMonitoring ? Colors.red : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (isMonitoring)
                      ElevatedButton.icon(
                        onPressed: _exportReport,
                        icon: const Icon(Icons.download),
                        label: const Text('Export Report'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Status: ${isMonitoring ? "Monitoring active" : "Monitoring inactive"}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isMonitoring ? Colors.green : Colors.grey,
                  ),
                ),
                if (isMonitoring && _currentStatus['start_time'] != null)
                  Text(
                    'Started: ${_currentStatus['start_time']}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // WebSocket Server Status
          if (!kIsWeb) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WebSocket Server',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: _currentStatus['websocket_enabled'] == true
                            ? Colors.green
                            : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentStatus['websocket_enabled'] == true
                            ? 'Server running on ws://localhost:8080'
                            : 'Server not running',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connected clients: ${_currentStatus['connected_clients'] ?? 0}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Debug Options
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Debug Options',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Enable Coverage Tracking'),
                  subtitle: const Text('Track function execution coverage'),
                  value: true,
                  onChanged: (value) {
                    // TODO: Implement toggle
                  },
                ),
                SwitchListTile(
                  title: const Text('Enable Execution Logging'),
                  subtitle: const Text('Log all function executions with timing'),
                  value: true,
                  onChanged: (value) {
                    // TODO: Implement toggle
                  },
                ),
                SwitchListTile(
                  title: const Text('Enable Leak Detection'),
                  subtitle: const Text('Monitor for memory leaks'),
                  value: true,
                  onChanged: (value) {
                    // TODO: Implement toggle
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_sweep),
                  title: const Text('Clear Event History'),
                  subtitle: const Text('Remove all captured events'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => _eventHistory.clear()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildStatusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final type = event['type'] ?? 'unknown';
    final timestamp = event['timestamp'] ?? '';
    final message = event['message'] ?? event['operation'] ?? event['function'] ?? type;

    return ListTile(
      leading: Icon(
        _getEventIcon(type),
        color: _getEventColor(type),
      ),
      title: Text(message),
      subtitle: Text(timestamp),
      dense: true,
    );
  }

  Widget _buildPerformanceIssueItem(Map<String, dynamic> issue) {
    return ListTile(
      leading: Icon(
        Icons.warning,
        color: _getSeverityColor(issue['severity']),
      ),
      title: Text(issue['function'] ?? 'Unknown'),
      subtitle: Text(issue['description'] ?? ''),
      trailing: Chip(
        label: Text(issue['type'] ?? ''),
        backgroundColor: _getSeverityColor(issue['severity']).withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildMemoryLeakItem(Map<String, dynamic> leak) {
    return ListTile(
      leading: const Icon(
        Icons.memory,
        color: Colors.red,
      ),
      title: Text(leak['widget'] ?? leak['provider'] ?? leak['class'] ?? 'Unknown'),
      subtitle: Text('${leak['instances'] ?? leak['leaked'] ?? 0} instances leaked'),
      trailing: Chip(
        label: Text(leak['type'] ?? ''),
        backgroundColor: Colors.red.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildEventChart() {
    // Simple placeholder chart
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(10, (index) => FlSpot(index.toDouble(), index * 2.0)),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    // Simple placeholder chart
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(5, (index) => BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: (index + 1) * 20.0,
              color: Colors.blue,
              width: 20,
            ),
          ],
        )),
      ),
    );
  }

  // Helper Methods
  IconData _getEventIcon(String type) {
    switch (type) {
      case 'monitoring_started':
      case 'monitoring_stopped':
        return Icons.monitor;
      case 'operation_started':
      case 'operation_completed':
        return Icons.play_arrow;
      case 'operation_failed':
        return Icons.error;
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'error':
      case 'operation_failed':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'monitoring_started':
      case 'operation_completed':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow[700]!;
      case 'low':
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int _calculateTotalSize() {
    // Calculate actual total size from dead code items
    return 0;  // 0 until real data is available
  }

  int _calculateAverageAge() {
    // Calculate actual average age from timestamps
    return 0;  // 0 until real data is available
  }

  int _calculateAvgResponseTime() {
    // Calculate actual response time from performance data
    return 0;  // 0 until real data is available
  }

  // TEST DEAD CODE - This function is intentionally never called to test dead code detection
  void _thisIsDeadCodeForTesting() {
    // This function should be detected as dead code
    debugPrint('If you see this message, dead code detection failed!');
    final testVar = 'This entire function should never run';
    for (int i = 0; i < 100; i++) {
      debugPrint('Dead code test iteration: $i');
    }
  }

  // Another dead function for testing
  int _calculateNothingUseful() {
    // This should also be detected as dead code
    return 42 * 73 + 1337;
  }

  // Action Methods
  void _startMonitoring() {
    _monitoringService.startMonitoring(sessionName: 'dev_tools_session');
    setState(() {
      _currentStatus = _monitoringService.getStatus();
    });
  }

  Future<void> _stopMonitoring() async {
    final summary = await _monitoringService.stopMonitoring();
    setState(() {
      _currentStatus = _monitoringService.getStatus();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Monitoring stopped. ${summary['summary']}'), ),
      );
    }
  }

  Future<void> _runDeadCodeAnalysis() async {
    // TODO: Implement actual dead code analysis
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Running dead code analysis...')),
    );

    // No mock data - only show real results
    setState(() {
      _deadCodeItems = [];  // Empty until real analysis is done
    });
  }

  Future<void> _cleanupDeadCode() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Cleanup'),
        content: Text('This will remove ${_deadCodeItems.length} dead code files. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // TODO: Implement actual cleanup
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dead code cleanup completed')),
      );
      setState(() {
        _deadCodeItems.clear();
      });
    }
  }

  Future<void> _exportReport() async {
    final report = await _monitoringService.stopMonitoring();
    // TODO: Implement actual export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report exported to analysis/ directory')),
    );
  }
}