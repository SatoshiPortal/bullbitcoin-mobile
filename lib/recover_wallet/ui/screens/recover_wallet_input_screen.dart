import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/_ui/components/segment/segmented_small.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:bb_mobile/recover_wallet/ui/widgets/label_input_field.dart';
import 'package:bb_mobile/recover_wallet/ui/widgets/mnemonic_word_input_field.dart';
import 'package:bb_mobile/recover_wallet/ui/widgets/passphrase_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class RecoverWalletInputScreen extends StatelessWidget {
  const RecoverWalletInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: TopBar(
          title: 'Recover Wallet',
          onBack: () {
            context.pop();
          },
        ),
        automaticallyImplyLeading: false,
        forceMaterialTransparency: true,
      ),
      body: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fromOnboarding =
        context.select((RecoverWalletBloc _) => _.state.fromOnboarding);

    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BlocSelector<RecoverWalletBloc, RecoverWalletState, int>(
                  selector: (state) => state.wordsCount,
                  builder: (context, wordsCount) {
                    return Column(
                      children: [
                        // Padding(
                        //   padding: const EdgeInsets.symmetric(horizontal: 8),
                        //   child: TopBar(
                        //     title: 'Recover Wallet',
                        //     onBack: () {
                        //       context.pop();
                        //     },
                        //   ),
                        // ),
                        const Gap(40),

                        if (!fromOnboarding) ...[
                          SegmentedSmall(
                            items: const {'12', '24'},
                            selected: '12',
                            onSelected: (s) {},
                          ),
                          // MnemonicWordsCountSelection(
                          //   selectedWordsCount: wordsCount,
                          // ),

                          const SizedBox(height: 33),
                        ],
                        GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          physics:
                              const NeverScrollableScrollPhysics(), // Prevent GridView from scrolling
                          shrinkWrap:
                              true, // Allow GridView to take the height it needs
                          itemCount: wordsCount,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 32,
                            childAspectRatio: 3.5,
                          ),

                          itemBuilder: (context, index) {
                            return MnemonicWordInputField(
                              wordIndex: index,
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                if (!fromOnboarding) ...[
                  const Gap(54),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: PassphraseInputField(),
                  ),
                  const Gap(16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: LabelInputField(),
                  ),
                  const Gap(54),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BlocSelector<RecoverWalletBloc, RecoverWalletState, bool>(
                selector: (state) => state.hasAllValidWords,
                builder: (context, hasAllValidWords) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: BBButton.big(
                      label: 'Recover',
                      onPressed: () => hasAllValidWords
                          ? () => context.read<RecoverWalletBloc>().add(
                                const RecoverWalletConfirmed(),
                              )
                          : null,
                      bgColor: context.colour.secondary,
                      textColor: context.colour.onPrimary,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }
}
