import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import 'contact_repository.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  late final ContactRepository _repository = ContactRepository(widget.api);
  late Future<_ContactData> _data = _load();

  Future<_ContactData> _load() async => _ContactData(
    contacts: await _repository.listContacts(),
    requests: await _repository.listRequests(),
  );

  void _reload() => setState(() => _data = _load());

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not complete action: $error')));
    }
  }

  Future<void> _addContact() async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add by user ID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'SDS-DB user ID', hintText: 'Paste the user UUID'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    if (id == null || id.isEmpty) return;
    try {
      final user = await _repository.discover(id);
      if (!mounted) return;
      final name = user['displayName'] as String? ?? 'this user';
      final send = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Send request to $name?'),
          content: const Text('Only the public profile is shown. The recipient can accept or decline your request.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send request')),
          ],
        ),
      );
      if (send == true) await _run(() => _repository.sendRequest(id), 'Contact request sent.');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not find that user: $error')));
    }
  }

  Future<void> _joinInvite() async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use contact invite code'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Invite token')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Add contact')),
        ],
      ),
    );
    controller.dispose();
    if (token == null || token.isEmpty) return;
    try {
      await _repository.consumeQr(token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact added.')));
        _reload();
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invite could not be used: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Contacts'),
      actions: [
        IconButton(tooltip: 'Refresh contacts', onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _addContact,
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('Add contact'),
    ),
    body: FutureBuilder<_ContactData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Unable to load contacts.'),
          const SizedBox(height: 8),
          FilledButton(onPressed: _reload, child: const Text('Retry')),
        ]));
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
            children: [
              Card(child: ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Add using an invite code'),
                subtitle: const Text('Use a short-lived code shared by a contact.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _joinInvite,
              )),
              const Padding(padding: EdgeInsets.fromLTRB(8, 20, 8, 8), child: Text('Contact requests', style: TextStyle(fontWeight: FontWeight.bold))),
              if (data.requests.isEmpty) const ListTile(title: Text('No pending requests')),
              for (final request in data.requests)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(request['displayName'] as String? ?? 'SDS-DB user'),
                    subtitle: Text(request['direction'] == 'incoming' ? 'Incoming request' : 'Request sent'),
                    trailing: request['direction'] == 'incoming'
                      ? Wrap(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(tooltip: 'Accept', onPressed: () => _run(() => _repository.acceptRequest(request['id'] as String), 'Contact request accepted.'), icon: const Icon(Icons.check_circle_outline)),
                          IconButton(tooltip: 'Decline', onPressed: () => _run(() => _repository.declineRequest(request['id'] as String), 'Contact request declined.'), icon: const Icon(Icons.close)),
                        ])
                      : IconButton(tooltip: 'Cancel request', onPressed: () => _run(() => _repository.cancelRequest(request['id'] as String), 'Request cancelled.'), icon: const Icon(Icons.cancel_outlined)),
                  ),
                ),
              const Padding(padding: EdgeInsets.fromLTRB(8, 20, 8, 8), child: Text('My contacts', style: TextStyle(fontWeight: FontWeight.bold))),
              if (data.contacts.isEmpty) const ListTile(title: Text('No contacts yet'), subtitle: Text('Add someone using their user ID or invite code.')),
              for (final contact in data.contacts)
                Card(child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(contact['displayName'] as String? ?? 'SDS-DB user'),
                  subtitle: SelectableText(contact['id'] as String),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'remove') _run(() => _repository.removeContact(contact['id'] as String), 'Contact removed.');
                    },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remove contact'))],
                  ),
                )),
            ],
          ),
        );
      },
    ),
  );
}

class _ContactData {
  const _ContactData({required this.contacts, required this.requests});
  final List<Map<String, dynamic>> contacts;
  final List<Map<String, dynamic>> requests;
}
