import 'package:bb_mobile/features/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:bb_mobile/features/recover_wallet/presentation/widgets/mnemonic_word_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverWalletInputScreen extends StatelessWidget {
  const RecoverWalletInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        return GridView.builder(
                          shrinkWrap: true,
                          itemCount: wordsCount,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                          ),
                          itemBuilder: (context, index) {
                            return MnemonicWordInputField(
                              wordIndex: index,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
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
