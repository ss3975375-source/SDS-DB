import '../../core/network/api_client.dart';

class AccountDeletionStatus {
  final String jobId;
  final DateTime scheduledFor;
  final String status;
  final DateTime requestedAt;

  const AccountDeletionStatus({
    required this.jobId,
    required this.scheduledFor,
    required this.status,
    required this.requestedAt,
  });

  factory AccountDeletionStatus.fromJson(Map<String, dynamic> json) => AccountDeletionStatus(
    jobId: json['jobId'] as String,
    scheduledFor: DateTime.parse(json['scheduledFor'] as String),
    status: json['status'] as String,
    requestedAt: DateTime.parse(json['requestedAt'] as String),
  );
}

class AccountRepository {
  AccountRepository(this.api);
  final ApiClient api;

  Future<AccountDeletionStatus?> deletionStatus() async {
    final data = await api.get('/api/v1/account/deletion', authenticated: true);
    if (data.isEmpty) return null;
    return AccountDeletionStatus.fromJson(data);
  }

  Future<AccountDeletionStatus> requestDeletion() async {
    final data = await api.post('/api/v1/account/deletion', authenticated: true, body: {'confirm': true});
    return AccountDeletionStatus.fromJson(data);
  }

  Future<void> cancelDeletion() async {
    await api.delete('/api/v1/account/deletion', authenticated: true);
  }
}
