import 'package:flutter/material.dart';
import 'notification_preferences.dart';
import 'notification_repository.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.repository});
  final NotificationRepository repository;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<NotificationPreferences> _future = widget.repository.getPreferences();
  NotificationPreferences? _preferences;
  bool _saving = false;

  Future<void> _update(NotificationPreferences next) async {
    final previous = _preferences;
    setState(() {
      _preferences = next;
      _saving = true;
    });
    try {
      await widget.repository.savePreferences(next);
    } catch (error) {
      if (mounted) {
        setState(() => _preferences = previous);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save notification preferences: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        if (_saving) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      ],
    ),
    body: FutureBuilder<NotificationPreferences>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Unable to load notification preferences.'),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => setState(() => _future = widget.repository.getPreferences()), child: const Text('Retry')),
        ]));
        final p = _preferences ?? snapshot.data!;
        return ListView(children: [
          SwitchListTile(title: const Text('Messages'), value: p.messagesEnabled, onChanged: (v) => _update(p.copyWith(messagesEnabled: v))),
          SwitchListTile(title: const Text('Groups'), value: p.groupsEnabled, onChanged: (v) => _update(p.copyWith(groupsEnabled: v))),
          SwitchListTile(title: const Text('Contact requests'), value: p.contactRequestsEnabled, onChanged: (v) => _update(p.copyWith(contactRequestsEnabled: v))),
          SwitchListTile(title: const Text('Feel It'), value: p.feelItEnabled, onChanged: (v) => _update(p.copyWith(feelItEnabled: v))),
          const Divider(),
          SwitchListTile(
            title: const Text('Show previews on lock screen'),
            subtitle: const Text('Off by default. Device system settings may also affect previews.'),
            value: p.lockScreenPreviewEnabled,
            onChanged: (v) => _update(p.copyWith(lockScreenPreviewEnabled: v)),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Sound and vibration'),
            subtitle: Text('Controlled by device notification settings; these preferences are not yet managed by SDS-DB.'),
          ),
        ]);
      },
    ),
  );
}
