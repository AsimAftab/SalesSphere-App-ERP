import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/auth/auth_state.dart';
import 'package:sales_sphere_erp/features/auth/auth_controller.dart';

class BiometricUnlockPage extends ConsumerWidget {
  const BiometricUnlockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.fingerprint, size: 96),
              const SizedBox(height: 24),
              const Text(
                'Use your fingerprint or face to unlock SalesSphere.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock'),
                onPressed: () => ref
                    .read(authControllerProvider.notifier)
                    .unlockWithBiometrics(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref
                    .read(authStateProvider.notifier)
                    .set(const AuthState.unauthenticated()),
                child: const Text('Use password instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
