import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/accounts.dart';

/// The luthier's fleet dashboard. Placeholder until the designed screen lands.
class LuthierHomeScreen extends ConsumerWidget {
  const LuthierHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleet = ref.watch(visibleInstrumentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: ref.read(accountProvider.notifier).signOut,
          ),
        ],
      ),
      body: ListView(children: [for (final i in fleet) ListTile(title: Text(i.instrument.name))]),
    );
  }
}
