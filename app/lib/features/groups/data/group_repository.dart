import '../../../core/network/api_client.dart';
import '../domain/group.dart';

class GroupRepository {
  GroupRepository(this.api);
  final ApiClient api;

  Future<List<Group>> list() async {
    final data=await api.get('/api/v1/groups',authenticated:true);
    return (data['groups'] as List<dynamic>).map((e)=>Group.fromJson(e as Map<String,dynamic>)).toList(growable:false);
  }
  Future<Map<String,dynamic>> create(String name,{List<String> userIds=const []}) => api.post('/api/v1/groups',body:{'name':name,'userIds':userIds},authenticated:true);
  Future<Map<String,dynamic>> get(String conversationId)=>api.get('/api/v1/groups/$conversationId',authenticated:true);
  Future<Map<String,dynamic>> rename(String conversationId,String name)=>api.patch('/api/v1/groups/$conversationId',body:{'name':name},authenticated:true);
  Future<Map<String,dynamic>> addMembers(String conversationId,List<String> userIds)=>api.post('/api/v1/groups/$conversationId/members',body:{'userIds':userIds},authenticated:true);
  Future<Map<String,dynamic>> createInvite(String conversationId,{int ttlHours=24,int maxUses=1})=>api.post('/api/v1/groups/$conversationId/invites',body:{'ttlHours':ttlHours,'maxUses':maxUses},authenticated:true);
  Future<Map<String,dynamic>> joinInvite(String token)=>api.post('/api/v1/groups/join',body:{'token':token},authenticated:true);
  Future<void> leave(String conversationId)=>api.post('/api/v1/groups/$conversationId/leave',authenticated:true).then((_){});
}
