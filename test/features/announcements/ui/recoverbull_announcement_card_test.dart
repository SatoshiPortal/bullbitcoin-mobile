import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/announcements/domain/entities/recoverbull_announcement.dart';
import 'package:bb_mobile/features/announcements/ui/announcement_navigation.dart';
import 'package:bb_mobile/features/announcements/ui/widgets/announcement_card.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/ui/screens/attempt_alert_detail_page.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('RecoverBull announcement exposes a localized dismiss action', (
    tester,
  ) async {
    final alert = RecoverBullAttemptAlert(
      RecoverBullAttemptAlertKind.unavailable,
    );
    await _pumpCard(
      tester,
      RecoverBullAnnouncement(primaryAlert: alert, sourceAlerts: [alert]),
    );

    final l10n = RecoverBullLocalizations.of(
      tester.element(find.byType(AnnouncementCard)),
    );
    final dismiss = find.bySemanticsLabel(
      l10n.recoverbullAttemptMonitoringDismiss,
    );
    expect(dismiss, findsOneWidget);
    expect(
      tester.getSemantics(dismiss),
      matchesSemantics(isButton: true, hasTapAction: true),
    );
  });

  testWidgets('body and dismiss actions invoke distinct callbacks', (
    tester,
  ) async {
    var bodyTaps = 0;
    var dismissTaps = 0;
    final alert = RecoverBullAttemptAlert(
      RecoverBullAttemptAlertKind.unavailable,
    );
    await _pumpCard(
      tester,
      RecoverBullAnnouncement(primaryAlert: alert, sourceAlerts: [alert]),
      onTap: () => bodyTaps++,
      onDismiss: () => dismissTaps++,
    );

    final l10n = RecoverBullLocalizations.of(
      tester.element(find.byType(AnnouncementCard)),
    );
    await tester.tap(
      find.bySemanticsLabel(l10n.recoverbullAttemptMonitoringDismiss),
    );
    expect(dismissTaps, 1);
    expect(bodyTaps, 0);

    await tester.tap(find.byType(BullInfoCard));
    expect(bodyTaps, 1);
    expect(dismissTaps, 1);
  });

  testWidgets('service pressure announcements expose their dedicated content', (
    tester,
  ) async {
    final cases = {
      RecoverBullAttemptAlertKind.servicePressure:
          'recoverbullAttemptMonitoringServicePressure',
      RecoverBullAttemptAlertKind.identifierSaturation:
          'recoverbullAttemptMonitoringIdentifierSaturation',
      RecoverBullAttemptAlertKind.unavailable:
          'recoverbullAttemptMonitoringUnavailableUnknownDuration',
    };
    for (final entry in cases.entries) {
      final alert = RecoverBullAttemptAlert(entry.key);
      await _pumpCard(
        tester,
        RecoverBullAnnouncement(primaryAlert: alert, sourceAlerts: [alert]),
      );
      final l10n = RecoverBullLocalizations.of(
        tester.element(find.byType(AnnouncementCard)),
      );
      final text = switch (entry.key) {
        RecoverBullAttemptAlertKind.servicePressure =>
          l10n.recoverbullAttemptMonitoringServicePressure,
        RecoverBullAttemptAlertKind.identifierSaturation =>
          l10n.recoverbullAttemptMonitoringIdentifierSaturation,
        RecoverBullAttemptAlertKind.unavailable =>
          l10n.recoverbullAttemptMonitoringUnavailableUnknownDuration,
        _ => throw StateError('unreachable'),
      };
      expect(find.text(text), findsExactly(2));
      expect(find.byType(BullInfoCard), findsOneWidget);
    }
  });

  testWidgets('English suspicious alert card opens its educational details', (
    tester,
  ) async {
    final alert = RecoverBullAttemptAlert.suspiciousActivity(
      backupReference: 'backup-a',
      correlationId: 'digest-a',
      observedTotal: 7,
      expectedTotal: 3,
      windowStartedAt: DateTime.utc(2026, 8, 5),
    );
    await _pumpCard(
      tester,
      RecoverBullAnnouncement(primaryAlert: alert, sourceAlerts: [alert]),
    );

    await tester.tap(find.byType(BullInfoCard));
    await tester.pumpAndSettle();

    final l10n = RecoverBullLocalizations.of(
      tester.element(find.byType(RecoverBullAttemptAlertDetailPage)),
    );
    expect(
      find.text(l10n.recoverbullAttemptAlertAttempts(3, 7)),
      findsOneWidget,
    );
    expect(
      find.textContaining('Reinstallation, another phone or device'),
      findsOneWidget,
    );
    expect(find.textContaining('If you recognize it'), findsOneWidget);
    expect(
      find.textContaining('new wallet with a new mnemonic'),
      findsOneWidget,
    );
    expect(find.textContaining('secure every backup copy'), findsOneWidget);
    expect(find.textContaining('contact support'), findsAtLeastNWidgets(1));
    expect(find.textContaining('too many failed attempts'), findsNothing);
  });

  testWidgets('English lockout details explain retry and migration choices', (
    tester,
  ) async {
    final alert = RecoverBullAttemptAlert.targetedLockout(
      backupReference: 'backup-a',
      correlationId: 'digest-a',
    );
    await _pumpCard(
      tester,
      RecoverBullAnnouncement(primaryAlert: alert, sourceAlerts: [alert]),
    );

    await tester.tap(find.byType(BullInfoCard));
    await tester.pumpAndSettle();

    expect(find.textContaining('too many failed attempts'), findsOneWidget);
    expect(find.textContaining('wait and try again'), findsOneWidget);
    expect(
      find.textContaining('move funds to a new wallet with a new mnemonic'),
      findsAtLeastNWidgets(1),
    );
    expect(find.textContaining('contact support'), findsAtLeastNWidgets(1));
    expect(
      find.textContaining('Reinstallation, another phone or device'),
      findsNothing,
    );
  });

  testWidgets(
    'consolidated details show both proofs and only the backup prefix',
    (tester) async {
      final suspicious = RecoverBullAttemptAlert.suspiciousActivity(
        backupReference: 'backup-a',
        correlationId: 'full-digest-must-not-render',
        observedTotal: 7,
        expectedTotal: 3,
        windowStartedAt: DateTime.utc(2026, 8, 5),
      );
      final lockout = RecoverBullAttemptAlert.targetedLockout(
        backupReference: 'backup-a',
        correlationId: 'full-digest-must-not-render',
      );
      await _pumpCard(
        tester,
        RecoverBullAnnouncement(
          primaryAlert: suspicious,
          sourceAlerts: [suspicious, lockout],
        ),
      );

      await tester.tap(find.byType(BullInfoCard));
      await tester.pumpAndSettle();

      expect(find.text('Backup reference: backup-a'), findsOneWidget);
      expect(find.textContaining('Attempts: 7 / expected: 3'), findsOneWidget);
      expect(
        find.textContaining('The server temporarily limited access'),
        findsOneWidget,
      );
      expect(find.textContaining('full-digest-must-not-render'), findsNothing);
      expect(find.textContaining('Backup reference:'), findsOneWidget);
    },
  );

  testWidgets('French suspicious alert details keep the same safety guidance', (
    tester,
  ) async {
    final alert = RecoverBullAttemptAlert.suspiciousActivity(
      backupReference: 'sauvegarde-a',
      correlationId: 'digest-a',
      observedTotal: 7,
      expectedTotal: 3,
      windowStartedAt: DateTime.utc(2026, 8, 5),
    );
    await _pumpCard(
      tester,
      RecoverBullAnnouncement(primaryAlert: alert, sourceAlerts: [alert]),
      locale: const Locale('fr'),
    );

    await tester.tap(find.byType(BullInfoCard));
    await tester.pumpAndSettle();

    final l10n = RecoverBullLocalizations.of(
      tester.element(find.byType(RecoverBullAttemptAlertDetailPage)),
    );
    expect(
      find.text(l10n.recoverbullAttemptAlertAttempts(3, 7)),
      findsOneWidget,
    );
    expect(find.textContaining('Une réinstallation'), findsOneWidget);
    expect(find.textContaining('Si vous les reconnaissez'), findsOneWidget);
    expect(
      find.textContaining(
        'nouveau portefeuille avec une nouvelle phrase mnémotechnique',
      ),
      findsOneWidget,
    );
  });

  for (final locale in const [Locale('en'), Locale('fr')]) {
    for (final kind in const [
      RecoverBullAttemptAlertKind.suspiciousActivity,
      RecoverBullAttemptAlertKind.targetedLockout,
    ]) {
      testWidgets(
        'details do not overflow at high text scale ($locale, $kind)',
        (tester) async {
          final alert = kind == RecoverBullAttemptAlertKind.suspiciousActivity
              ? RecoverBullAttemptAlert.suspiciousActivity(
                  backupReference: 'backup-a',
                  correlationId: 'digest-a',
                  observedTotal: 17,
                  expectedTotal: 3,
                  windowStartedAt: DateTime.utc(2026, 8, 5),
                )
              : RecoverBullAttemptAlert.targetedLockout(
                  backupReference: 'backup-a',
                  correlationId: 'digest-a',
                );
          await tester.binding.setSurfaceSize(const Size(320, 568));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final textScaleNotifier = ValueNotifier(1.0);
          addTearDown(textScaleNotifier.dispose);
          await _pumpCard(
            tester,
            RecoverBullAnnouncement(primaryAlert: alert, sourceAlerts: [alert]),
            locale: locale,
            textScaleNotifier: textScaleNotifier,
          );
          await tester.tap(find.byType(BullInfoCard));
          await tester.pumpAndSettle();
          textScaleNotifier.value = 2.5;
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _pumpCard(
  WidgetTester tester,
  RecoverBullAnnouncement announcement, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  ValueNotifier<double>? textScaleNotifier,
  VoidCallback? onTap,
  VoidCallback? onDismiss,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        RecoverBullLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ValueListenableBuilder<double>(
          valueListenable: textScaleNotifier ?? ValueNotifier(textScale),
          builder: (context, scale, child) => MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          child: AnnouncementCard(
            announcement: announcement,
            onTap:
                onTap ??
                () => announcement.open(
                  tester.element(find.byType(AnnouncementCard)),
                ),
            onDismiss: onDismiss ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
