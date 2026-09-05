import 'package:flutter/material.dart';
import '../../core/security/app_lock_service.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _lockService = AppLockService();
  AppLockMode _mode = AppLockMode.off;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await _lockService.mode();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('App lock'),
            subtitle: Text(_label(_mode)),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<AppLockMode>(
          segments: const [
            ButtonSegment(
              value: AppLockMode.off,
              label: Text('Off'),
              icon: Icon(Icons.lock_open_outlined),
            ),
            ButtonSegment(
              value: AppLockMode.passcode,
              label: Text('Passcode'),
              icon: Icon(Icons.password_outlined),
            ),
            ButtonSegment(
              value: AppLockMode.biometrics,
              label: Text('Biometric'),
              icon: Icon(Icons.fingerprint),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (value) async {
            final next = value.first;
            try {
              await _lockService.setMode(next);
              if (!mounted) return;
              setState(() => _mode = next);
            } catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Biometric authentication is unavailable on this device.',
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 20),
        const ListTile(
          leading: Icon(Icons.visibility_off_outlined),
          title: Text('Private app switcher'),
          subtitle: Text(
            'Sensitive screen protection depends on Android/iOS platform capabilities.',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.security_outlined),
          title: Text('Security note'),
          subtitle: Text(
            'SDS-DB never stores your device biometric data. Android/iOS owns biometric verification.',
          ),
        ),
      ],
    );
  }

  String _label(AppLockMode mode) => switch (mode) {
    AppLockMode.off => 'No app lock',
    AppLockMode.passcode => 'Passcode lock enabled',
    AppLockMode.biometrics => 'Biometric lock enabled',
  };
}
