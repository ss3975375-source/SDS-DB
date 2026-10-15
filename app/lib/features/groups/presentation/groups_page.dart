import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/group_repository.dart';
import '../domain/group.dart';
import '../../chats/chat_page.dart';
import '../../chats/offline_message_repository.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key, required this.repository, required this.currentUserId});
  final GroupRepository repository;
  final String currentUserId;

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late Future<List<Group>> _future = widget.repository.list();
  bool _busy = false;

  void _reload() => setState(() => _future = widget.repository.list());

  Future<String?> _textDialog(String title, String label, {String initial = '', int maxLength = 100}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true, maxLength: maxLength, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      _reload();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Group action failed: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final name = await _textDialog('Create group', 'Group name');
    if (name == null || name.isEmpty) return;
    await _run(() async { await widget.repository.create(name); }, 'Group created.');
  }

  Future<void> _rename(Group group) async {
    final name = await _textDialog('Rename group', 'Group name', initial: group.name);
    if (name == null || name.isEmpty) return;
    await _run(() async { await widget.repository.rename(group.conversationId, name); }, 'Group renamed.');
  }

  Future<void> _addMembers(Group group) async {
    final value = await _textDialog('Add members', 'User IDs separated by commas or new lines', maxLength: 4000);
    if (value == null || value.trim().isEmpty) return;
    final ids = value.split(RegExp(r'[,\s]+')).map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;
    await _run(() async { await widget.repository.addMembers(group.conversationId, ids); }, 'Member request completed.');
  }

  Future<void> _createInvite(Group group) async {
    try {
      final invite = await widget.repository.createInvite(group.conversationId);
      if (!mounted) return;
      final token = invite['token'] as String;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Group invite code'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Share this code with the people you want to invite. It expires automatically.'),
            const SizedBox(height: 12),
            SelectableText(token, style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Text('Expires: ${DateTime.parse(invite['expiresAt'] as String).toLocal()}'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: token));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied.')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy code'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create invite: $error')));
    }
  }

  Future<void> _joinInvite() async {
    final token = await _textDialog('Join a group', 'Group invite token', maxLength: 512);
    if (token == null || token.isEmpty) return;
    await _run(() async { await widget.repository.joinInvite(token); }, 'Joined group.');
  }

  Future<void> _leave(Group group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave ${group.name}?'),
        content: const Text('You may need a new invite to rejoin this group.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave group')),
        ],
      ),
    );
    if (confirm == true) await _run(() => widget.repository.leave(group.conversationId), 'Left group.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Groups'),
      actions: [
        IconButton(onPressed: _busy ? null : _joinInvite, tooltip: 'Join with invite', icon: const Icon(Icons.link)),
        IconButton(onPressed: _reload, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : _create,
      icon: const Icon(Icons.group_add),
      label: const Text('New group'),
    ),
    body: FutureBuilder<List<Group>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Could not load groups'),
          const SizedBox(height: 8),
          FilledButton(onPressed: _reload, child: const Text('Retry')),
        ]));
        final groups = snapshot.data ?? const <Group>[];
        if (groups.isEmpty) return const Center(child: Text('No groups yet. Create one or join with an invite.'));
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                title: Text(group.name),
                subtitle: Text('${group.memberCount} members • ${group.role}'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(
                  conversationId: group.conversationId,
                  conversationName: group.name,
                  currentUserId: widget.currentUserId,
                  repository: OfflineMessageRepository(api: widget.repository.api),
                ))),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') _rename(group);
                    if (value == 'members') _addMembers(group);
                    if (value == 'invite') _createInvite(group);
                    if (value == 'leave') _leave(group);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename group')),
                    PopupMenuItem(value: 'members', child: Text('Add members')),
                    PopupMenuItem(value: 'invite', child: Text('Create invite')),
                    PopupMenuItem(value: 'leave', child: Text('Leave group')),
                  ],
                ),
              ));
            },
          ),
        );
      },
    ),
  );
}
