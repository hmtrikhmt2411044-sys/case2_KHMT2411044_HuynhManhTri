import 'dart:convert';
import 'api_client.dart';
import '../models/statistics.dart';

class StatisticsService {
  // Lấy dữ liệu tổng quan thống kê
  static Future<OverviewStats?> getOverview() async {
    final res = await ApiClient.get('/statistics/overview', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return OverviewStats.fromJson(body['data']);
      }
    }
    return null;
  }

  // Lấy thống kê theo trạng thái
  static Future<StatusStats?> getStatusStats() async {
    final res = await ApiClient.get('/statistics/tasks', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return StatusStats.fromJson(body['data']);
      }
    }
    return null;
  }

  // Lấy thống kê phân công
  static Future<AssignmentStats?> getAssignmentStats() async {
    final res = await ApiClient.get('/statistics/assignments', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return AssignmentStats.fromJson(body['data']);
      }
    }
    return null;
  }

  // Lấy thống kê thời hạn
  static Future<DeadlineStats?> getDeadlineStats() async {
    final res = await ApiClient.get('/statistics/deadlines', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return DeadlineStats.fromJson(body['data']);
      }
    }
    return null;
  }
}
