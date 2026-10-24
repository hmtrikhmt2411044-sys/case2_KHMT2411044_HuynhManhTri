import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../utils/constants.dart';
import 'api_client.dart';

class AuthService {
  // 1. Đăng ký tài khoản
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

  // 2. Đăng nhập
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post('/auth/login', body: {
        'email': email,
        'password': password,
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.keyToken, data['data']['token']);
        await prefs.setString(
          AppConstants.keyUser,
          jsonEncode(data['data']['user']),
        );
        return {'success': true, 'message': data['message'] ?? 'Đăng nhập thành công'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Đăng nhập thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  // 3. Đăng xuất
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyToken);
    await prefs.remove(AppConstants.keyUser);
  }

  // 4. Lấy thông tin người dùng từ máy chủ (Profile)
  static Future<User?> getProfile() async {
    try {
      final response = await ApiClient.get('/auth/me', requireAuth: true);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final user = User.fromJson(data['data']);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.keyUser, jsonEncode(user.toJson()));
          return user;
        }
      }
    } catch (e) {
      // Fallback lấy từ local nếu offline
      return await getLocalUser();
    }
    return await getLocalUser();
  }

  // 5. Cập nhật thông tin cá nhân
  static Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String? avatarUrl,
  }) async {
    try {
      final body = <String, dynamic>{'fullName': fullName};
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl;

      final response = await ApiClient.put(
        '/auth/me',
        body: body,
        requireAuth: true,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final user = User.fromJson(data['data']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.keyUser, jsonEncode(user.toJson()));
        return {'success': true, 'message': data['message'] ?? 'Cập nhật thành công', 'user': user};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Cập nhật thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // 6. Đổi mật khẩu
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await ApiClient.put(
        '/auth/change-password',
        body: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
        requireAuth: true,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message'] ?? 'Đổi mật khẩu thành công'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Đổi mật khẩu thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // Tiện ích kiểm tra đăng nhập
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyToken);
    return token != null && token.isNotEmpty;
  }

  static Future<User?> getLocalUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(AppConstants.keyUser);
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }
}
