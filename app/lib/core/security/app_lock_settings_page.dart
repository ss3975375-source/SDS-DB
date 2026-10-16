import 'package:flutter/material.dart';
import 'app_lock_controller.dart';
import 'app_lock_service.dart';

class AppLockSettingsPage extends StatefulWidget {
  const AppLockSettingsPage({super.key, required this.controller});
  final AppLockController controller;
  @override
  State<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends State<AppLockSettingsPage> {
  bool _busy = false;

  Future<void> _showPasscodeSetup() async {
    final first = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final passcode = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set app passcode'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Choose 6–12 digits. SDS-DB stores only a salted verifier in secure storage.'),
            const SizedBox(height: 16),
            TextField(controller: first, obscureText: true, keyboardType: TextInputType.number, maxLength: 12, decoration: const InputDecoration(labelText: 'New passcode', counterText: '')),
            TextField(controller: confirm, obscureText: true, keyboardType: TextInputType.number, maxLength: 12, decoration: const InputDecoration(labelText: 'Confirm passcode', counterText: '')),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              if (!RegExp(r'^\d{6,12}$').hasMatch(first.text)) {
                setDialogState(() => error = 'Use 6–12 digits.');
              } else if (first.text != confirm.text) {
                setDialogState(() => error = 'Passcodes do not match.');
              } else {
                Navigator.pop(dialogContext, first.text);
              }
            }, child: const Text('Enable')),
          ],
        ),
      ),
    );
    first.dispose();
    confirm.dispose();
    if (passcode == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.controller.enablePasscode(passcode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passcode lock enabled.')));
      setState(() {});
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not enable passcode lock: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enableBiometrics() async {
    setState(() => _busy = true);
    try {
      await widget.controller.enableBiometrics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometric lock enabled.')));
        setState(() {});
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not enable biometrics: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disableLock() async {
    setState(() => _busy = true);
    try {
      await widget.controller.disableLock();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App lock disabled.')));
        setState(() {});
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not disable app lock: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('App lock')),
    body: FutureBuilder<AppLockMode>(
      future: widget.controller.service.mode(),
      builder: (context, snapshot) {
        final mode = snapshot.data ?? widget.controller.currentMode;
        return ListView(children: [
          const ListTile(leading: Icon(Icons.shield_outlined), title: Text('Protect SDS-DB'), subtitle: Text('Require authentication when reopening the app.')),
          RadioListTile<AppLockMode>(value: AppLockMode.off, groupValue: mode, onChanged: _busy ? null : (_) => _disableLock(), title: const Text('Off'), subtitle: const Text('No app-level lock.')),
          RadioListTile<AppLockMode>(value: AppLockMode.passcode, groupValue: mode, onChanged: _busy ? null : (_) => _showPasscodeSetup(), title: const Text('Passcode'), subtitle: const Text('Use a 6–12 digit passcode.')),
          RadioListTile<AppLockMode>(value: AppLockMode.biometrics, groupValue: mode, onChanged: _busy ? null : (_) => _enableBiometrics(), title: const Text('Biometrics'), subtitle: const Text('Use device-supported biometric authentication.')),
          if (_busy) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        ]);
      },
    ),
  );
}
