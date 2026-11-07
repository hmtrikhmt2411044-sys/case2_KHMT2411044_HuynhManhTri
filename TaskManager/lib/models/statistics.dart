class StatusStats {
  final int total;
  final int todo;
  final int inProgress;
  final int completed;
  final int completionRate;

  StatusStats({
    required this.total,
    required this.todo,
    required this.inProgress,
    required this.completed,
    required this.completionRate,
  });

  factory StatusStats.fromJson(Map<String, dynamic> json) {
    return StatusStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      todo: (json['todo'] as num?)?.toInt() ?? 0,
      inProgress: (json['inProgress'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      completionRate: (json['completionRate'] as num?)?.toInt() ?? 0,
    );
  }
}

class AssignmentStats {
  final int createdCount;
  final int assignedCount;
  final int primaryCount;

  AssignmentStats({
    required this.createdCount,
    required this.assignedCount,
    required this.primaryCount,
  });

  factory AssignmentStats.fromJson(Map<String, dynamic> json) {
    return AssignmentStats(
      createdCount: (json['createdCount'] as num?)?.toInt() ?? 0,
      assignedCount: (json['assignedCount'] as num?)?.toInt() ?? 0,
      primaryCount: (json['primaryCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class DeadlineStats {
  final int overdueCount;
  final int dueSoonCount;

  DeadlineStats({
    required this.overdueCount,
    required this.dueSoonCount,
  });

  factory DeadlineStats.fromJson(Map<String, dynamic> json) {
    return DeadlineStats(
      overdueCount: (json['overdueCount'] as num?)?.toInt() ?? 0,
      dueSoonCount: (json['dueSoonCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class OverviewStats {
  final StatusStats statusStats;
  final AssignmentStats assignmentStats;
  final DeadlineStats deadlineStats;

  OverviewStats({
    required this.statusStats,
    required this.assignmentStats,
    required this.deadlineStats,
  });

  factory OverviewStats.fromJson(Map<String, dynamic> json) {
    return OverviewStats(
      statusStats: StatusStats.fromJson(json['statusStats'] ?? {}),
      assignmentStats: AssignmentStats.fromJson(json['assignmentStats'] ?? {}),
      deadlineStats: DeadlineStats.fromJson(json['deadlineStats'] ?? {}),
    );
  }
}
