import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/ark_setup/presentation/cubit.dart';
import 'package:bb_mobile/features/ark_setup/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ArkSetupPage extends StatelessWidget {
  const ArkSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ark Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('''
Ark is still experimental. We are going to create a new Ark wallet using your default mnemonic.

By continuing, you acknowledge the risk of losing funds if you have not properly backed up both your default mnemonic.
            '''),

            BlocBuilder<ArkSetupCubit, ArkSetupState>(
              builder: (context, state) {
                final cubit = context.read<ArkSetupCubit>();

                return Column(
                  children: [
                    if (state.error != null) ...[
                      Text(
                        state.error!.message,
                        style: TextStyle(color: context.colour.error),
                      ),
                      const Gap(16),
                    ],

                    BBButton.big(
                      onPressed: () => cubit.createArkSecretKey(),
                      label: state.isLoading ? 'Creating...' : 'Enable Ark',
                      bgColor: context.colour.primary,
                      textColor: context.colour.onPrimary,
                      disabled: state.isLoading,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
