import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String userId;
  final String? taskId;
  final String type; // 'assigned', 'shared', 'status_changed', 'deadline_approaching', 'completed', 'updated', 'general'
  final String title;
  final String message;
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    this.taskId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    String? tId;
    if (json['taskId'] != null) {
      if (json['taskId'] is Map<String, dynamic>) {
        tId = json['taskId']['_id']?.toString() ?? json['taskId']['id']?.toString();
      } else {
        tId = json['taskId'].toString();
      }
    }

    return AppNotification(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      taskId: tId,
      type: json['type'] ?? 'general',
      title: json['title'] ?? 'Thông báo',
      message: json['message'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // Label phân loại sự kiện
  String get typeLabel {
    switch (type) {
      case 'assigned':
        return 'Giao việc';
      case 'shared':
        return 'Chia sẻ';
      case 'status_changed':
        return 'Cập nhật';
      case 'completed':
        return 'Hoàn thành';
      case 'deadline_approaching':
        return 'Hạn chót';
      default:
        return 'Hệ thống';
    }
  }

  // Icon hiển thị theo loại
  IconData get typeIcon {
    switch (type) {
      case 'assigned':
        return Icons.assignment_ind_outlined;
      case 'shared':
        return Icons.share_outlined;
      case 'status_changed':
        return Icons.sync_alt_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'deadline_approaching':
        return Icons.alarm_on_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  // Màu sắc chủ đạo theo loại
  Color get typeColor {
    switch (type) {
      case 'assigned':
        return const Color(0xFF2563EB); // Blue
      case 'shared':
        return const Color(0xFF7C3AED); // Purple
      case 'status_changed':
        return const Color(0xFFF59E0B); // Amber
      case 'completed':
        return const Color(0xFF10B981); // Emerald
      case 'deadline_approaching':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  // Định dạng thời gian tương đối thân thiện (VD: "5 phút trước", "Hôm qua")
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
