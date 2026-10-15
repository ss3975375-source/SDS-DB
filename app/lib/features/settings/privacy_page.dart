import 'package:flutter/material.dart';
import 'privacy_repository.dart';
import 'privacy_settings.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key, required this.repository});
  final PrivacyRepository repository;

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  late Future<PrivacySettings> _future = widget.repository.get();
  PrivacySettings? _settings;
  bool _saving = false;

  Future<void> _set(PrivacySettings next) async {
    final previous = _settings;
    setState(() {
      _settings = next;
      _saving = true;
    });
    try {
      final saved = await widget.repository.update(next);
      if (mounted) setState(() => _settings = saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _settings = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save privacy settings: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Privacy'),
      actions: [
        if (_saving) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      ],
    ),
    body: FutureBuilder<PrivacySettings>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Unable to load privacy settings.'),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => setState(() => _future = widget.repository.get()), child: const Text('Retry')),
        ]));
        final settings = _settings ?? snapshot.data!;
        return ListView(children: [
          SwitchListTile(
            title: const Text('Find me by user ID'),
            subtitle: const Text('Controls whether user-ID lookup can discover your account.'),
            value: settings.discoverableByUserId,
            onChanged: (value) => _set(settings.copyWith(discoverableByUserId: value)),
          ),
          SwitchListTile(
            title: const Text('Allow contact requests'),
            value: settings.contactRequestsEnabled,
            onChanged: (value) => _set(settings.copyWith(contactRequestsEnabled: value)),
          ),
          SwitchListTile(
            title: const Text('Read receipts'),
            value: settings.readReceiptsEnabled,
            onChanged: (value) => _set(settings.copyWith(readReceiptsEnabled: value)),
          ),
          SwitchListTile(
            title: const Text('Typing indicators'),
            value: settings.typingIndicatorsEnabled,
            onChanged: (value) => _set(settings.copyWith(typingIndicatorsEnabled: value)),
          ),
          SwitchListTile(
            title: const Text('Presence'),
            subtitle: const Text('Off by default.'),
            value: settings.presenceEnabled,
            onChanged: (value) => _set(settings.copyWith(presenceEnabled: value)),
          ),
          const Divider(),
          const ListTile(title: Text('Feel It default visibility')),
          RadioListTile<String>(
            title: const Text('My contacts'),
            value: 'contacts',
            groupValue: settings.feelItDefaultVisibility,
            onChanged: (value) { if (value != null) _set(settings.copyWith(feelItDefaultVisibility: value)); },
          ),
          RadioListTile<String>(
            title: const Text('Selected contacts'),
            value: 'selected',
            groupValue: settings.feelItDefaultVisibility,
            onChanged: (value) { if (value != null) _set(settings.copyWith(feelItDefaultVisibility: value)); },
          ),
          RadioListTile<String>(
            title: const Text('Exclude contacts'),
            value: 'exclude',
            groupValue: settings.feelItDefaultVisibility,
            onChanged: (value) { if (value != null) _set(settings.copyWith(feelItDefaultVisibility: value)); },
          ),
        ]);
      },
    ),
  );
}
