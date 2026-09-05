import 'dart:convert';
import 'package:http/http.dart' as http;

class ContactRepository {
  final String baseUrl;
  final http.Client client;
  final Future<String?> Function() accessToken;

  ContactRepository({
    required this.baseUrl,
    required this.client,
    required this.accessToken,
  });

  Future<void> sendRequest(String userId) async {
    final token = await accessToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/v1/contacts/requests'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'userId': userId}),
    );
    if (response.statusCode >= 400) {
      throw Exception('Unable to send contact request');
    }
  }

  Future<void> acceptRequest(String requestId) async {
    final token = await accessToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/v1/contacts/requests/$requestId/accept'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 400) {
      throw Exception('Unable to accept contact request');
    }
  }

  Future<void> declineRequest(String requestId) async {
    final token = await accessToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/v1/contacts/requests/$requestId/decline'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 400) {
      throw Exception('Unable to decline contact request');
    }
  }

  Future<void> removeContact(String userId) async {
    final token = await accessToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/v1/contacts/$userId'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 400) {
      throw Exception('Unable to remove contact');
    }
  }
}
