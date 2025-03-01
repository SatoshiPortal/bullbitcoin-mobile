import 'package:bb_mobile/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:bb_mobile/recover_wallet/ui/widgets/label_input_field.dart';
import 'package:bb_mobile/recover_wallet/ui/widgets/mnemonic_word_input_field.dart';
import 'package:bb_mobile/recover_wallet/ui/widgets/mnemonic_words_count_selection.dart';
import 'package:bb_mobile/recover_wallet/ui/widgets/passphrase_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverWalletInputScreen extends StatelessWidget {
  const RecoverWalletInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recover Wallet'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
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
                            const SizedBox(height: 20),
                            MnemonicWordsCountSelection(
                              selectedWordsCount: wordsCount,
                            ),
                            const SizedBox(height: 40),
                            GridView.builder(
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
                                childAspectRatio: 4,
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
                    const SizedBox(height: 40),
                    const PassphraseInputField(),
                    const SizedBox(height: 40),
                    const LabelInputField(),
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
                      return ElevatedButton(
                        onPressed: hasAllValidWords
                            ? () => context.read<RecoverWalletBloc>().add(
                                  const RecoverWalletConfirmed(),
                                )
                            : null,
                        child: const Text('Next'),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
