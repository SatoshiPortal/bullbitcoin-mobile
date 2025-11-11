import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/ark_setup/presentation/cubit.dart';
import 'package:bb_mobile/features/ark_setup/presentation/state.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ArkSetupPage extends StatelessWidget {
  const ArkSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.arkSetupTitle)),
      body: BlocBuilder<ArkSetupCubit, ArkSetupState>(
        builder: (context, state) {
          final isLoading = state.isLoading;
          final error = state.error;
          final arkWallet = context.watch<WalletBloc>().state.arkWallet;

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
                      Text(context.loc.arkSetupExperimentalWarning),
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
                                  context
                                      .read<ArkSetupCubit>()
                                      .createArkSecretKey(),
                          label: context.loc.arkSetupEnable,
                          bgColor: context.colour.primary,
                          textColor: context.colour.onPrimary,
                          disabled: arkWallet != null || isLoading,
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
