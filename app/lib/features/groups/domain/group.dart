class Group {
  const Group({required this.conversationId, required this.name, required this.createdBy, required this.role, required this.memberCount});
  final String conversationId, name, createdBy, role;
  final int memberCount;
  factory Group.fromJson(Map<String,dynamic> j)=>Group(
    conversationId:j['conversation_id'] as String,
    name:j['name'] as String,
    createdBy:j['created_by'] as String,
    role:j['role'] as String,
    memberCount:(j['member_count'] as num).toInt(),
  );
}
