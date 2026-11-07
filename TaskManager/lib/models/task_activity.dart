import 'package:flutter/material.dart';
import 'user.dart';

class TaskActivityModel {
  final String id;
  final String taskId;
  final User? user;
  final String action; // 'created', 'updated', 'assigned', 'shared', 'status_changed', 'share_revoked'
  final Map<String, dynamic> details;
  final DateTime createdAt;

  TaskActivityModel({
    required this.id,
    required this.taskId,
    this.user,
    required this.action,
    required this.details,
    required this.createdAt,
  });

  factory TaskActivityModel.fromJson(Map<String, dynamic> json) {
    User? u;
    if (json['userId'] is Map<String, dynamic>) {
      u = User.fromJson(json['userId']);
    } else if (json['userId'] != null) {
      u = User(id: json['userId'].toString(), fullName: 'Người dùng', email: '');
    }

    return TaskActivityModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      taskId: json['taskId']?.toString() ?? '',
      user: u,
      action: json['action'] ?? 'updated',
      details: json['details'] is Map<String, dynamic> ? json['details'] : {},
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // Tiêu đề sự kiện
  String get actionTitle {
    final actorName = user?.fullName ?? 'Thành viên';
    switch (action) {
      case 'created':
        return '$actorName đã tạo công việc này';
      case 'updated':
        return '$actorName đã cập nhật thông tin công việc';
      case 'assigned':
        return '$actorName đã cập nhật phân công thành viên';
      case 'shared':
        return '$actorName đã chia sẻ công việc';
      case 'share_revoked':
        return '$actorName đã thu hồi quyền chia sẻ';
      case 'status_changed':
        final st = details['status']?.toString();
        final stLabel = st == 'completed' ? 'Hoàn thành' : st == 'in_progress' ? 'Đang làm' : 'Cần làm';
        return '$actorName đã chuyển trạng thái sang "$stLabel"';
      default:
        return '$actorName đã thực hiện một thay đổi';
    }
  }

  // Icon loại hành động
  IconData get actionIcon {
    switch (action) {
      case 'created':
        return Icons.add_circle_outline;
      case 'status_changed':
        return Icons.change_circle_outlined;
      case 'assigned':
        return Icons.person_add_alt_outlined;
      case 'shared':
        return Icons.share_outlined;
      case 'share_revoked':
        return Icons.person_remove_outlined;
      default:
        return Icons.edit_note_outlined;
    }
  }

  // Màu sắc sự kiện
  Color get actionColor {
    switch (action) {
      case 'created':
        return const Color(0xFF2563EB); // Blue
      case 'status_changed':
        final st = details['status']?.toString();
        if (st == 'completed') return const Color(0xFF10B981); // Emerald
        if (st == 'in_progress') return const Color(0xFFF59E0B); // Amber
        return const Color(0xFF64748B); // Slate
      case 'assigned':
        return const Color(0xFF0284C7); // Sky
      case 'shared':
        return const Color(0xFF7C3AED); // Purple
      case 'share_revoked':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF475569);
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}
