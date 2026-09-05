import 'package:flutter/material.dart';
import '../authentication/auth_repository.dart';
import '../authentication/google_auth_service.dart';
import '../feel_it/feel_it_page.dart';
import '../feel_it/feel_it_repository.dart';
import '../groups/data/group_repository.dart';
import '../groups/presentation/groups_page.dart';
import '../../core/network/api_client.dart';
import '../../core/security/app_lock_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.googleAuth, required this.auth, required this.api, required this.lockController});
  final GoogleAuthService googleAuth;
  final AuthRepository auth;
  final ApiClient api;
  final AppLockController lockController;
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  @override Widget build(BuildContext context) {
    final pages = [
      _ChatsSection(onGroups: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupsPage(repository: GroupRepository(widget.api)))),),
      const _Section(title: 'Contacts', icon: Icons.people_outline, message: 'Add people by user ID or invitation.'),
      const _Section(title: 'Files', icon: Icons.folder_outlined, message: 'Private files shared with you will appear here.'),
      FeelItPage(repository: FeelItRepository(widget.api)),
      _SecurityPage(onSignOut: widget.auth.signOut),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('SDS-DB'), actions: [IconButton(onPressed: () => widget.lockController.lock(), icon: const Icon(Icons.lock_outline), tooltip: 'Lock app')]),
      body: pages[index],
      bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
        NavigationDestination(icon: Icon(Icons.people_outline), label: 'Contacts'),
        NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Files'),
        NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'Feel It'),
        NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Security'),
      ]),
    );
  }
}

class _ChatsSection extends StatelessWidget {
  const _ChatsSection({required this.onGroups});
  final VoidCallback onGroups;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.chat_bubble_outline, size: 56), const SizedBox(height: 16),
    Text('Chats', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 8), const Text('Your private conversations will appear here.', textAlign: TextAlign.center),
    const SizedBox(height: 20), FilledButton.tonalIcon(onPressed: onGroups, icon: const Icon(Icons.groups_outlined), label: const Text('Open groups'))
  ]));
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.message});
  final String title, message; final IconData icon;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 56), const SizedBox(height: 16), Text(title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center)])));
}

class _SecurityPage extends StatelessWidget {
  const _SecurityPage({required this.onSignOut});
  final Future<void> Function() onSignOut;
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const ListTile(leading: Icon(Icons.fingerprint), title: Text('Biometric unlock'), subtitle: Text('App-lock foundation')), 
    const ListTile(leading: Icon(Icons.devices_outlined), title: Text('Sessions'), subtitle: Text('Manage signed-in devices')), 
    const ListTile(leading: Icon(Icons.visibility_off_outlined), title: Text('Privacy'), subtitle: Text('Notification and content controls')), 
    const SizedBox(height: 12), FilledButton.tonal(onPressed: onSignOut, child: const Text('Sign out')),
  ]);
}
