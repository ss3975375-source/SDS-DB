import 'package:flutter/material.dart';
import 'session_models.dart';

class SessionsPage extends StatelessWidget {
  final List<DeviceSession> sessions;
  final Future<void> Function(String id)? onRevoke;
  final Future<void> Function()? onRevokeOthers;

  const SessionsPage({
    super.key,
    this.sessions = const [],
    this.onRevoke,
    this.onRevokeOthers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices & sessions'),
        actions: [
          if (onRevokeOthers != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'others') await onRevokeOthers!();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'others',
                  child: Text('Sign out other devices'),
                ),
              ],
            ),
        ],
      ),
      body: sessions.isEmpty
          ? const Center(child: Text('No active sessions to display.'))
          : ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return ListTile(
                  leading: Icon(
                    session.platform?.toLowerCase() == 'android'
                        ? Icons.android
                        : Icons.devices_other,
                  ),
                  title: Text(
                    session.deviceName?.trim().isNotEmpty == true
                        ? session.deviceName!
                        : 'Device',
                  ),
                  subtitle: Text(
                    [
                      if (session.platform != null) session.platform!,
                      if (session.appVersion != null)
                        'App ${session.appVersion!}',
                      if (session.current) 'Current device',
                    ].join(' • '),
                  ),
                  trailing: session.current
                      ? const Chip(label: Text('Current'))
                      : TextButton(
                          onPressed: session.revoked || onRevoke == null
                              ? null
                              : () => onRevoke!(session.id),
                          child: const Text('Revoke'),
                        ),
                );
              },
            ),
    );
  }
}
