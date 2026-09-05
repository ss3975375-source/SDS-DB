import '../../core/network/api_client.dart';

class FeelItPost {
  final String id;
  final String authorId;
  final String? text;
  final String? attachmentId;
  final DateTime createdAt;
  final DateTime expiresAt;
  const FeelItPost({required this.id,required this.authorId,this.text,this.attachmentId,required this.createdAt,required this.expiresAt});
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
}

class FeelItRepository {
  final ApiClient api;
  FeelItRepository(this.api);

  Future<List<FeelItPost>> list() async {
    final data=await api.get('/api/v1/feel-it',authenticated:true);
    final items=(data['items'] as List<dynamic>? ?? const []);
    return items.map((x){final j=x as Map<String,dynamic>;return FeelItPost(id:j['id'] as String,authorId:j['authorId'] as String,text:j['text'] as String?,attachmentId:j['attachmentId'] as String?,createdAt:DateTime.parse(j['createdAt'] as String),expiresAt:DateTime.parse(j['expiresAt'] as String));}).where((p)=>!p.isExpired).toList();
  }

  Future<FeelItPost> create({String? text,String? attachmentId,String visibility='contacts',List<String> userIds=const []}) async {
    final data=await api.post('/api/v1/feel-it',body:{if(text!=null&&text.trim().isNotEmpty)'text':text.trim(),if(attachmentId!=null)'attachmentId':attachmentId,'visibility':visibility,'userIds':userIds},authenticated:true);
    return _post(data);
  }
  Future<void> markViewed(String postId)=>api.post('/api/v1/feel-it/$postId/view',authenticated:true);
  Future<void> react(String postId,String reaction)=>api.put('/api/v1/feel-it/$postId/reaction',body:{'reaction':reaction},authenticated:true);
  Future<void> removeReaction(String postId)=>api.delete('/api/v1/feel-it/$postId/reaction',authenticated:true);
  Future<Map<String,dynamic>> reply(String postId,String body)=>api.post('/api/v1/feel-it/$postId/replies',body:{'body':body},authenticated:true);
  Future<List<Map<String,dynamic>>> viewers(String postId) async {final d=await api.get('/api/v1/feel-it/$postId/viewers',authenticated:true);return ((d['items'] as List<dynamic>? ?? const [])).cast<Map<String,dynamic>>();}
  Future<Map<String,dynamic>> media(String postId)=>api.get('/api/v1/feel-it/$postId/media',authenticated:true);
  Future<void> delete(String postId)=>api.delete('/api/v1/feel-it/$postId',authenticated:true);
  FeelItPost _post(Map<String,dynamic> j)=>FeelItPost(id:j['id'] as String,authorId:j['authorId'] as String,text:j['text'] as String?,attachmentId:j['attachmentId'] as String?,createdAt:DateTime.parse(j['createdAt'] as String),expiresAt:DateTime.parse(j['expiresAt'] as String));
}
