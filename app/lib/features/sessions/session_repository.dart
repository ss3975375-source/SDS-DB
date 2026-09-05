import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_models.dart';

class SessionRepository {
  final String baseUrl;
  final http.Client client;
  final Future<String?> Function() accessToken;

  SessionRepository({
    required this.baseUrl,
    required this.client,
    required this.accessToken,
  });

  Future<List<DeviceSession>> list() async {
    final token = await accessToken();
    final response = await client.get(
      Uri.parse('$baseUrl/api/v1/sessions'),
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 400) {
      throw Exception('Unable to load active sessions');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>? ?? const [])
        .map((e) => DeviceSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> revoke(String sessionId) async {
    final token = await accessToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/v1/sessions/$sessionId/revoke'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 400) {
      throw Exception('Unable to revoke session');
    }
  }

  Future<void> revokeOthers() async {
    final token = await accessToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/v1/sessions/revoke-others'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 400) {
      throw Exception('Unable to revoke other sessions');
    }
  }

  Future<void> revokeAll() async {
    final token = await accessToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/v1/sessions/revoke-all'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 400) {
      throw Exception('Unable to revoke sessions');
    }
  }
}
