import 'dart:convert';
import 'package:http/http.dart' as http;
import '../error/app_exception.dart';
import '../storage/secure_session_store.dart';

class ApiClient {
  ApiClient({required this.baseUrl, required this.sessionStore, http.Client? client}) : _client = client ?? http.Client();
  final String baseUrl;
  final SecureSessionStore sessionStore;
  final http.Client _client;

  Future<Map<String, dynamic>> post(String path, {Object? body, bool authenticated = false}) async {
    var response = await _send(path, body: body, authenticated: authenticated);
    if (authenticated && response.statusCode == 401) {
      final refreshed = await _refresh();
      if (refreshed) response = await _send(path, body: body, authenticated: true);
    }
    return _decode(response);
  }

  Future<Map<String, dynamic>> get(String path, {bool authenticated = false}) async {
    var response = await _send(path, authenticated: authenticated, method: 'GET');
    if (authenticated && response.statusCode == 401) {
      final refreshed = await _refresh();
      if (refreshed) response = await _send(path, authenticated: true, method: 'GET');
    }
    return _decode(response);
  }


  Future<Map<String, dynamic>> patch(String path, {Object? body, bool authenticated = false}) async {
    var response = await _send(path, body: body, authenticated: authenticated, method: 'PATCH');
    if (authenticated && response.statusCode == 401) {
      final refreshed = await _refresh();
      if (refreshed) response = await _send(path, body: body, authenticated: true, method: 'PATCH');
    }
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(String path, {Object? body, bool authenticated = false}) async {
    var response = await _send(path, body: body, authenticated: authenticated, method: 'PUT');
    if (authenticated && response.statusCode == 401) { final refreshed = await _refresh(); if (refreshed) response = await _send(path, body: body, authenticated: true, method: 'PUT'); }
    return _decode(response);
  }

  Future<void> delete(String path, {bool authenticated = false}) async {
    var response = await _send(path, authenticated: authenticated, method: 'DELETE');
    if (authenticated && response.statusCode == 401) { final refreshed = await _refresh(); if (refreshed) response = await _send(path, authenticated: true, method: 'DELETE'); }
    _decode(response);
  }

  Future<http.Response> _send(String path, {Object? body, bool authenticated = false, String method = 'POST'}) async {
    final headers = {'content-type': 'application/json', 'accept': 'application/json'};
    if (authenticated) {
      final token = await sessionStore.accessToken();
      if (token != null) headers['authorization'] = 'Bearer $token';
    }
    final uri = Uri.parse('$baseUrl$path');
    if (method == 'GET') return _client.get(uri, headers: headers);
    if (method == 'DELETE') return _client.delete(uri, headers: headers);
    if (method == 'PATCH') return _client.patch(uri, headers: headers, body: body == null ? null : jsonEncode(body));
    if (method == 'PUT') return _client.put(uri, headers: headers, body: body == null ? null : jsonEncode(body));
    return _client.post(uri, headers: headers, body: body == null ? null : jsonEncode(body));
  }

  Future<bool> _refresh() async {
    final refresh = await sessionStore.refreshToken();
    if (refresh == null) return false;
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/auth/refresh'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (response.statusCode != 200) { await sessionStore.clear(); return false; }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      await sessionStore.save(accessToken: json['accessToken'] as String, refreshToken: json['refreshToken'] as String);
      return true;
    } catch (_) { return false; }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException((data['error'] as String?) ?? 'Request failed', code: '${response.statusCode}');
    }
    return data;
  }
}
