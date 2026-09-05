import 'dart:convert';
import 'package:http/http.dart' as http;
import 'notification_preferences.dart';

class NotificationRepository {
  final String baseUrl;
  final http.Client client;
  final Future<String?> Function() accessToken;

  NotificationRepository({
    required this.baseUrl,
    required this.client,
    required this.accessToken,
  });

  Future<void> savePreferences(NotificationPreferences preferences) async {
    final token=await accessToken();
    final r=await client.put(
      Uri.parse('$baseUrl/api/v1/notifications/preferences'),
      headers:{
        'Content-Type':'application/json',
        if(token!=null)'Authorization':'Bearer $token',
      },
      body:jsonEncode(preferences.toJson()),
    );
    if(r.statusCode>=400) throw Exception('Unable to save notification preferences');
  }

  Future<void> registerDevice({
    required String pushToken,
    required String platform,
    String? appVersion,
  }) async {
    final token=await accessToken();
    final r=await client.post(
      Uri.parse('$baseUrl/api/v1/notifications/devices'),
      headers:{
        'Content-Type':'application/json',
        if(token!=null)'Authorization':'Bearer $token',
      },
      body:jsonEncode({
        'token':pushToken,
        'platform':platform,
        if(appVersion!=null)'appVersion':appVersion,
      }),
    );
    if(r.statusCode>=400) throw Exception('Unable to register notification device');
  }
}
