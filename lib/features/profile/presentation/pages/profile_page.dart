import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/features/auth/presentation/controllers/auth_controller.dart';

/// Profile detail screen reached by pushing from the More tab. Sign-out
/// lives on `MorePage` so this stays a focused identity-display screen.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/more'),
        ),
      ),
      body: Center(
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
          ],
        ),
      ),
    );
  }
}
