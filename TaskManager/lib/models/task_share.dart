import 'user.dart';

class TaskShareModel {
  final String id;
  final String taskId;
  final User user;
  final String permission; // 'viewer' | 'editor'
  final User? sharedBy;
  final DateTime? createdAt;

  TaskShareModel({
    required this.id,
    required this.taskId,
    required this.user,
    required this.permission,
    this.sharedBy,
    this.createdAt,
  });

  factory TaskShareModel.fromJson(Map<String, dynamic> json) {
    User u;
    if (json['userId'] is Map<String, dynamic>) {
      u = User.fromJson(json['userId']);
    } else {
      u = User(id: json['userId'] ?? '', fullName: 'Người dùng', email: '');
    }

    User? sb;
    if (json['sharedBy'] is Map<String, dynamic>) {
      sb = User.fromJson(json['sharedBy']);
    }

    return TaskShareModel(
      id: json['_id'] ?? json['id'] ?? '',
      taskId: json['taskId'] ?? '',
      user: u,
      permission: json['permission'] ?? 'viewer',
      sharedBy: sb,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  String get permissionLabel {
    return permission == 'editor' ? 'Chỉnh sửa' : 'Chỉ xem';
  }
}
