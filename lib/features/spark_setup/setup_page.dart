import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/spark_setup/presentation/cubit.dart';
import 'package:bb_mobile/features/spark_setup/presentation/state.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SparkSetupPage extends StatelessWidget {
  const SparkSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spark Setup')),
      body: BlocBuilder<SparkSetupCubit, SparkSetupState>(
        builder: (context, state) {
          final isLoading = state.isLoading;
          final error = state.error;
          final sparkWallet = context.watch<WalletBloc>().state.sparkWallet;

          return Column(
            children: [
              if (isLoading)
                LinearProgressIndicator(
                  backgroundColor: context.colour.surface,
                  color: context.colour.primary,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('''
Spark is still experimental.

Your Spark wallet uses your main wallet's seed phrase directly. No additional backup is needed - your existing wallet backup restores your Spark funds too.

By continuing, you acknowledge the experimental nature of Spark and the risk of losing funds.

Developer note: Spark uses the same mnemonic as your main wallet.
            '''),
                      const Spacer(),
                      if (error != null) ...[
                        Text(
                          error.message,
                          style: TextStyle(color: context.colour.error),
                        ),
                        const Gap(16),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: BBButton.big(
                          onPressed:
                              () =>
                                  context.read<SparkSetupCubit>().enableSpark(),
                          label: 'Enable Spark',
                          bgColor: context.colour.primary,
                          textColor: context.colour.onPrimary,
                          disabled: sparkWallet != null || isLoading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
