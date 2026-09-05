import 'dart:convert';
import 'package:http/http.dart' as http;

class AccountDeletionStatus {
  final String jobId;
  final DateTime scheduledFor;
  final String status;
  final DateTime requestedAt;
  const AccountDeletionStatus({required this.jobId, required this.scheduledFor, required this.status, required this.requestedAt});

  factory AccountDeletionStatus.fromJson(Map<String, dynamic> json) => AccountDeletionStatus(
    jobId: json['jobId'] as String,
    scheduledFor: DateTime.parse(json['scheduledFor'] as String),
    status: json['status'] as String,
    requestedAt: DateTime.parse(json['requestedAt'] as String),
  );
}

class AccountRepository {
  final String baseUrl;
  final http.Client client;
  final Future<String?> Function() accessToken;
  AccountRepository({required this.baseUrl, required this.client, required this.accessToken});

  Future<AccountDeletionStatus?> deletionStatus() async {
    final response = await client.get(Uri.parse('$baseUrl/api/v1/account/deletion'), headers: _headers(await accessToken()));
    if (response.statusCode >= 400) throw Exception('Unable to read deletion status');
    if (response.body == 'null') return null;
    return AccountDeletionStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AccountDeletionStatus> requestDeletion() async {
    final response = await client.post(Uri.parse('$baseUrl/api/v1/account/deletion'), headers: _headers(await accessToken()), body: jsonEncode({'confirm': true}));
    if (response.statusCode >= 400) throw Exception('Unable to request account deletion');
    return AccountDeletionStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> cancelDeletion() async {
    final response = await client.delete(Uri.parse('$baseUrl/api/v1/account/deletion'), headers: _headers(await accessToken()));
    if (response.statusCode >= 400) throw Exception('Unable to cancel account deletion');
  }

  Map<String, String> _headers(String? token) => {
    if (token != null) 'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
}
