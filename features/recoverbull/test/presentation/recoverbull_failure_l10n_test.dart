import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/presentation/recoverbull_failure_l10n.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
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
      const KeyServerBusyFailure(
        retryIn: Duration(seconds: 30),
        logMessage: diagnostic,
      ),
      const KeyServerRejectedFailure(diagnostic),
      const KeyServerUnavailableFailure(diagnostic),
      const RecoverBullTemporarilyUnavailableFailure(
        retryIn: Duration(seconds: 30),
        logMessage: diagnostic,
      ),
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

  testWidgets('retry delays are rendered exactly in English', (tester) async {
    late List<String> messages;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            const durations = [
              Duration(seconds: -1),
              Duration(seconds: 1),
              Duration(seconds: 30),
              Duration(seconds: 59),
              Duration(seconds: 60),
              Duration(seconds: 61),
              Duration(seconds: 90),
              Duration(seconds: 120),
              Duration(seconds: 253),
            ];
            messages = [
              for (final duration in durations)
                VaultRateLimitedFailure(
                  retryIn: duration,
                ).toTranslated(context),
            ];
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(messages, [
      'Rate limited. Please try again in 1 second',
      'Rate limited. Please try again in 1 second',
      'Rate limited. Please try again in 30 seconds',
      'Rate limited. Please try again in 59 seconds',
      'Rate limited. Please try again in 1 minute',
      'Rate limited. Please try again in 1 minute 1 second',
      'Rate limited. Please try again in 1 minute 30 seconds',
      'Rate limited. Please try again in 2 minutes',
      'Rate limited. Please try again in 4 minutes 13 seconds',
    ]);
  });

  testWidgets('retry delays are rendered exactly in French for 429 and 503', (
    tester,
  ) async {
    late List<String> messages;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            messages = [
              const VaultRateLimitedFailure(
                retryIn: Duration(seconds: 253),
              ).toTranslated(context),
              const KeyServerBusyFailure(
                retryIn: Duration(seconds: 253),
              ).toTranslated(context),
            ];
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(messages, [
      'Limite de taux atteinte. Veuillez réessayer dans 4 minutes 13 secondes',
      'Le service est occupé. Veuillez réessayer dans 4 minutes 13 secondes.',
    ]);
  });

  testWidgets('503 failures retain their service-busy message', (tester) async {
    late List<String> messages;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            messages = [
              const KeyServerBusyFailure(
                retryIn: Duration(seconds: 30),
              ).toTranslated(context),
              const RecoverBullTemporarilyUnavailableFailure(
                retryIn: Duration(seconds: 30),
              ).toTranslated(context),
              const KeyServerBusyFailure().toTranslated(context),
              const RecoverBullTemporarilyUnavailableFailure().toTranslated(
                context,
              ),
              const KeyServerBusyFailure(
                retryIn: Duration(seconds: 61),
              ).toTranslated(context),
            ];
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(messages, [
      'The service is busy. Please try again in 30 seconds.',
      'The service is busy. Please try again in 30 seconds.',
      'The service is busy. Please try again later.',
      'The service is busy. Please try again later.',
      'The service is busy. Please try again in 1 minute 1 second.',
    ]);
  });

  testWidgets('retry delays are rendered exactly in French for every duration', (
    tester,
  ) async {
    late List<String> messages;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            const durations = [
              Duration(seconds: -1),
              Duration(seconds: 1),
              Duration(seconds: 30),
              Duration(seconds: 59),
              Duration(seconds: 60),
              Duration(seconds: 61),
              Duration(seconds: 90),
              Duration(seconds: 120),
              Duration(seconds: 253),
            ];
            messages = [
              for (final duration in durations)
                VaultRateLimitedFailure(
                  retryIn: duration,
                ).toTranslated(context),
            ];
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(messages, [
      'Limite de taux atteinte. Veuillez réessayer dans 1 seconde',
      'Limite de taux atteinte. Veuillez réessayer dans 1 seconde',
      'Limite de taux atteinte. Veuillez réessayer dans 30 secondes',
      'Limite de taux atteinte. Veuillez réessayer dans 59 secondes',
      'Limite de taux atteinte. Veuillez réessayer dans 1 minute',
      'Limite de taux atteinte. Veuillez réessayer dans 1 minute 1 seconde',
      'Limite de taux atteinte. Veuillez réessayer dans 1 minute 30 secondes',
      'Limite de taux atteinte. Veuillez réessayer dans 2 minutes',
      'Limite de taux atteinte. Veuillez réessayer dans 4 minutes 13 secondes',
    ]);
  });

  testWidgets('VaultServiceBusyFailure renders its optional retry delay', (
    tester,
  ) async {
    late List<String> messages;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            messages = [
              const VaultServiceBusyFailure(
                retryIn: Duration(seconds: 30),
              ).toTranslated(context),
              const VaultServiceBusyFailure().toTranslated(context),
            ];
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(messages, [
      'Le service est occupé. Veuillez réessayer dans 30 secondes.',
      'Le service est occupé. Veuillez réessayer plus tard.',
    ]);
  });
}
