import 'dart:async';

import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/import_mnemonic_failure_l10n.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Stateful only to own the screen-capture lifecycle: the user types their
/// recovery phrase here, so the screen must be excluded from screenshots and
/// the recents thumbnail for as long as it is mounted.
class MnemonicPage extends StatefulWidget {
  const MnemonicPage({super.key});

  @override
  State<MnemonicPage> createState() => _MnemonicPageState();
}

class _MnemonicPageState extends State<MnemonicPage> with PrivacyScreen {
  @override
  void initState() {
    super.initState();
    // Not in build: this is a platform channel call, and this page rebuilds on
    // every cubit emission.
    unawaited(enableScreenPrivacy());
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.importMnemonicTitle,
          color: context.appColors.background,
          onBack: () => context.pop(),
        ),
      ),
      body: BlocConsumer<ImportMnemonicCubit, ImportMnemonicState>(
        listener: (context, state) {
          if (state.failure != null) {
            SnackBarUtils.showSnackBar(
              context,
              state.failure!.toTranslated(context),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MnemonicWidget(
                        initialLength: bip39.MnemonicLength.words12,
                        onSubmit: context
                            .read<ImportMnemonicCubit>()
                            .updateMnemonic,
                        submitLabel: context.loc.importMnemonicContinue,
                      ),
                    ],
                  ),
                ),
              ),
              if (state.isLoading)
                Positioned.fill(
                  child: ColoredBox(
                    color: context.appColors.overlay,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: context.appColors.primary,
                      ),
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
