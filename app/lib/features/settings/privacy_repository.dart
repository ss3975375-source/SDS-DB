import 'dart:convert';
import 'package:http/http.dart' as http;
import 'privacy_settings.dart';

class PrivacyRepository {
  final String baseUrl;
  final http.Client client;
  final Future<String?> Function() accessToken;

  PrivacyRepository({required this.baseUrl, required this.client, required this.accessToken});

  Future<PrivacySettings> get() async {
    final token = await accessToken();
    final response = await client.get(Uri.parse('$baseUrl/api/v1/privacy'), headers: _headers(token));
    if (response.statusCode >= 400) throw Exception('Unable to read privacy settings');
    return PrivacySettings.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PrivacySettings> update(PrivacySettings settings) async {
    final token = await accessToken();
    final response = await client.put(Uri.parse('$baseUrl/api/v1/privacy'), headers: _headers(token), body: jsonEncode(settings.toJson()));
    if (response.statusCode >= 400) throw Exception('Unable to update privacy settings');
    return PrivacySettings.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}
