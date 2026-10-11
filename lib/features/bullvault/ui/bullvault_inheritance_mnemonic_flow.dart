import 'dart:async';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/public/import_mnemonic_facade.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_failure_l10n.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_inheritance_mnemonic_cubit.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart'
    show BullInfoCard, BullSnackBar, BullScreenPrivacyGate;
import 'package:flutter/material.dart';
import 'package:bb_mobile/locator.dart';
import 'package:secrets/secrets.dart' show SecretWidgets;
import 'package:screen_privacy/screen_privacy.dart';

/// This flow keeps mnemonic material private and returns only the account key.
Future<String?> showBullVaultInheritanceMnemonic(
  BuildContext context, {
  required Network network,
  required bool generated,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(
    builder: (_) => generated
        ? _GeneratedInheritanceMnemonicScreen(network: network)
        : _ImportInheritanceMnemonicScreen(network: network),
  ),
);

final class _GeneratedInheritanceMnemonicScreen extends StatefulWidget {
  final Network network;

  const _GeneratedInheritanceMnemonicScreen({required this.network});

  @override
  State<_GeneratedInheritanceMnemonicScreen> createState() =>
      _GeneratedInheritanceMnemonicScreenState();
}

final class _GeneratedInheritanceMnemonicScreenState
    extends State<_GeneratedInheritanceMnemonicScreen> {
  late final _cubit = locator<BullVaultInheritanceMnemonicCubit>();
  late final Future<Result<SecretWidgets, BullVaultFailure>> _generation =
      _cubit.generate();

  Future<void> _verify(SecretWidgets mnemonic) async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => VerifyMnemonicScreen.forMnemonicWidgets(
          mnemonic: mnemonic,
          title: context.loc.bullVaultInheritanceMnemonicVerifyTitle,
          onVerified: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (!mounted || verified != true) return;
    final result = await _cubit.acceptGenerated(widget.network);
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final failure):
        BullSnackBar.show(context, message: failure.toTranslated(context));
    }
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<Result<SecretWidgets, BullVaultFailure>>(
        future: _generation,
        builder: (context, snapshot) {
          if (snapshot.data case Ok(:final value)) {
            return ShowMnemonicScreen.forMnemonicWidgets(
              mnemonic: value,
              title: context.loc.bullVaultInheritanceMnemonicShowTitle,
              notice: context.loc.bullVaultInheritanceMnemonicWarning,
              onContinue: () => _verify(value),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(context.loc.bullVaultInheritanceMnemonicShowTitle),
            ),
            body: Center(
              child: switch (snapshot.data) {
                Err(:final failure) => Text(failure.toTranslated(context)),
                _ => const CircularProgressIndicator(),
              },
            ),
          );
        },
      );
}

final class _ImportInheritanceMnemonicScreen extends StatefulWidget {
  final Network network;

  const _ImportInheritanceMnemonicScreen({required this.network});

  @override
  State<_ImportInheritanceMnemonicScreen> createState() =>
      _ImportInheritanceMnemonicScreenState();
}

final class _ImportInheritanceMnemonicScreenState
    extends State<_ImportInheritanceMnemonicScreen>
    with PrivacyScreen {
  late final _cubit = locator<BullVaultInheritanceMnemonicCubit>();
  late Future<bool> _privacyFuture = enableScreenPrivacy();

  @override
  void dispose() {
    unawaited(_cubit.close());
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  Future<void> _submitMnemonic(Mnemonic mnemonic) async {
    final result = await _cubit.import(
      mnemonic.words,
      widget.network,
      language: mnemonic.language,
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err():
        setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => BullScreenPrivacyGate(
    protection: _privacyFuture,
    unavailableMessage: context.loc.screenPrivacyUnavailable,
    retryLabel: context.loc.retry,
    onRetry: () => setState(() {
      _privacyFuture = enableScreenPrivacy();
    }),
    builder: (context) => Scaffold(
      appBar: AppBar(
        title: Text(context.loc.bullVaultInheritanceImportMnemonic),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: BullInfoCard(
                description: context.loc.bullVaultInheritanceMnemonicWarning,
                tagColor: context.appColors.warning,
                bgColor: context.appColors.warningContainer,
              ),
            ),
            Expanded(
              child: MnemonicWidget(
                initialLength: bip39.MnemonicLength.words12,
                allowPassphrase: false,
                allowLabel: false,
                onSubmit: _submitMnemonic,
                submitLabel: context.loc.continueButton,
                externalError: _cubit.state?.toTranslated(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
