import 'user.dart';

class TaskModel {
  final String id;
  final String title;
  final String description;
  final User? createdBy;
  final List<User> assignees;
  final User? primaryAssignee;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String priority; // 'low', 'medium', 'high'
  final String status; // 'todo', 'in_progress', 'completed'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.createdBy,
    this.assignees = const [],
    this.primaryAssignee,
    this.startDate,
    this.dueDate,
    this.priority = 'medium',
    this.status = 'todo',
    this.createdAt,
    this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    // Parse createdBy
    User? creator;
    if (json['createdBy'] is Map<String, dynamic>) {
      creator = User.fromJson(json['createdBy']);
    } else if (json['createdBy'] is String && (json['createdBy'] as String).isNotEmpty) {
      creator = User(id: json['createdBy'], fullName: 'Người tạo', email: '');
    }

    // Parse primaryAssigneeId
    User? primary;
    if (json['primaryAssigneeId'] is Map<String, dynamic>) {
      primary = User.fromJson(json['primaryAssigneeId']);
    } else if (json['primaryAssigneeId'] is String && (json['primaryAssigneeId'] as String).isNotEmpty) {
      primary = User(id: json['primaryAssigneeId'], fullName: '', email: '');
    }

    // Parse assigneeIds
    List<User> listAssignees = [];
    if (json['assigneeIds'] is List) {
      for (var item in json['assigneeIds']) {
        if (item is Map<String, dynamic>) {
          listAssignees.add(User.fromJson(item));
        } else if (item is String && item.isNotEmpty) {
          listAssignees.add(User(id: item, fullName: '', email: ''));
        }
      }
    }

    return TaskModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      createdBy: creator,
      assignees: listAssignees,
      primaryAssignee: primary,
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'].toString()) : null,
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'].toString()) : null,
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'todo',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'startDate': startDate?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority,
      'status': status,
      'assigneeIds': assignees.map((a) => a.id).toList(),
      'primaryAssigneeId': primaryAssignee?.id,
    };
  }

  String get statusLabel {
    switch (status) {
      case 'in_progress':
        return 'Đang làm';
      case 'completed':
        return 'Hoàn thành';
      case 'todo':
      default:
        return 'Cần làm';
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'high':
        return 'Cao';
      case 'low':
        return 'Thấp';
      case 'medium':
      default:
        return 'Trung bình';
    }
  }

  bool get isOverdue {
    if (dueDate == null || status == 'completed') return false;
    return dueDate!.isBefore(DateTime.now());
  }
}
