class SystemStats {
  final int totalUsers;
  final int studentCount;
  final int teacherCount;
  final int adminCount;
  final int activeSessions;
  final int recentActivityCount;

  SystemStats({
    required this.totalUsers,
    required this.studentCount,
    required this.teacherCount,
    required this.adminCount,
    required this.activeSessions,
    required this.recentActivityCount,
  });

  double get studentPercentage => totalUsers > 0 ? (studentCount / totalUsers) * 100 : 0;
  double get teacherPercentage => totalUsers > 0 ? (teacherCount / totalUsers) * 100 : 0;
  double get adminPercentage => totalUsers > 0 ? (adminCount / totalUsers) * 100 : 0;
}