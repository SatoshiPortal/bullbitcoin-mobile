import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MnemonicPage extends StatelessWidget {
  const MnemonicPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Import Mnemonic',
          color: context.colour.secondaryFixed,
          onBack: () => context.pop(),
        ),
      ),
      body: BlocListener<ImportMnemonicCubit, ImportMnemonicState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: BBText(
                  state.error!.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MnemonicWidget(
                  initialLength: bip39.MnemonicLength.words12,
                  onSubmit: context.read<ImportMnemonicCubit>().updateMnemonic,
                  submitLabel: 'Continue',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
