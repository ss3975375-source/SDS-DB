import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});
  final AuthRepository auth;
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool busy = false;
  String? error;
  Future<void> _login() async {
    setState(() { busy = true; error = null; });
    try { await widget.auth.signIn(); if (mounted) context.go('/'); }
    catch (e) { if (mounted) setState(() => error = 'Sign-in failed. Please try again.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Padding(
      padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.shield_outlined, size: 72), SizedBox(height: 20), Text('SDS-DB', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
        SizedBox(height: 8), Text('Private communication, built with privacy by default.', textAlign: TextAlign.center), SizedBox(height: 32),
        if (error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(error!, textAlign: TextAlign.center)),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : _login, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: Text(busy ? 'Signing in…' : 'Continue with Google'))),
      ],
    )))),
  );
}
