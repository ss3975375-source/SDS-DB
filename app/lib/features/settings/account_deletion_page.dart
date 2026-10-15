import 'package:flutter/material.dart';
import 'account_repository.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({
    super.key,
    required this.repository,
    this.onDeletionRequested,
  });

  final AccountRepository repository;
  final Future<void> Function()? onDeletionRequested;

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  bool _confirmed = false;
  bool _busy = false;
  late Future<AccountDeletionStatus?> _status = widget.repository.deletionStatus();

  Future<void> _requestDeletion() async {
    setState(() => _busy = true);
    try {
      final status = await widget.repository.requestDeletion();
      if (!mounted) return;
      setState(() {
        _confirmed = false;
        _status = Future.value(status);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deletion request submitted. Your session may be revoked for safety.')));
      await widget.onDeletionRequested?.call();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not request deletion: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelDeletion() async {
    setState(() => _busy = true);
    try {
      await widget.repository.cancelDeletion();
      if (!mounted) return;
      setState(() => _status = Future.value(null));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deletion cancellation submitted.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not cancel deletion with this session. You may need to sign in again: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delete account')),
    body: FutureBuilder<AccountDeletionStatus?>(
      future: _status,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load account deletion status.'),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => setState(() => _status = widget.repository.deletionStatus()), child: const Text('Retry')),
          ]),
        ));
        final status = snapshot.data;
        if (status != null) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.hourglass_top, size: 44),
              const SizedBox(height: 12),
              Text('Deletion is scheduled', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text('Status: ${status.status}'),
              const SizedBox(height: 8),
              Text('Scheduled for: ${status.scheduledFor.toLocal()}'),
              const SizedBox(height: 8),
              const Text('If your session has been revoked, cancellation may require signing in again.'),
              const Spacer(),
              SizedBox(width: double.infinity, child: OutlinedButton(
                onPressed: _busy ? null : _cancelDeletion,
                child: Text(_busy ? 'Please wait…' : 'Cancel deletion'),
              )),
            ]),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Delete your SDS-DB account', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text('Deletion starts a server-side workflow. The final deletion is scheduled after the cancellation period.'),
            const SizedBox(height: 12),
            const Text('Your profile, contacts, devices, notifications, Feel It content, account-owned messages and private files are removed subject to documented retention requirements.'),
            const SizedBox(height: 20),
            CheckboxListTile(
              value: _confirmed,
              onChanged: _busy ? null : (value) => setState(() => _confirmed = value ?? false),
              title: const Text('I understand and want to continue'),
              contentPadding: EdgeInsets.zero,
            ),
            const Spacer(),
            SizedBox(width: double.infinity, child: FilledButton.tonal(
              onPressed: _confirmed && !_busy ? _requestDeletion : null,
              child: Text(_busy ? 'Submitting…' : 'Request account deletion'),
            )),
          ]),
        );
      },
    ),
  );
}
