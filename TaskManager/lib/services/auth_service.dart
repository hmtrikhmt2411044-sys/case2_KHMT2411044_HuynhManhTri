import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../utils/constants.dart';
import 'api_client.dart';

class AuthService {
  // 1. Đăng ký tài khoản bằng họ tên, email và mật khẩu
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post('/auth/register', body: {
        'fullName': fullName,
        'email': email,
        'password': password,
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        // Lưu token và thông tin user
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.keyToken, data['data']['token']);
        await prefs.setString(
          AppConstants.keyUser,
          jsonEncode(data['data']['user']),
        );
        return {'success': true, 'message': data['message'] ?? 'Đăng ký thành công'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Đăng ký thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }
}
