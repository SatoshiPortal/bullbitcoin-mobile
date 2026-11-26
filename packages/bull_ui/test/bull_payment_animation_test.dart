import 'package:bull_ui/generated/l10n/bull_ui_localizations_en.dart';
import 'package:bull_ui/generated/l10n/bull_ui_localizations_fr.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/src/payments/payment_scenes.dart' show PaymentSceneText;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show Locale, MaterialApp, MediaQueryData, Text;

void main() {
  test('success treatment is high contrast on the payment background', () {
    const palette = PaymentAnimationPalette.standard;
    final foreground = palette.success.computeLuminance();
    final background = palette.background.computeLuminance();
    expect((foreground + .05) / (background + .05), greaterThan(4.5));
  });

  for (final appTheme in AppThemeType.values) {
    for (final highContrast in [false, true]) {
      testWidgets(
        '$appTheme success displays the proven localized milestone, high contrast $highContrast',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.themeData(appTheme),
              localizationsDelegates: const [bullUiLocalizationsDelegate],
              home: MediaQuery(
                data: MediaQueryData(
                  disableAnimations: true,
                  highContrast: highContrast,
                ),
                child: BullPaymentTransition(
                  network: BullPaymentNetwork.bitcoin,
                  phase: BullPaymentPhase.success,
                  progress: BullPaymentProgress(
                    steps: const ['Signée', 'Diffusée'],
                    completed: 2,
                  ),
                  status: 'En attente de confirmation',
                  skipLabel: 'Détails',
                  onSkip: () {},
                  onDone: () {},
                ),
              ),
            ),
          );
          expect(find.text('Diffusée'), findsOneWidget);
          expect(find.text('En attente de confirmation'), findsOneWidget);
          final headline = tester.widget<Text>(find.text('Diffusée'));
          expect(
            headline.style?.color,
            PaymentAnimationPalette.standard.success,
          );
        },
      );
    }
  }

  testWidgets('refunded state does not use success treatment', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        localizationsDelegates: const [bullUiLocalizationsDelegate],
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: BullPaymentTransition(
            network: BullPaymentNetwork.boltz,
            phase: BullPaymentPhase.failed,
            progress: BullPaymentProgress(
              steps: const ['Locked', 'Completed'],
              completed: 1,
              failedAt: 1,
              refund: BullPaymentRefund.done,
            ),
            status: 'Refunded',
            skipLabel: 'Details',
            onSkip: () {},
            onDone: () {},
          ),
        ),
      ),
    );
    final headline = tester.widget<Text>(find.text('Refunded'));
    expect(
      headline.style?.color,
      isNot(PaymentAnimationPalette.standard.success),
    );
  });

  for (final network in BullPaymentNetwork.values) {
    for (final phase in BullPaymentPhase.values) {
      testWidgets('$network $phase paints a static reduced-motion pose', (
        tester,
      ) async {
        var done = 0;
        var impacts = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: BullPaymentAnimation(
                network: network,
                phase: phase,
                onDone: () => done++,
                onImpact: () => impacts++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final terminal =
            phase == BullPaymentPhase.success ||
            phase == BullPaymentPhase.failed;
        expect(done, terminal ? 1 : 0);
        expect(impacts, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('pending transition offers a named skip without settling', (
    tester,
  ) async {
    var skipped = 0;
    var backdropTaps = 0;
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: BullPaymentTransition(
            network: BullPaymentNetwork.lightning,
            phase: BullPaymentPhase.sending,
            status: 'Payment pending',
            skipLabel: 'View details',
            onSkip: () => skipped++,
            onBackdropTap: () => backdropTaps++,
            onDone: () => done++,
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(100, 100));
    expect(backdropTaps, 1);
    expect(skipped, 0);
    await tester.tap(find.text('View details'));
    await tester.pump();
    expect(skipped, 1);
    expect(backdropTaps, 1);
    expect(done, 0);
  });

  testWidgets('bottom replaces the skip button in its slot', (tester) async {
    var skipped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: BullPaymentTransition(
            network: BullPaymentNetwork.lightning,
            phase: BullPaymentPhase.sending,
            status: 'Payment pending',
            skipLabel: 'View details',
            onSkip: () => skipped++,
            bottom: const Text('Switch'),
            onDone: () {},
          ),
        ),
      ),
    );
    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('View details'), findsNothing);
    expect(skipped, 0);
  });

  testWidgets('fast completion keeps the intro then plays one terminal phase', (
    tester,
  ) async {
    var done = 0;
    Widget screen(BullPaymentPhase phase) => MaterialApp(
      theme: AppTheme.themeData(AppThemeType.dark),
      home: BullPaymentTransition(
        network: BullPaymentNetwork.bitcoin,
        phase: phase,
        status: phase == BullPaymentPhase.sending ? 'Sending' : 'Sent',
        skipLabel: 'View details',
        onSkip: null,
        onDone: () => done++,
      ),
    );

    await tester.pumpWidget(screen(BullPaymentPhase.sending));
    await tester.pump();
    await tester.pumpWidget(screen(BullPaymentPhase.success));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sending'), findsOneWidget);
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Sent'), findsOneWidget);
    for (var frame = 0; frame < 50; frame++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(done, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(done, 1);
  });

  testWidgets('an inactive scene cannot finish in the background', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BullPaymentAnimation(
          network: BullPaymentNetwork.ark,
          phase: BullPaymentPhase.success,
          onDone: () => done++,
        ),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 3));
    expect(done, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(done, 1);
  });

  const steps = ['Lockup sent', 'Boltz locked', 'Claimed'];
  Widget host(Widget child, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        theme: AppTheme.themeData(AppThemeType.dark),
        localizationsDelegates: bullUiLocalizationsDelegates,
        supportedLocales: const [Locale('en'), Locale('fr'), Locale('es')],
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child,
        ),
      );
  BullPaymentTransition transition({
    BullPaymentNetwork network = BullPaymentNetwork.boltz,
    BullPaymentPhase phase = BullPaymentPhase.sending,
    BullPaymentDirection direction = BullPaymentDirection.outgoing,
    BullPaymentProgress? progress,
    String? statusTag,
    VoidCallback? onDone,
  }) => BullPaymentTransition(
    statusTag: statusTag,
    network: network,
    phase: phase,
    direction: direction,
    progress: progress,
    status: 'Sending',
    skipLabel: 'View details',
    onSkip: () {},
    onDone: onDone ?? () {},
  );

  const labels = [
    'Lockup sent',
    'Boltz locked',
    'Claim broadcast',
    'Completed',
  ];
  for (final network in BullPaymentNetwork.values) {
    for (final direction in BullPaymentDirection.values) {
      for (final phase in BullPaymentPhase.values) {
        for (final nodes in [2, 3, 4]) {
          for (final completed in {0, nodes - 1, nodes}) {
            testWidgets(
              '$network $direction $phase $completed/$nodes nodes paints',
              (tester) async {
                await tester.pumpWidget(
                  host(
                    transition(
                      network: network,
                      direction: direction,
                      phase: phase,
                      statusTag: 'PAID',
                      progress: BullPaymentProgress(
                        steps: labels.take(nodes).toList(),
                        completed: completed,
                        failedAt: phase == BullPaymentPhase.failed
                            ? completed.clamp(0, nodes - 1)
                            : null,
                        refund: phase == BullPaymentPhase.failed
                            ? BullPaymentRefund.available
                            : null,
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }
  }

  for (final network in BullPaymentNetwork.values) {
    for (final direction in BullPaymentDirection.values) {
      for (final nodes in [2, 3, 4]) {
        testWidgets('$network $direction skips node 1 of $nodes', (
          tester,
        ) async {
          await tester.pumpWidget(
            host(
              transition(
                network: network,
                direction: direction,
                progress: BullPaymentProgress(
                  steps: labels.take(nodes).toList(),
                  completed: 1,
                  skippedAt: 1,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final fraction in <double?>[null, 0, .4, 1]) {
    for (final phase in BullPaymentPhase.values) {
      for (final completed in [0, 1, 2, 3, 4]) {
        testWidgets('ark exit fraction $fraction $phase $completed/4 paints', (
          tester,
        ) async {
          await tester.pumpWidget(
            host(
              transition(
                network: BullPaymentNetwork.arkExit,
                phase: phase,
                progress: BullPaymentProgress(
                  steps: const [
                    'Exit started',
                    'Unrolling',
                    'Exit delay',
                    'Claim',
                  ],
                  completed: completed,
                  failedAt: phase == BullPaymentPhase.failed
                      ? completed.clamp(0, 3)
                      : null,
                  currentFraction: completed < 4 ? fraction : null,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  test('currentFraction takes part in equality and is bounded', () {
    BullPaymentProgress make(double? f) =>
        BullPaymentProgress(steps: steps, completed: 1, currentFraction: f);
    expect(make(.5), make(.5));
    expect(make(.5), isNot(make(null)));
    expect(make(.5).hashCode, make(.5).hashCode);
    expect(() => make(1.5), throwsA(isA<AssertionError>()));
  });

  test('a caller descriptor overrides the network descriptor', () {
    PaymentSceneText resolve(String? descriptor) => PaymentSceneText.resolve(
      BullUiLocalizationsEn(),
      network: BullPaymentNetwork.lightning,
      phase: BullPaymentPhase.sending,
      direction: BullPaymentDirection.outgoing,
      descriptor: descriptor,
    );
    expect(resolve('EXCHANGE // ORDER').descriptor, 'EXCHANGE // ORDER');
    expect(resolve(null).descriptor, 'LIGHTNING // INVOICE');
    expect(resolve('').descriptor, 'LIGHTNING // INVOICE');
  });

  testWidgets('the transition forwards a descriptor override', (tester) async {
    await tester.pumpWidget(
      host(
        BullPaymentTransition(
          network: BullPaymentNetwork.lightning,
          phase: BullPaymentPhase.sending,
          descriptor: 'EXCHANGE // ORDER',
          status: 'Sending',
          skipLabel: 'View details',
          onSkip: () {},
          onDone: () {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final animation = tester.widget<BullPaymentAnimation>(
      find.byType(BullPaymentAnimation),
    );
    expect(animation.descriptor, 'EXCHANGE // ORDER');
  });

  test('an Ark exit is never labelled sent or sending', () {
    PaymentSceneText resolve(BullPaymentPhase phase) =>
        PaymentSceneText.resolve(
          BullUiLocalizationsEn(),
          network: BullPaymentNetwork.arkExit,
          phase: phase,
          direction: BullPaymentDirection.outgoing,
        );
    expect(resolve(BullPaymentPhase.sending).tag, 'EXITING');
    expect(resolve(BullPaymentPhase.success).tag, 'EXITED');
    expect(resolve(BullPaymentPhase.failed).tag, 'FAILED');
  });

  testWidgets('a refundable swap stays in progress and shows no result', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(
      host(
        BullPaymentTransition(
          network: BullPaymentNetwork.boltz,
          phase: BullPaymentPhase.sending,
          progress: BullPaymentProgress(
            steps: const ['Lockup sent', 'Boltz locked', 'Claimed'],
            completed: 1,
            failedAt: 1,
            refund: BullPaymentRefund.available,
          ),
          status: 'Refund available',
          skipLabel: 'View details',
          onSkip: () {},
          onDone: () => done++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text('Stopped before step 2 of 3 · Boltz locked'),
      findsOneWidget,
    );
    expect(done, 0);
  });

  testWidgets('a refunded swap plays one terminal result', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      host(
        BullPaymentTransition(
          network: BullPaymentNetwork.boltz,
          phase: BullPaymentPhase.failed,
          progress: BullPaymentProgress(
            steps: const ['Lockup sent', 'Boltz locked', 'Claimed'],
            completed: 1,
            failedAt: 1,
            refund: BullPaymentRefund.done,
          ),
          status: 'Refunded',
          skipLabel: 'View details',
          onSkip: () {},
          onDone: () => done++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(done, 1);
  });

  test('the Ark exit descriptor is localized', () {
    expect(
      PaymentSceneText.resolve(
        BullUiLocalizationsEn(),
        network: BullPaymentNetwork.arkExit,
        phase: BullPaymentPhase.sending,
        direction: BullPaymentDirection.outgoing,
      ).descriptor,
      'ARK // UNILATERAL EXIT',
    );
    expect(
      PaymentSceneText.resolve(
        BullUiLocalizationsFr(),
        network: BullPaymentNetwork.arkExit,
        phase: BullPaymentPhase.sending,
        direction: BullPaymentDirection.outgoing,
      ).descriptor,
      'ARK // SORTIE UNILATÉRALE',
    );
  });

  test('skippedAt and refund take part in equality', () {
    BullPaymentProgress make({int? skippedAt, BullPaymentRefund? refund}) =>
        BullPaymentProgress(
          steps: steps,
          completed: 1,
          skippedAt: skippedAt,
          refund: refund,
        );
    expect(make(skippedAt: 1), make(skippedAt: 1));
    expect(make(skippedAt: 1), isNot(make()));
    expect(make(skippedAt: 1).hashCode, make(skippedAt: 1).hashCode);
    expect(make(refund: BullPaymentRefund.done), isNot(make()));
  });

  group('scene text', () {
    PaymentSceneText resolve(
      BullPaymentPhase phase,
      BullPaymentDirection direction, {
      String? tag,
      BullPaymentNetwork network = BullPaymentNetwork.bitcoin,
    }) => PaymentSceneText.resolve(
      BullUiLocalizationsEn(),
      network: network,
      phase: phase,
      direction: direction,
      statusTag: tag,
    );

    test('an incoming payment is never labelled as sending', () {
      expect(
        resolve(BullPaymentPhase.sending, BullPaymentDirection.incoming).tag,
        'RECEIVING',
      );
      expect(
        resolve(BullPaymentPhase.success, BullPaymentDirection.incoming).tag,
        'RECEIVED',
      );
      expect(
        resolve(BullPaymentPhase.sending, BullPaymentDirection.outgoing).tag,
        'SENDING',
      );
      expect(
        resolve(BullPaymentPhase.success, BullPaymentDirection.outgoing).tag,
        'SENT',
      );
      for (final phase in BullPaymentPhase.values) {
        expect(
          resolve(phase, BullPaymentDirection.incoming).tag,
          isNot('SENDING'),
        );
      }
    });

    test('the caller status tag wins over the fallback', () {
      expect(
        resolve(
          BullPaymentPhase.sending,
          BullPaymentDirection.incoming,
          tag: 'CLAIMABLE',
        ).tag,
        'CLAIMABLE',
      );
      expect(
        resolve(
          BullPaymentPhase.sending,
          BullPaymentDirection.incoming,
          tag: '',
        ).tag,
        'RECEIVING',
      );
    });

    test('descriptors name the network and the Payjoin BIP', () {
      expect(
        resolve(
          BullPaymentPhase.sending,
          BullPaymentDirection.outgoing,
          network: BullPaymentNetwork.payjoin,
        ).descriptor,
        'PAYJOIN // BIP 77',
      );
      expect(
        resolve(
          BullPaymentPhase.sending,
          BullPaymentDirection.outgoing,
        ).descriptor,
        'BITCOIN // ON-CHAIN',
      );
      expect(
        PaymentSceneText.resolve(
          BullUiLocalizationsFr(),
          network: BullPaymentNetwork.lightning,
          phase: BullPaymentPhase.sending,
          direction: BullPaymentDirection.incoming,
        ).tag,
        'RÉCEPTION',
      );
    });
  });

  testWidgets('rail names the current step and the steps left', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        transition(progress: BullPaymentProgress(steps: steps, completed: 1)),
      ),
    );
    expect(find.text('Step 2 of 3 · Boltz locked'), findsOneWidget);
    expect(find.text('1 step left'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Step 2 of 3 · Boltz locked. 1 step left'),
      findsOneWidget,
    );
    final node = tester.getSemantics(
      find.bySemanticsLabel('Step 2 of 3 · Boltz locked. 1 step left'),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('rail announces one step left in the plural form', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        transition(progress: BullPaymentProgress(steps: steps, completed: 2)),
      ),
    );
    expect(find.text('Step 3 of 3 · Claimed'), findsOneWidget);
    expect(find.text('1 step left'), findsOneWidget);
  });

  testWidgets('rail is localized', (tester) async {
    await tester.pumpWidget(
      host(
        transition(progress: BullPaymentProgress(steps: steps, completed: 2)),
        locale: const Locale('fr'),
      ),
    );
    expect(find.text('Étape 3 sur 3 · Claimed'), findsOneWidget);
    expect(find.text('1 étape restante'), findsOneWidget);
  });

  testWidgets('rail reports the failed step without a remaining count', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        transition(
          phase: BullPaymentPhase.failed,
          progress: BullPaymentProgress(
            steps: steps,
            completed: 1,
            failedAt: 1,
          ),
        ),
      ),
    );
    expect(
      find.text('Stopped before step 2 of 3 · Boltz locked'),
      findsOneWidget,
    );
    expect(find.textContaining('left'), findsNothing);
  });

  for (final refund in BullPaymentRefund.values) {
    testWidgets('rail never paints a $refund refund red', (tester) async {
      await tester.pumpWidget(
        host(
          transition(
            phase: refund == BullPaymentRefund.done
                ? BullPaymentPhase.failed
                : BullPaymentPhase.sending,
            progress: BullPaymentProgress(
              steps: steps,
              completed: 1,
              failedAt: 1,
              refund: refund,
            ),
          ),
        ),
      );
      final red = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.color == PaymentAnimationPalette.standard.failure,
      );
      expect(find.byType(BullPaymentStepRail), findsOneWidget);
      expect(red, findsNothing);
    });
  }

  testWidgets('a transition without progress shows no rail', (tester) async {
    await tester.pumpWidget(host(transition()));
    expect(find.textContaining('Step '), findsNothing);
    expect(find.text('View details'), findsOneWidget);
  });

  testWidgets('complete progress never plays a result before the phase', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(
      host(
        transition(
          network: BullPaymentNetwork.payjoin,
          progress: BullPaymentProgress(steps: steps, completed: 3),
          onDone: () => done++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Complete'), findsOneWidget);
    expect(done, 0);
  });

  testWidgets('a broadcast status is orange and never the completion', (
    tester,
  ) async {
    const palette = PaymentAnimationPalette.standard;
    await tester.pumpWidget(
      host(
        transition(
          network: BullPaymentNetwork.bitcoin,
          progress: BullPaymentProgress(
            steps: const ['Signing', 'Broadcasted', 'Confirmed'],
            completed: 1,
            currentState: BullPaymentStepState.broadcast,
          ),
        ),
      ),
    );
    final label = tester.widget<Text>(find.text('Step 2 of 3 · Broadcasted'));
    expect(label.style?.color, palette.broadcast);
    expect(find.text('1 step left'), findsOneWidget);
    expect(find.text('Complete'), findsNothing);
  });

  testWidgets('the headline takes the broadcast colour with the rail text', (
    tester,
  ) async {
    const palette = PaymentAnimationPalette.standard;
    Future<Color?> headline(BullPaymentStepState state) async {
      await tester.pumpWidget(
        host(
          transition(
            network: BullPaymentNetwork.bitcoin,
            progress: BullPaymentProgress(
              steps: const ['Signing', 'Broadcasted', 'Confirmed'],
              completed: 1,
              currentState: state,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<Text>(find.text('Sending')).style?.color;
    }

    expect(await headline(BullPaymentStepState.broadcast), palette.broadcast);
    expect(await headline(BullPaymentStepState.active), palette.foreground);
  });

  testWidgets('the last status turns green only with the success phase', (
    tester,
  ) async {
    const palette = PaymentAnimationPalette.standard;
    await tester.pumpWidget(
      host(
        transition(
          network: BullPaymentNetwork.bitcoin,
          phase: BullPaymentPhase.success,
          progress: BullPaymentProgress(
            steps: const ['Signing', 'Broadcasted', 'Confirmed'],
            completed: 1,
            currentState: BullPaymentStepState.broadcast,
          ),
        ),
      ),
    );
    final label = tester.widget<Text>(find.text('Step 3 of 3 · Confirmed'));
    expect(label.style?.color, palette.success);
    expect(find.text('Complete'), findsOneWidget);
  });

  testWidgets('the success phase still plays its single result', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(
      host(
        transition(
          phase: BullPaymentPhase.success,
          progress: BullPaymentProgress(steps: steps, completed: 3),
          onDone: () => done++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(done, 1);
  });
}
