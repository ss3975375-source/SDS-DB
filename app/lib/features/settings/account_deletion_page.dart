import 'package:flutter/material.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});
  @override State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}
class _AccountDeletionPageState extends State<AccountDeletionPage> {
  bool confirmed = false;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delete account')),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Delete your SDS-DB account', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text('Deletion starts a server-side workflow. Active sessions are revoked immediately. Final deletion occurs after the 24-hour cancellation period.'),
      const SizedBox(height: 12),
      const Text('Your profile, contacts, devices, notifications, Feel It content, account-owned messages and private files are removed subject to documented retention requirements.'),
      const SizedBox(height: 20),
      CheckboxListTile(value: confirmed, onChanged: (v) => setState(() => confirmed = v ?? false), title: const Text('I understand and want to continue'), contentPadding: EdgeInsets.zero),
      const Spacer(),
      SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: confirmed ? _requestDeletion : null, child: const Text('Request account deletion'))),
    ])),
  );
  void _requestDeletion() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect AccountRepository to submit this request.')));
}
