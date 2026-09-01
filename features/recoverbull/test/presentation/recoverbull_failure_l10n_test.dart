import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/presentation/recoverbull_failure_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('translates every failure without exposing diagnostics', (
    tester,
  ) async {
    const diagnostic = 'technical diagnostic that must stay out of the UI';
    final failures = <RecoverBullFailure>[
      const SelectVaultFailure(),
      const PasswordNotSetFailure(),
      const VaultNotSetFailure(),
      const KeyServerConnectionFailure(),
      const VaultCreationFailure(),
      const VaultProviderSaveFailure(),
      const TorNotStartedFailure(),
      const ExternalTorProxyUnavailableFailure(diagnostic),
      const VaultKeyFetchFailure(),
      const VaultDecryptionFailure(),
      const VaultRecoveryFailure(),
      const InvalidVaultCredentialsFailure(),
      const InvalidVaultFileFormatFailure(),
      const VaultRateLimitedFailure(retryIn: Duration.zero),
      const KeyServerInvalidCredentialsFailure(diagnostic),
      const KeyServerRateLimitedFailure(logMessage: diagnostic),
      const KeyServerRejectedFailure(diagnostic),
      const KeyServerUnavailableFailure(diagnostic),
      const InvalidVaultFileFailure(diagnostic),
      const RecoverBullGoogleDriveFetchFailure(diagnostic),
      const RecoverBullGoogleDriveDeleteFailure(diagnostic),
      const RecoverBullGoogleDriveExportFailure(diagnostic),
      const RecoverBullUnexpectedFailure(diagnostic),
    ];

    final messages = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            messages.addAll(
              failures.map((failure) => failure.toTranslated(context)),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(messages, hasLength(failures.length));
    expect(messages, everyElement(isNot(contains(diagnostic))));
    expect(messages, everyElement(isNotEmpty));
  });
}
