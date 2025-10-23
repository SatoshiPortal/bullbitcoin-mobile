import 'package:bb_mobile/core/widgets/loading/status_screen.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VaultCreatedPage extends StatelessWidget {
  const VaultCreatedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusScreen(
      title: 'Encrypted Vault created!',
      description:
          "Now let's test your backup to make sure everything was done properly.",
      isLoading: false,
      buttonText: 'Test Recovery',
      onTap:
          () => context.goNamed(
            RecoverBullRoute.recoverbullFlows.name,
            extra: RecoverBullFlow.testVault,
          ),
    );
  }
}
