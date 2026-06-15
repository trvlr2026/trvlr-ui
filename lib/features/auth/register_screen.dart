import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _loading = false;

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      await ref.read(repositoryProvider).register(_name.text.trim(), _email.text.trim(), _password.text);
      ref.invalidate(currentUserProvider);
      if (!mounted) return;
      context.go('/onboarding');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name')),
              const SizedBox(height: 12),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _register,
                child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Get started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
