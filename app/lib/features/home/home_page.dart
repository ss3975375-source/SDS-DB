import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/security/app_lock_settings_page.dart';
import '../authentication/auth_repository.dart';
import '../authentication/google_auth_service.dart';
import '../chats/chat_page.dart';
import '../chats/conversation_repository.dart';
import '../chats/offline_message_repository.dart';
import '../contacts/contacts_page.dart';
import '../feel_it/feel_it_page.dart';
import '../feel_it/feel_it_repository.dart';
import '../groups/data/group_repository.dart';
import '../groups/presentation/groups_page.dart';
import '../sessions/session_repository.dart';
import '../sessions/sessions_page.dart';
import '../settings/privacy_repository.dart';
import '../settings/privacy_page.dart';
import '../settings/account_repository.dart';
import '../settings/account_deletion_page.dart';
import '../notifications/notification_repository.dart';
import '../notifications/notifications_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.googleAuth,
    required this.auth,
    required this.api,
    required this.lockController,
    required this.currentUserId,
  });

  final GoogleAuthService googleAuth;
  final AuthRepository auth;
  final ApiClient api;
  final AppLockController lockController;
  final String currentUserId;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  Future<void> _signOut() async {
    await widget.auth.signOut();
    if (mounted) context.go('/login');
  }

  void _openGroups() => Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => GroupsPage(
      repository: GroupRepository(widget.api),
      currentUserId: widget.currentUserId,
    ),
  ));

  @override
  Widget build(BuildContext context) {
    final pages = [
      _ChatsSection(
        api: widget.api,
        currentUserId: widget.currentUserId,
        onGroups: _openGroups,
        onContacts: () => setState(() => index = 1),
      ),
      ContactsPage(api: widget.api, currentUserId: widget.currentUserId),
      const _FilesSection(),
      FeelItPage(repository: FeelItRepository(widget.api)),
      _SecurityPage(
        api: widget.api,
        lockController: widget.lockController,
        onSignOut: _signOut,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SDS-DB'),
        actions: [
          IconButton(
            onPressed: () => widget.lockController.lock(),
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock app',
          ),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Files'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'Feel It'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Security'),
        ],
      ),
    );
  }
}

class _ChatsSection extends StatefulWidget {
  const _ChatsSection({
    required this.api,
    required this.currentUserId,
    required this.onGroups,
    required this.onContacts,
  });

  final ApiClient api;
  final String currentUserId;
  final VoidCallback onGroups;
  final VoidCallback onContacts;

  @override
  State<_ChatsSection> createState() => _ChatsSectionState();
}

class _ChatsSectionState extends State<_ChatsSection> {
  late Future<List<Map<String, dynamic>>> _conversations = _load();

  Future<List<Map<String, dynamic>>> _load() => ConversationRepository(widget.api).list();
  void _reload() => setState(() => _conversations = _load());

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Expanded(child: Text('Your conversations', style: Theme.of(context).textTheme.titleLarge)),
            IconButton(onPressed: _reload, tooltip: 'Refresh conversations', icon: const Icon(Icons.refresh)),
            IconButton(onPressed: widget.onGroups, tooltip: 'Groups', icon: const Icon(Icons.groups_outlined)),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _conversations,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text('Could not load conversations. Check your connection and retry.', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ]),
              ));
            }
            final conversations = snapshot.data ?? const <Map<String, dynamic>>[];
            if (conversations.isEmpty) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.chat_bubble_outline, size: 56),
                  const SizedBox(height: 16),
                  Text('No conversations yet', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Add a contact and open a conversation, or create a group.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: widget.onContacts, icon: const Icon(Icons.person_add_alt_1), label: const Text('Find contacts')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: widget.onGroups, icon: const Icon(Icons.groups_outlined), label: const Text('Create a group')),
                ]),
              ));
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                itemCount: conversations.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final item = conversations[index];
                  final id = item['conversationId'] as String;
                  final name = item['name'] as String? ?? (item['kind'] == 'group' ? 'Group' : 'Conversation');
                  final kind = item['kind'] as String? ?? 'direct';
                  final last = item['lastMessage'] as String?;
                  return ListTile(
                    leading: CircleAvatar(child: Icon(kind == 'group' ? Icons.groups_outlined : Icons.person_outline)),
                    title: Text(name),
                    subtitle: Text(last == null || last.isEmpty ? 'No messages yet' : last, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(
                        conversationId: id,
                        conversationName: name,
                        currentUserId: widget.currentUserId,
                        repository: OfflineMessageRepository(api: widget.api),
                      )));
                      if (mounted) _reload();
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _FilesSection extends StatelessWidget {
  const _FilesSection();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.folder_outlined, size: 56),
        SizedBox(height: 16),
        Text('Shared files', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Text('File upload and download APIs are available, but the file picker and attachment list still need to be connected in the app.', textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _SecurityPage extends StatelessWidget {
  const _SecurityPage({required this.api, required this.lockController, required this.onSignOut});

  final ApiClient api;
  final AppLockController lockController;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(child: ListTile(
        leading: const Icon(Icons.lock_outline),
        title: const Text('App lock'),
        subtitle: const Text('Configure app-lock behavior'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppLockSettingsPage(controller: lockController))),
      )),
      Card(child: ListTile(
        leading: const Icon(Icons.devices_outlined),
        title: const Text('Devices and sessions'),
        subtitle: const Text('Review active sessions and revoke devices'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionsPage(repository: SessionRepository(api)))),
      )),
      Card(child: ListTile(
        leading: const Icon(Icons.visibility_off_outlined),
        title: const Text('Privacy settings'),
        subtitle: const Text('Discovery, contact requests, and presence'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrivacyPage(repository: PrivacyRepository(api)))),
      )),
      Card(child: ListTile(
        leading: const Icon(Icons.notifications_outlined),
        title: const Text('Notifications'),
        subtitle: const Text('Message and lock-screen preferences'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationsPage(repository: NotificationRepository(api)))),
      )),
      Card(child: ListTile(
        leading: const Icon(Icons.delete_forever_outlined),
        title: const Text('Account deletion'),
        subtitle: const Text('Request or review account deletion'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountDeletionPage(
          repository: AccountRepository(api),
        ))),
      )),
      const SizedBox(height: 16),
      FilledButton.tonal(onPressed: onSignOut, child: const Text('Sign out')),
    ],
  );
}
