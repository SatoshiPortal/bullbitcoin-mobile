import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_words_cubit.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// Shows the twelve magic backup words behind the PIN and the capture block.
///
/// The words are derived only after both gates have passed, so nothing secret
/// is built, held or handed to another widget until then. No quiz follows them:
/// writing them down is what the person came here to do, and a
/// recorded answer would not make the words any safer.
class BackupWordsScreen extends StatefulWidget {
  final AppUnlockFacade appUnlock;

  const BackupWordsScreen({
    super.key,
    this.appUnlock = const AppUnlockFacade(),
  });

  @override
  State<BackupWordsScreen> createState() => _BackupWordsScreenState();
}

class _BackupWordsScreenState extends State<BackupWordsScreen>
    with PrivacyScreen {
  late final Future<void> _privacy = enableScreenPrivacy();
  bool _authenticated = false;
  Future<List<String>?>? _words;

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return widget.appUnlock.buildReauthenticationGate(
        canPop: true,
        onSuccess: (_) => setState(() => _authenticated = true),
      );
    }
    return PrivacyGate(
      protection: _privacy,
      unprotected: const PrivacyUnavailableNotice(),
      builder: (context) {
        _words ??= context.read<BackupWordsCubit>().reveal();
        return FutureBuilder<List<String>?>(
          future: _words,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _BackupWordsMessage();
            }
            final words = snapshot.data;
            if (words == null) return const _BackupWordsMessage();
            return ShowMnemonicScreen.forMnemonic(
              mnemonic: words,
              title: context.loc.backupWordsTitle,
              notice: context.loc.backupWordsExplanation,
              onContinue: () => Navigator.of(context).pop(),
            );
          },
        );
      },
    );
  }
}

/// The screen while the words are being derived, and when they cannot be.
class _BackupWordsMessage extends StatelessWidget {
  const _BackupWordsMessage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.backupWordsTitle)),
    body: SafeArea(
      child: BlocBuilder<BackupWordsCubit, BackupWordsState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              context.loc.backupWordsExplanation,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(24),
            if (state.failure case final failure?)
              Text(failure.toTranslated(context), style: context.font.bodyLarge)
            else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    ),
  );
}
