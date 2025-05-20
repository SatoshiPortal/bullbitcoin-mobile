import 'dart:async';

import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/features/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:bb_mobile/features/recover_wallet/ui/widgets/mnemonic_word_input_field.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class RecoverPhysicalWalletInputScreen extends StatefulWidget {
  const RecoverPhysicalWalletInputScreen({super.key});

  @override
  State<RecoverPhysicalWalletInputScreen> createState() =>
      _RecoverPhysicalWalletInputScreenState();
}

class _RecoverPhysicalWalletInputScreenState
    extends State<RecoverPhysicalWalletInputScreen>
    with PrivacyScreen {
  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: enableScreenPrivacy(),
      builder: (context, snapshot) {
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
      },
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
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

                        GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                            return MnemonicWordInputField(wordIndex: index);
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          const Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_Button(), SizedBox(height: 20)],
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button();

  @override
  Widget build(BuildContext context) {
    final hasAllValidWords = context.select(
      (RecoverWalletBloc recoverWalletBloc) =>
          recoverWalletBloc.state.hasAllValidWords,
    );

    final creating = context.select(
      (RecoverWalletBloc recoverWalletBloc) =>
          recoverWalletBloc.state.recoverWalletStatus ==
          const RecoverWalletStatus.loading(),
    );

    if (creating) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BBButton.big(
        label: 'Recover',
        onPressed: () {
          if (hasAllValidWords) {
            context.read<RecoverWalletBloc>().add(
              const RecoverWalletConfirmed(),
            );
          }
        },
        bgColor: context.colour.secondary,
        textColor: context.colour.onPrimary,
      ),
    );
  }
}
