import 'dart:convert';
import 'api_client.dart';
import '../models/task.dart';

class TaskService {
  // 1. Lấy danh sách công việc theo bộ lọc
  static Future<List<TaskModel>> getTasks({
    String type = 'all', // 'all', 'my_tasks'
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

    final queryString = Uri(queryParameters: queryParams).query;
    final res = await ApiClient.get('/tasks?$queryString', requireAuth: true);

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] is List) {
        return (body['data'] as List).map((item) => TaskModel.fromJson(item)).toList();
      }
    }
    return [];
  }

  // 2. Lấy chi tiết công việc
  static Future<Map<String, dynamic>?> getTaskDetail(String id) async {
    final res = await ApiClient.get('/tasks/$id', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return {
          'task': TaskModel.fromJson(body['data']),
          'permission': body['permission'] ?? 'owner',
        };
      }
    }
    return null;
  }

  // 3. Tạo công việc mới
  static Future<TaskModel?> createTask({
    required String title,
    String? description,
    String? priority,
    String? status,
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      if (description != null) 'description': description,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
    };

    final res = await ApiClient.post('/tasks', body: payload, requireAuth: true);
    if (res.statusCode == 201) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return TaskModel.fromJson(body['data']);
      }
    }
    return null;
  }

  // 4. Cập nhật thông tin công việc
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

  // 5. Cập nhật trạng thái công việc
  static Future<bool> updateStatus(String id, String status) async {
    final res = await ApiClient.patch('/tasks/$id/status', body: {'status': status}, requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['success'] == true;
    }
    return false;
  }

  // 6. Xóa công việc
  static Future<bool> deleteTask(String id) async {
    final res = await ApiClient.delete('/tasks/$id', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['success'] == true;
    }
    return false;
  }
}
