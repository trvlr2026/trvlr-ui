import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await ref.read(repositoryProvider).login(_email.text.trim(), _password.text);
      ref.invalidate(currentUserProvider);
      if (!mounted) return;
      context.go('/onboarding');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.explore_rounded, size: 56, color: Color(0xFF0D9488)),
              const SizedBox(height: 12),
              Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Sign in to track your travels and climb the leaderboard.'),
              const SizedBox(height: 32),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _login,
                child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in'),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.push('/register'), child: const Text('Create an account')),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
