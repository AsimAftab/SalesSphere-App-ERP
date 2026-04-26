import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/auth/auth_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.value;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.person_outline, size: 80),
          const SizedBox(height: 12),
          Text(
            user?.fullName ?? 'Profile',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (user != null) Text(user.email),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
