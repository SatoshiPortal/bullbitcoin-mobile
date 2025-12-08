import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bip85_derivation_widget.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/cubit.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class Bip85HomePage extends StatelessWidget {
  const Bip85HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.bip85Title)),
      body: BlocBuilder<Bip85EntropyCubit, Bip85EntropyState>(
        builder: (context, state) {
          final cubit = context.read<Bip85EntropyCubit>();

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                FadingLinearProgress(
                  trigger: state.xprvBase58.isEmpty || state.isLoading,
                ),
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.appColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: context.appColors.warning),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          context.loc.bip85ExperimentalWarning,
                          style: TextStyle(color: context.appColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                if (state.derivations.isNotEmpty && state.xprvBase58.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.derivations.length,
                      itemBuilder: (context, index) {
                        final derivation = state.derivations[index];
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Bip85DerivationWidget(
                            xprvBase58: state.xprvBase58,
                            derivation: derivation,
                            onAliasChanged: cubit.aliasDerivation,
                            onDerivationRevoked: cubit.revokeDerivation,
                            onDerivationActivated: cubit.activateDerivation,
                          ),
                        );
                      },
                    ),
                  ),
                const Gap(16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      BBButton.small(
                        onPressed: () => cubit.deriveNextMnemonic(),
                        label: context.loc.bip85NextMnemonic,
                        bgColor: context.appColors.onSurface,
                        textColor: context.appColors.surface,
                      ),
                      BBButton.small(
                        onPressed: () => cubit.deriveNextHex(),
                        label: context.loc.bip85NextHex,
                        bgColor: context.appColors.onSurface,
                        textColor: context.appColors.surface,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
