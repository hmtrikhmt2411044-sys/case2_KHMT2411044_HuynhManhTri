import 'dart:convert';
import 'api_client.dart';
import '../models/task.dart';
import '../models/task_share.dart';
import '../models/email_log.dart';
import '../models/task_activity.dart';

class TaskService {
  // Lấy danh sách công việc theo bộ lọc
  static Future<List<TaskModel>> getTasks({
    String type = 'all', // 'all', 'my_tasks', 'assigned', 'shared'
    String? status,
    String? priority,
    String? search,
    String? sortBy,
  }) async {
    final queryParams = <String, String>{'type': type};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;
    if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();
    if (sortBy != null && sortBy.isNotEmpty) queryParams['sortBy'] = sortBy;

    try {
      final queryString = Uri(queryParameters: queryParams).query;
      final res = await ApiClient.get('/tasks?$queryString', requireAuth: true);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] is List) {
          return (body['data'] as List).map((item) => TaskModel.fromJson(item)).toList();
        }
      }
    } catch (e) {
      // Bắt lỗi kết nối mạng để app không bị treo loading
      rethrow;
    }
    return [];
  }

  // Lấy chi tiết công việc kèm quyền hạn
  static Future<Map<String, dynamic>?> getTaskDetail(String id) async {
    final res = await ApiClient.get('/tasks/$id', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return {
          'task': TaskModel.fromJson(body['data']),
          'permission': body['permission'] ?? 'viewer',
        };
      }
    }
    return null;
  }

  // Tạo công việc mới
  static Future<TaskModel?> createTask({
    required String title,
    String? description,
    String? priority,
    String? status,
    DateTime? startDate,
    DateTime? dueDate,
    List<String>? assigneeIds,
    String? primaryAssigneeId,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
    };
    if (description != null) payload['description'] = description;
    if (priority != null) payload['priority'] = priority;
    if (status != null) payload['status'] = status;
    if (startDate != null) payload['startDate'] = startDate.toIso8601String();
    if (dueDate != null) payload['dueDate'] = dueDate.toIso8601String();
    if (assigneeIds != null) payload['assigneeIds'] = assigneeIds;
    if (primaryAssigneeId != null) payload['primaryAssigneeId'] = primaryAssigneeId;

    final res = await ApiClient.post('/tasks', body: payload, requireAuth: true);
    if (res.statusCode == 201) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return TaskModel.fromJson(body['data']);
      }
    }
    return null;
  }

  // Cập nhật thông tin công việc
  static Future<TaskModel?> updateTask(String id, Map<String, dynamic> updates) async {
    final res = await ApiClient.put('/tasks/$id', body: updates, requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return TaskModel.fromJson(body['data']);
      }
    }
    return null;
  }

  // Cập nhật trạng thái công việc
  static Future<bool> updateStatus(String id, String status) async {
    final res = await ApiClient.patch('/tasks/$id/status', body: {'status': status}, requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['success'] == true;
    }
    return false;
  }

  // Xóa công việc
  static Future<bool> deleteTask(String id) async {
    final res = await ApiClient.delete('/tasks/$id', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['success'] == true;
    }
    return false;
  }

  // Phân công công việc (Assign)
  static Future<TaskModel?> assignTask(
    String id, {
    required List<String> assigneeIds,
    String? primaryAssigneeId,
  }) async {
    final payload = {
      'assigneeIds': assigneeIds,
      'primaryAssigneeId': primaryAssigneeId,
    };
    final res = await ApiClient.post('/tasks/$id/assign', body: payload, requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return TaskModel.fromJson(body['data']);
      }
    }
    return null;
  }

  // Chia sẻ công việc
  static Future<bool> shareTask(String id, {required String targetUserId, required String permission}) async {
    final payload = {
      'targetUserId': targetUserId,
      'permission': permission,
    };
    final res = await ApiClient.post('/tasks/$id/share', body: payload, requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['success'] == true;
    }
    return false;
  }

  // Thu hồi chia sẻ
  static Future<bool> revokeShare(String id, String targetUserId) async {
    final res = await ApiClient.delete('/tasks/$id/share/$targetUserId', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['success'] == true;
    }
    return false;
  }

  // Lấy danh sách chia sẻ của công việc
  static Future<List<TaskShareModel>> getTaskShares(String id) async {
    final res = await ApiClient.get('/tasks/$id/shares', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] is List) {
        return (body['data'] as List).map((s) => TaskShareModel.fromJson(s)).toList();
      }
    }
    return [];
  }

  // Lấy lịch sử gửi email của công việc (Nhóm chức năng D)
  static Future<List<EmailLogModel>> getEmailLogs(String taskId) async {
    final res = await ApiClient.get('/tasks/$taskId/email-logs', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] is List) {
        return (body['data'] as List).map((e) => EmailLogModel.fromJson(e)).toList();
      }
    }
    return [];
  }


  // Lấy lịch sử hoạt động của công việc (Nhóm chức năng E)
  static Future<List<TaskActivityModel>> getTaskActivities(String taskId) async {
    final res = await ApiClient.get('/tasks/$taskId/activities', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] is List) {
        return (body['data'] as List).map((a) => TaskActivityModel.fromJson(a)).toList();
      }
    }
    return [];
  }

  // Thử gửi lại email thất bại (Nhóm chức năng D)
  static Future<bool> retryEmail(String logId) async {
    final res = await ApiClient.post('/email-logs/$logId/retry', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['success'] == true;
    }
    return false;
  }
}
