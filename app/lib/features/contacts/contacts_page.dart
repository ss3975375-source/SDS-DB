import 'package:flutter/material.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            tooltip: 'QR',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContactQrPage()),
            ),
            icon: const Icon(Icons.qr_code_2),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Contacts are private. Search requires an authenticated '
          'request and is subject to privacy and blocking rules.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class ContactQrPage extends StatelessWidget {
  const ContactQrPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact QR')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'QR generation and scanning are server-authorized. '
            'The QR must contain only a short-lived opaque token; '
            'never place access tokens or private profile data in it.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
