import 'dart:convert';
import 'package:http/http.dart' as http;

class ContactQrService {
  final String baseUrl;
  final http.Client client;
  final Future<String?> Function() accessToken;
  ContactQrService({required this.baseUrl, required this.client, required this.accessToken});

  Future<String> create({int expiresInSeconds=600, int maxUses=1}) async {
    final token=await accessToken();
    final r=await client.post(Uri.parse('$baseUrl/api/v1/contacts/qr'),headers:{
      'Content-Type':'application/json', if(token!=null)'Authorization':'Bearer $token'
    },body:jsonEncode({'expiresInSeconds':expiresInSeconds,'maxUses':maxUses}));
    if(r.statusCode>=400) throw Exception('Unable to create contact QR');
    final body=jsonDecode(r.body) as Map<String,dynamic>;
    final value=body['token'];
    if(value is! String || value.isEmpty) throw Exception('Invalid contact QR response');
    return value;
  }

  Future<void> consume(String qrToken) async {
    final token=await accessToken();
    final r=await client.post(Uri.parse('$baseUrl/api/v1/contacts/qr/consume'),headers:{
      'Content-Type':'application/json', if(token!=null)'Authorization':'Bearer $token'
    },body:jsonEncode({'token':qrToken}));
    if(r.statusCode>=400) throw Exception('Unable to use contact QR');
  }
}
