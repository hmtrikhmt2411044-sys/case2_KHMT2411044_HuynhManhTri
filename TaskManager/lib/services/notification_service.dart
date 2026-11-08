import 'dart:convert';
import 'api_client.dart';
import '../models/app_notification.dart';

class NotificationService {
  // Lấy danh sách thông báo
  static Future<List<AppNotification>> getNotifications({bool? isRead, int limit = 50}) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
    if (isRead != null) {
      queryParams['isRead'] = isRead.toString();
    }

    final queryString = Uri(queryParameters: queryParams).query;
    final res = await ApiClient.get('/notifications?$queryString', requireAuth: true);

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] is List) {
        return (body['data'] as List).map((n) => AppNotification.fromJson(n)).toList();
      }
    }
    return [];
  }

  // Đếm số thông báo chưa đọc
  static Future<int> getUnreadCount() async {
    try {
      final res = await ApiClient.get('/notifications/unread-count', requireAuth: true);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['unreadCount'] != null) {
          return (body['unreadCount'] as num).toInt();
        }
      }
    } catch (_) {}
    return 0;
  }

  // Đánh dấu 1 thông báo là đã đọc
  static Future<bool> markAsRead(String id) async {
    final res = await ApiClient.patch('/notifications/$id/read', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['success'] == true;
    }
    return false;
  }

  // Đánh dấu tất cả thông báo là đã đọc
  static Future<bool> markAllAsRead() async {
    final res = await ApiClient.patch('/notifications/read-all', requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['success'] == true;
    }
    return false;
  }
}
