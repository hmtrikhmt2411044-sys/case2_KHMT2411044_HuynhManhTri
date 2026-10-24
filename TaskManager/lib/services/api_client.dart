import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiClient {
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

  static Future<http.Response> get(String endpoint, {bool requireAuth = false}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await http.get(uri, headers: headers);
  }

  static Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await http.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  static Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await http.put(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  static Future<http.Response> delete(String endpoint, {bool requireAuth = false}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await http.delete(uri, headers: headers);
  }
}
