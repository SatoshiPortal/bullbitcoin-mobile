import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bip85_derivation_widget.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
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
            child: ScrollableColumn(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          context.loc.bip85ExperimentalWarning,
                          style: TextStyle(color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                if (state.derivations.isNotEmpty)
                  ...List.generate(state.derivations.length, (index) {
                    final derivation = state.derivations[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Bip85DerivationWidget(
                        xprvBase58: state.xprvBase58,
                        derivation: derivation,
                      ),
                    );
                  }),
                const Gap(16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BBButton.small(
                      onPressed: () => cubit.deriveNextMnemonic(),
                      label: context.loc.bip85NextMnemonic,
                      bgColor: Theme.of(context).colorScheme.secondary,
                      textColor: Theme.of(context).colorScheme.onSecondary,
                    ),
                    BBButton.small(
                      onPressed: () => cubit.deriveNextHex(),
                      label: context.loc.bip85NextHex,
                      bgColor: Theme.of(context).colorScheme.secondary,
                      textColor: Theme.of(context).colorScheme.onSecondary,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
