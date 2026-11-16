import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại']);

  @override
  String toString() => message;
}

class ApiClient {
  static void Function()? onUnauthorized;
  static bool _isHandlingUnauthorized = false;

  static void resetSessionGuard() {
    _isHandlingUnauthorized = false;
  }

  static Future<Map<String, String>> _getHeaders({bool requireAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyToken);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<http.Response> _processResponse(http.Response response, bool requireAuth) async {
    if (requireAuth && response.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyToken);
      await prefs.remove(AppConstants.keyUser);

      if (!_isHandlingUnauthorized) {
        _isHandlingUnauthorized = true;
        onUnauthorized?.call();
      }
      throw UnauthorizedException();
    }
    return response;
  }

  static Future<http.Response> get(String endpoint, {bool requireAuth = false}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
    return _processResponse(res, requireAuth);
  }

  static Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final res = await http.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 15));
    return _processResponse(res, requireAuth);
  }

  static Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final res = await http.put(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 15));
    return _processResponse(res, requireAuth);
  }

  static Future<http.Response> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final res = await http.patch(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 15));
    return _processResponse(res, requireAuth);
  }

  static Future<http.Response> delete(String endpoint, {bool requireAuth = false}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 12));
    return _processResponse(res, requireAuth);
  }
}
