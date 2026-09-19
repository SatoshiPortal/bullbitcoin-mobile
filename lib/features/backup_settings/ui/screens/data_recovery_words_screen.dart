import 'dart:async';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/reveal_data_recovery_words_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show BullSpacing, Gap;
import 'package:flutter/material.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// Reads internally; neither the route nor a cubit receives the words.
class DataRecoveryWordsScreen extends StatefulWidget {
  final String? expectedFingerprint;
  final bool forVault;

  const DataRecoveryWordsScreen({super.key})
    : expectedFingerprint = null,
      forVault = false;

  const DataRecoveryWordsScreen.forVault({
    super.key,
    required this.expectedFingerprint,
  }) : forVault = true;

  @override
  State<DataRecoveryWordsScreen> createState() =>
      _DataRecoveryWordsScreenState();
}

class _DataRecoveryWordsScreenState extends State<DataRecoveryWordsScreen>
    with PrivacyScreen {
  late Future<Result<RevealedDataRecoveryWords, BackupSettingsFailure>> _words =
      _load();

  Future<Result<RevealedDataRecoveryWords, BackupSettingsFailure>>
  _load() async {
    final origin = widget.expectedFingerprint;
    final forVault = widget.forVault;
    await enableScreenPrivacy();
    if (!mounted ||
        origin != widget.expectedFingerprint ||
        forVault != widget.forVault) {
      return const Err(BackupSettingsWordsUnavailableFailure());
    }
    return locator<RevealDataRecoveryWordsUsecase>().execute(
      expectedFingerprint: origin,
      forVault: forVault,
    );
  }

  @override
  void didUpdateWidget(covariant DataRecoveryWordsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expectedFingerprint != widget.expectedFingerprint ||
        oldWidget.forVault != widget.forVault) {
      _words = _load();
    }
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.dataBackupWordsTitle)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(BullSpacing.lg),
        children: [
          Text(context.loc.dataBackupWordsExplanation),
          const Gap(BullSpacing.lg),
          FutureBuilder<
            Result<RevealedDataRecoveryWords, BackupSettingsFailure>
          >(
            future: _words,
            builder: (context, snapshot) {
              // A changed origin must never retain the previous future's words.
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Text(context.loc.dataBackupWordsUnavailable);
              }
              switch (snapshot.data!) {
                case Err(:final failure):
                  return Text(failure.toTranslated(context));
                case Ok(:final value):
                  final words = value.words.split(' ');
                  return ExcludeSemantics(
                    child: Column(
                      children: [
                        for (var row = 0; row < 6; row++) ...[
                          Row(
                            children: [
                              for (final index in [row, row + 6])
                                Expanded(
                                  child: Text(
                                    '${index + 1}. ${words[index]}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                            ],
                          ),
                          const Gap(BullSpacing.md),
                        ],
                      ],
                    ),
                  );
              }
            },
          ),
          const Gap(BullSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.loc.testBackupNext),
          ),
        ],
      ),
    ),
  );
}
