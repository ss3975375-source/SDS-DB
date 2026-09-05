import 'package:flutter/material.dart';
import 'app_lock_controller.dart';

/// Places a privacy-preserving lock surface above authenticated content.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.controller, required this.child});
  final AppLockController controller;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.start();
  }

  @override
  void didUpdateWidget(covariant AppLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      widget.controller.start();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!widget.controller.locked) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 20),
                Text('SDS-DB is locked', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'Authenticate to continue. Private content stays behind the app-lock screen.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: widget.controller.authenticating ? null : widget.controller.unlock,
                  icon: widget.controller.authenticating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.fingerprint),
                  label: Text(widget.controller.authenticating ? 'Authenticating…' : 'Unlock'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Biometric verification is performed by the operating system; SDS-DB does not receive biometric data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
