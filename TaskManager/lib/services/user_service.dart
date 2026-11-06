import 'dart:convert';
import 'api_client.dart';
import '../models/user.dart';

class UserService {
  // Lấy danh sách thành viên để phân công hoặc chia sẻ
  static Future<List<User>> searchUsers({String? query}) async {
    final endpoint = query != null && query.trim().isNotEmpty
        ? '/users?search=${Uri.encodeComponent(query.trim())}'
        : '/users';

    final res = await ApiClient.get(endpoint, requireAuth: true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] is List) {
        return (body['data'] as List).map((u) => User.fromJson(u)).toList();
      }
    }
    return [];
  }
}
