import 'package:flutter/material.dart';
import 'privacy_settings.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  PrivacySettings settings = const PrivacySettings();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Find me by user ID'),
            subtitle: const Text(
              'Controls whether user-ID lookup can discover your account.',
            ),
            value: settings.discoverableByUserId,
            onChanged: (value) => _set(
              settings.copyWith(discoverableByUserId: value),
            ),
          ),
          SwitchListTile(
            title: const Text('Allow contact requests'),
            value: settings.contactRequestsEnabled,
            onChanged: (value) => _set(
              settings.copyWith(contactRequestsEnabled: value),
            ),
          ),
          SwitchListTile(
            title: const Text('Read receipts'),
            value: settings.readReceiptsEnabled,
            onChanged: (value) => _set(
              settings.copyWith(readReceiptsEnabled: value),
            ),
          ),
          SwitchListTile(
            title: const Text('Typing indicators'),
            value: settings.typingIndicatorsEnabled,
            onChanged: (value) => _set(
              settings.copyWith(typingIndicatorsEnabled: value),
            ),
          ),
          SwitchListTile(
            title: const Text('Presence'),
            subtitle: const Text('Off by default.'),
            value: settings.presenceEnabled,
            onChanged: (value) => _set(
              settings.copyWith(presenceEnabled: value),
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('Feel It default visibility'),
          ),
          RadioListTile<String>(
            title: const Text('My contacts'),
            value: 'contacts',
            groupValue: settings.feelItDefaultVisibility,
            onChanged: (value) => _set(
              settings.copyWith(feelItDefaultVisibility: value),
            ),
          ),
          RadioListTile<String>(
            title: const Text('Selected contacts'),
            value: 'selected',
            groupValue: settings.feelItDefaultVisibility,
            onChanged: (value) => _set(
              settings.copyWith(feelItDefaultVisibility: value),
            ),
          ),
          RadioListTile<String>(
            title: const Text('Exclude contacts'),
            value: 'exclude',
            groupValue: settings.feelItDefaultVisibility,
            onChanged: (value) => _set(
              settings.copyWith(feelItDefaultVisibility: value),
            ),
          ),
        ],
      ),
    );
  }

  void _set(PrivacySettings next) {
    setState(() => settings = next);
  }
}
