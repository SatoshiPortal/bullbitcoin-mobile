import 'package:bb_mobile/features/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MnemonicWordsCountSelection extends StatelessWidget {
  const MnemonicWordsCountSelection({
    super.key,
    required this.selectedWordsCount,
  });

  final int selectedWordsCount;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton(
      segments: const <ButtonSegment<int>>[
        ButtonSegment(
          value: 12,
          label: Text(
            '12 words',
          ),
        ),
        ButtonSegment(
          value: 24,
          label: Text(
            '24 words',
          ),
        ),
      ],
      selected: {selectedWordsCount},
      onSelectionChanged: (value) {
        context.read<RecoverWalletBloc>().add(
              RecoverWalletWordsCountChanged(
                wordsCount: value.first,
              ),
            );
      },
    );
  }
}
