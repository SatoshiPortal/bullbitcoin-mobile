import 'dart:async';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/derive_bullvault_mnemonic_key_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/generate_bullvault_inheritance_mnemonic_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_failure_l10n.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';

part '../presentation/bullvault_inheritance_mnemonic_cubit.dart';

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
    extends State<_GeneratedInheritanceMnemonicScreen>
    with PrivacyScreen {
  late final _InheritanceMnemonicCubit _cubit = _InheritanceMnemonicCubit(
    widget.network,
  );
  late final Future<void> _privacyFuture = _protectAndGenerate();

  Future<void> _protectAndGenerate() async {
    await enableScreenPrivacy();
    if (!mounted) return;
    _cubit.generate();
  }

  Future<void> _verify() async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => VerifyMnemonicScreen.forMnemonic(
          mnemonic: _cubit._words,
          title: context.loc.bullVaultInheritanceMnemonicVerifyTitle,
          onVerified: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (!mounted || verified != true) return;
    switch (_cubit.derive(_cubit._words)) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final failure):
        BullSnackBar.show(context, message: failure.toTranslated(context));
    }
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _privacyFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          _cubit.state == null) {
        return ShowMnemonicScreen.forMnemonic(
          mnemonic: _cubit._words,
          title: context.loc.bullVaultInheritanceMnemonicShowTitle,
          notice: context.loc.bullVaultInheritanceMnemonicWarning,
          onContinue: _verify,
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(context.loc.bullVaultInheritanceMnemonicShowTitle),
        ),
        body: Center(
          child: snapshot.connectionState != ConnectionState.done
              ? const CircularProgressIndicator()
              : Text(
                  _cubit.state?.toTranslated(context) ??
                      context.loc.oopsSomethingWentWrong,
                ),
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
  late final _InheritanceMnemonicCubit _cubit = _InheritanceMnemonicCubit(
    widget.network,
  );

  @override
  void initState() {
    super.initState();
    unawaited(enableScreenPrivacy());
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  void _submitMnemonic(Mnemonic mnemonic) {
    switch (_cubit.derive(mnemonic.words)) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err():
        setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.bullVaultInheritanceImportMnemonic)),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: InfoCard(
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
  );
}
