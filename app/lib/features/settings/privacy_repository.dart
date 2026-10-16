import '../../core/network/api_client.dart';
import 'privacy_settings.dart';

class PrivacyRepository {
  PrivacyRepository(this.api);
  final ApiClient api;

  Future<PrivacySettings> get() async {
    final data = await api.get('/api/v1/privacy', authenticated: true);
    return PrivacySettings.fromJson(data);
  }

  Future<PrivacySettings> update(PrivacySettings settings) async {
    final data = await api.put('/api/v1/privacy', authenticated: true, body: settings.toJson());
    return PrivacySettings.fromJson(data);
  }
}
