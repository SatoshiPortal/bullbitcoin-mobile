import 'package:secrets/secrets.dart';
import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_data_recovery_secret_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSpacing, Gap;
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
  late Future<Result<Secret, BackupSettingsFailure>> _words = _load();

  Future<Result<Secret, BackupSettingsFailure>> _load() async {
    final origin = widget.expectedFingerprint;
    final forVault = widget.forVault;
    final protected = await enableScreenPrivacy();
    if (!protected ||
        !mounted ||
        origin != widget.expectedFingerprint ||
        forVault != widget.forVault) {
      return const Err(BackupSettingsWordsUnavailableFailure());
    }
    return locator<GetDataRecoverySecretUsecase>().execute(
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
          Text(
            context.loc.dataBackupWordsExplanation,
            style: context.font.bodyMedium,
          ),
          const Gap(BullSpacing.lg),
          FutureBuilder<Result<Secret, BackupSettingsFailure>>(
            future: _words,
            builder: (context, snapshot) {
              // A changed origin must never retain the previous future's words.
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Text(context.loc.dataBackupWordsUnavailable);
              }
              switch (snapshot.data) {
                case null:
                  return Text(context.loc.dataBackupWordsUnavailable);
                case Err(:final failure):
                  return Text(failure.toTranslated(context));
                case Ok(:final value):
                  return value.widgets.dataRecoveryWords(
                    style: context.font.titleMedium,
                    failureBuilder: (context, failure, retry) =>
                        Text(context.loc.dataBackupWordsUnavailable),
                    placeholder: const Center(
                      child: CircularProgressIndicator(),
                    ),
                    wordBuilder: (context, number, word) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$number. ', style: context.font.titleMedium),
                        Expanded(child: word),
                      ],
                    ),
                    layoutBuilder: (context, words) => LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns =
                            constraints.maxWidth >=
                            MediaQuery.textScalerOf(context).scale(280);
                        final width = twoColumns
                            ? (constraints.maxWidth - BullSpacing.md) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: BullSpacing.md,
                          runSpacing: BullSpacing.md,
                          children: [
                            for (final index
                                in twoColumns
                                    ? [
                                        for (var row = 0; row < 6; row++) ...[
                                          row,
                                          row + 6,
                                        ],
                                      ]
                                    : List.generate(
                                        words.length,
                                        (index) => index,
                                      ))
                              SizedBox(width: width, child: words[index]),
                          ],
                        );
                      },
                    ),
                  );
              }
            },
          ),
          const Gap(BullSpacing.lg),
          BullButton.big(
            maxLines: null,
            onPressed: () => Navigator.of(context).pop(),
            label: context.loc.testBackupNext,
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
        ],
      ),
    ),
  );
}
