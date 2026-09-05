import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/network/api_client.dart';
import '../domain/file_upload.dart';

class FileRepository {
  FileRepository(this.api, {http.Client? client}) : _client = client ?? http.Client();
  final ApiClient api;
  final http.Client _client;

  Future<FileUpload> initialize({required String conversationId, required File file, String? mime}) async {
    final result = await api.post('/api/v1/files/uploads', authenticated: true, body: {
      'conversationId': conversationId,
      'size': await file.length(),
      'name': file.uri.pathSegments.last,
      'mime': mime,
    });
    return FileUpload.fromJson(result);
  }

  Future<void> upload(FileUpload upload, File file, {void Function(int sent, int total)? onProgress}) async {
    final total = await file.length();
    if (total != upload.totalBytes) throw StateError('File changed after upload initialization');
    final existing = await api.get('/api/v1/files/uploads/${upload.uploadId}/parts', authenticated: true);
    final completed = <int>{for (final p in (existing['parts'] as List<dynamic>? ?? const []) as List) (p['partNumber'] as num).toInt()};
    var sent = 0;
    for (final p in (existing['parts'] as List<dynamic>? ?? const [])) { sent += (p['byteSize'] as num).toInt(); }
    onProgress?.call(sent, total);
    final parts = upload.partCount;
    for (var part = 1; part <= parts; part++) {
      if (completed.contains(part)) continue;
      final start = (part - 1) * upload.partSize;
      final endExclusive = start + upload.expectedPartSize(part);
      final signed = await api.post('/api/v1/files/uploads/${upload.uploadId}/parts', authenticated: true, body: {'partNumber': part});
      final request = http.StreamedRequest('PUT', Uri.parse(signed['url'] as String));
      request.headers['content-length'] = (signed['expectedBytes'] as num).toInt().toString();
      request.headers['content-type'] = 'application/octet-stream';
      await request.sink.addStream(file.openRead(start, endExclusive));
      final response = await request.send();
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Storage part upload failed (${response.statusCode})');
      final etag = response.headers['etag'];
      if (etag == null || etag.isEmpty) throw StateError('Storage did not return an ETag');
      await api.put('/api/v1/files/uploads/${upload.uploadId}/parts', authenticated: true, body: {
        'partNumber': part, 'etag': etag, 'byteSize': signed['expectedBytes'],
      });
      sent += signed['expectedBytes'] as int;
      onProgress?.call(sent, total);
    }
    await complete(upload.uploadId);
  }

  Future<Map<String, dynamic>> complete(String uploadId) => api.post('/api/v1/files/uploads/$uploadId/complete', authenticated: true);
  Future<void> abort(String uploadId) => api.delete('/api/v1/files/uploads/$uploadId', authenticated: true);
  Future<Map<String, dynamic>> downloadAuthorization(String attachmentId) => api.get('/api/v1/files/attachments/$attachmentId/download', authenticated: true);
}
