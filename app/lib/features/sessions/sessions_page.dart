import 'package:flutter/material.dart';
import 'session_models.dart';
import 'session_repository.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key, required this.repository});
  final SessionRepository repository;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  late Future<List<DeviceSession>> _future = widget.repository.list();
  bool _busy = false;

  void _reload() => setState(() => _future = widget.repository.list());

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        _reload();
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Session operation failed: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Devices & sessions'),
      actions: [
        IconButton(onPressed: _busy ? null : _reload, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'others') _run(widget.repository.revokeOthers, 'Other sessions revoked.');
            if (value == 'all') _run(widget.repository.revokeAll, 'All sessions revoked. Sign in again.');
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'others', child: Text('Sign out other devices')),
            PopupMenuItem(value: 'all', child: Text('Sign out all devices')),
          ],
        ),
      ],
    ),
    body: FutureBuilder<List<DeviceSession>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Unable to load active sessions.'),
          const SizedBox(height: 8),
          FilledButton(onPressed: _reload, child: const Text('Retry')),
        ]));
        final sessions = snapshot.data ?? const <DeviceSession>[];
        if (sessions.isEmpty) return const Center(child: Text('No active sessions to display.'));
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return ListTile(
                leading: Icon(session.platform?.toLowerCase() == 'android' ? Icons.android : Icons.devices_other),
                title: Text(session.deviceName?.trim().isNotEmpty == true ? session.deviceName! : 'Device'),
                subtitle: Text([
                  if (session.platform != null) session.platform!,
                  if (session.appVersion != null) 'App ${session.appVersion!}',
                  if (session.current) 'Current device',
                  if (session.revoked) 'Revoked',
                ].join(' • ')),
                trailing: session.current
                  ? const Chip(label: Text('Current'))
                  : TextButton(
                      onPressed: _busy || session.revoked ? null : () => _run(() => widget.repository.revoke(session.id), 'Session revoked.'),
                      child: const Text('Revoke'),
                    ),
              );
            },
          ),
        );
      },
    ),
  );
}
