import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/services/auth_service.dart';

String _makeJwtWithExp(int expSeconds) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}')).replaceAll('=', '');
  final payload = base64Url.encode(utf8.encode('{"id":"123","exp":$expSeconds}')).replaceAll('=', '');
  return '$header.$payload.fakesig';
}

void main() {
  group('AuthService.isTokenExpired', () {
    test('returns true for expired JWT', () {
      final pastExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600;
      expect(AuthService.isTokenExpired(_makeJwtWithExp(pastExp)), isTrue);
    });

    test('returns false for valid future JWT', () {
      final futureExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      expect(AuthService.isTokenExpired(_makeJwtWithExp(futureExp)), isFalse);
    });

    test('returns true for malformed token', () {
      expect(AuthService.isTokenExpired('not-a-jwt'), isTrue);
    });
  });
}
