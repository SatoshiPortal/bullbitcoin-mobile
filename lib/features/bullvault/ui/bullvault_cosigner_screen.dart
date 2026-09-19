import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_cosigner_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_failure_l10n.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart' show BullInputText, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_privacy/screen_privacy.dart';

final class BullVaultCosignerScreen extends StatefulWidget {
  const BullVaultCosignerScreen({super.key});
  @override
  State<BullVaultCosignerScreen> createState() =>
      _BullVaultCosignerScreenState();
}

final class _BullVaultCosignerScreenState extends State<BullVaultCosignerScreen>
    with PrivacyScreen {
  String _passphrase = '';
  bool _consented = false;
  @override
  void initState() {
    super.initState();
    unawaited(enableScreenPrivacy());
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirm());
  }

  Future<void> _confirm() async {
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc.bullVaultCosignerWarningTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.loc.bullVaultCosignerWarning),
              const Gap(16),
              Text(context.loc.bullVaultCosignerWarningClarification),
              const Gap(16),
              Text(context.loc.bullVaultCosignerStored),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.loc.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.loc.bullVaultCosignerContinue),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (accepted != true) {
      context.pop();
      return;
    }
    setState(() => _consented = true);
  }

  @override
  void dispose() {
    _passphrase = '';
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<BullVaultCosignerCubit, BullVaultCosignerState>(
        listener: (context, state) {
          if (state is BullVaultCosignerAttached) context.pop(true);
        },
        builder: (context, state) {
          if (!_consented) return const Scaffold();
          final busy = state is BullVaultCosignerImporting;
          return PopScope(
            canPop: !busy,
            child: Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                forceMaterialTransparency: true,
                flexibleSpace: TopBar(
                  title: context.loc.bullVaultImportCosigner,
                  backEnabled: !busy,
                  onBack: () => context.pop(),
                ),
              ),
              body: SafeArea(
                child: AbsorbPointer(
                  absorbing: busy,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.loc.bullVaultCosignerStored,
                              style: context.font.bodyMedium,
                            ),
                            const Gap(16),
                            Text(
                              context.loc.passphraseLabel,
                              style: context.font.bodyMedium,
                            ),
                            const Gap(8),
                            ExcludeSemantics(
                              child: BullInputText(
                                value: _passphrase,
                                onChanged: (value) => _passphrase = value,
                                hint: context.loc.optionalPassphraseHint,
                                obscure: true,
                                maxLength: 1024,
                                enableSuggestions: false,
                                autocorrect: false,
                                smartQuotesType: SmartQuotesType.disabled,
                                smartDashesType: SmartDashesType.disabled,
                                maxLines: 1,
                              ),
                            ),
                            if (busy) ...[
                              const Gap(12),
                              const LinearProgressIndicator(),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: ExcludeSemantics(
                          child: MnemonicWidget(
                            initialLength: bip39.MnemonicLength.words12,
                            allowPassphrase: false,
                            allowLabel: false,
                            submitLabel: context.loc.bullVaultImportCosigner,
                            externalError: state is BullVaultCosignerFailed
                                ? state.failure.toTranslated(context)
                                : null,
                            onSubmit: (mnemonic) =>
                                context.read<BullVaultCosignerCubit>().attach(
                                  words: mnemonic.words,
                                  passphrase: _passphrase,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}
