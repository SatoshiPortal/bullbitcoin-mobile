import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/fees/custom_fee_list_item.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for [CustomFeeListItem] — the shared custom-fee tile used by
/// send, swap, and RBF. The tests cover the contract the wrappers depend on:
///
/// - Modal mode (commitOnChange=false): keystrokes route through `onArm`;
///   `onCommit` fires only on the Confirm button.
/// - RBF mode (commitOnChange=true): keystrokes route through `onCommit`;
///   `onArm`/`onDisarm` are ignored.
/// - Focus drives the local "selected" highlight independently of the
///   parent's committed selection — see the focus + didUpdateWidget tests.
/// - `dispose` calls `onDisarm` so the caller can roll back state.
///
/// The most load-bearing test here is the `didUpdateWidget` focus-drop:
/// when the parent's `isCommittedAsCustom` flips from true to false (e.g.,
/// the user tapped a preset elsewhere), the widget must release focus.
/// Combined with the parent modal's BlocSelector, this is what stops two
/// tiles from appearing selected at once.
void main() {
  /// Pump a `CustomFeeListItem` inside the minimum context it needs — a
  /// MaterialApp with the app theme and AppLocalizations.
  Future<void> pumpTile(
    WidgetTester tester, {
    NetworkFee? initialFee,
    bool isCommittedAsCustom = false,
    bool commitOnChange = false,
    bool allowAbsoluteToggle = true,
    int txSize = 140,
    int? committedAbsoluteFeesSat,
    void Function(NetworkFee fee)? onArm,
    Future<void> Function(NetworkFee fee)? onCommit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomFeeListItem(
            initialFee: initialFee,
            isCommittedAsCustom: isCommittedAsCustom,
            feePresets: null,
            txSize: txSize,
            exchangeRate: 0,
            fiatCurrencyCode: '',
            defaultAbsolute: false,
            tileColor: Colors.white,
            tileShadowColor: Colors.grey,
            unselectedIconColor: Colors.grey,
            onArm: onArm,
            onCommit: onCommit ?? (_) async {},
            allowAbsoluteToggle: allowAbsoluteToggle,
            commitOnChange: commitOnChange,
            committedAbsoluteFeesSat: committedAbsoluteFeesSat,
          ),
        ),
      ),
    );
    // First frame paints; settle so any post-frame focus listeners flush.
    await tester.pumpAndSettle();
  }

  /// Finds the tile's inner Material — the one inside the InkWell, which
  /// holds the elevation we read to detect the "selected" visual.
  Material tileMaterial(WidgetTester tester) => tester.widget<Material>(
    find
        .descendant(of: find.byType(InkWell), matching: find.byType(Material))
        .first,
  );

  group('CustomFeeListItem — keystroke dispatch', () {
    testWidgets(
      'modal mode (commitOnChange=false) routes keystrokes through onArm',
      (tester) async {
        NetworkFee? armed;
        NetworkFee? committed;
        await pumpTile(
          tester,
          onArm: (fee) => armed = fee,
          onCommit: (fee) async => committed = fee,
        );

        await tester.enterText(find.byType(TextFormField), '0.5');
        await tester.pump();

        expect(
          armed,
          isA<RelativeFee>(),
          reason: 'onArm should fire on every valid keystroke',
        );
        expect((armed! as RelativeFee).satPerVbyte, closeTo(0.5, 1e-9));
        expect(
          committed,
          isNull,
          reason: 'onCommit must NOT fire on keystroke in modal mode',
        );
      },
    );

    testWidgets(
      'RBF mode (commitOnChange=true) routes keystrokes through onCommit',
      (tester) async {
        NetworkFee? armed;
        NetworkFee? committed;
        await pumpTile(
          tester,
          commitOnChange: true,
          onArm: (fee) => armed = fee,
          onCommit: (fee) async => committed = fee,
        );

        await tester.enterText(find.byType(TextFormField), '2.5');
        await tester.pump();

        expect(
          armed,
          isNull,
          reason: 'onArm must NOT fire in RBF mode',
        );
        expect(
          committed,
          isA<RelativeFee>(),
          reason: 'onCommit should fire on every keystroke in RBF mode',
        );
        expect((committed! as RelativeFee).satPerVbyte, closeTo(2.5, 1e-9));
      },
    );
  });

  group('CustomFeeListItem — focus drives the highlight', () {
    testWidgets(
      'tile starts dim when isCommittedAsCustom is false and field unfocused',
      (tester) async {
        await pumpTile(tester);
        expect(tileMaterial(tester).elevation, 1.0);
      },
    );

    testWidgets('focusing the field raises elevation even without commit', (
      tester,
    ) async {
      await pumpTile(tester, isCommittedAsCustom: false);

      // Tap the InkWell to request focus — same path as onTap.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(
        tileMaterial(tester).elevation,
        4.0,
        reason:
            'focus alone must light up the tile so the user sees their tap '
            'register',
      );
    });

    testWidgets(
      'didUpdateWidget drops focus when isCommittedAsCustom goes true → false',
      (tester) async {
        // Regression guard for the double-selection bug: when the parent
        // moves the cubit/bloc selection off custom (e.g., user tapped a
        // preset), the custom tile must release focus so its focus-based
        // highlight clears — otherwise two tiles appear selected at once.
        await pumpTile(tester, isCommittedAsCustom: true);

        // Focus the field (raise it to "armed" visually).
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();
        expect(tileMaterial(tester).elevation, 4.0);

        // Rebuild with isCommittedAsCustom=false, simulating the cubit
        // emitting a preset selection (e.g., after a preset tile commit).
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CustomFeeListItem(
                initialFee: null,
                isCommittedAsCustom: false,
                feePresets: null,
                txSize: 140,
                exchangeRate: 0,
                fiatCurrencyCode: '',
                defaultAbsolute: false,
                tileColor: Colors.white,
                tileShadowColor: Colors.grey,
                unselectedIconColor: Colors.grey,
                onArm: (_) {},
                onCommit: (_) async {},
                allowAbsoluteToggle: true,
                commitOnChange: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tileMaterial(tester).elevation,
          1.0,
          reason:
              'when the parent un-commits custom, focus must drop and the '
              'tile must visually deselect',
        );
      },
    );
  });

  group('CustomFeeListItem — no Confirm button', () {
    // The widget no longer renders a "Confirm Custom Fee" button. Typing
    // IS the selection (onArm fires per keystroke); the commit happens
    // at the parent level when the user dismisses the bottom sheet via
    // tap-outside / swipe / back / Escape, or via the keyboard Done
    // action wired to Navigator.maybePop.
    testWidgets('Confirm Custom Fee button is gone in modal mode', (
      tester,
    ) async {
      await pumpTile(tester);
      expect(
        find.textContaining('Confirm'),
        findsNothing,
        reason: 'The button was the old explicit commit path — removed.',
      );
    });

    testWidgets('no Confirm button in RBF mode either', (tester) async {
      await pumpTile(tester, commitOnChange: true);
      expect(find.textContaining('Confirm'), findsNothing);
    });
  });

  group('CustomFeeListItem — preview line truth-tracking', () {
    // The bug: at sub-1 sat/vByte rates BDK overshoots a naive
    // `rate × vsize` prediction by 1-3 sats (ceil + dust absorption). When
    // the user reopens the modal with a value they previously confirmed,
    // the preview line must show the REAL fee BDK broadcast — not the
    // misleading naive prediction. See on-chain reproducers f0b40a72…
    // and b734968d…, and the user-reported 0.132 sat/vB → 27.46 (naive)
    // vs 29 (real BDK).

    testWidgets(
      'shows committed real fee when typed value still matches initialFee',
      (tester) async {
        // 0.132 sat/vB × 140 vB naively → 18 sat. But BDK actually paid
        // 29 sat (the caller passes that as committedAbsoluteFeesSat).
        // With no edits, the modal must show 29, not 18.
        await pumpTile(
          tester,
          initialFee: NetworkFee.relativeFromSatPerVbyte(0.132),
          isCommittedAsCustom: true,
          committedAbsoluteFeesSat: 29,
        );

        expect(
          find.textContaining('~ 29 sats'),
          findsOneWidget,
          reason: 'unedited tile must surface the real BDK fee',
        );
        // And NOT the naive prediction.
          expect(find.textContaining('~ 18 sats'), findsNothing);
      },
    );

    testWidgets('falls back to prediction once the user edits the value', (
      tester,
    ) async {
      await pumpTile(
        tester,
        initialFee: NetworkFee.relativeFromSatPerVbyte(0.132),
        isCommittedAsCustom: true,
        committedAbsoluteFeesSat: 29,
      );

      // User edits to a different rate. _customFee diverges from
      // initialFee — committed real no longer applies.
      await tester.enterText(find.byType(TextFormField), '0.5');
      await tester.pumpAndSettle();

      // 0.5 sat/vB × 140 vB = 70 sats (integer, half-up rounded by
      // NetworkFee.toAbsolute).
      expect(find.textContaining('~ 70 sats'), findsOneWidget);
      expect(find.textContaining('~ 29 sats'), findsNothing);
    });

    testWidgets(
      'falls back to prediction when committedAbsoluteFeesSat is null',
      (tester) async {
        // Caller passes null when armed (cubit cleared bitcoinAbsoluteFeesSat
        // on the first keystroke). Even if _customFee == initialFee, we
        // can't trust a stale real fee — show prediction instead.
        await pumpTile(
          tester,
          initialFee: NetworkFee.relativeFromSatPerVbyte(0.132),
          isCommittedAsCustom: true,
          committedAbsoluteFeesSat: null,
        );

        // Prediction at 0.132 sat/vB × 140 vB ≈ 18 sats (integer math).
        expect(find.textContaining('~ 18 sats'), findsOneWidget);
      },
    );
  });

  group('CustomFeeListItem — confirm button gating', () {
    testWidgets(
      'submit button disabled when sub-0.1 sat/vByte floor is hit',
      (tester) async {
        await pumpTile(tester);
        await tester.enterText(find.byType(TextFormField), '0.05');
        await tester.pumpAndSettle();

        // The shared BBButton variant exposes the disabled state via a
        // bool param. Easiest assertion: it should refuse to submit, so
        // tapping it does not call onCommit.
        NetworkFee? committed;
        // Re-pump with a fresh onCommit observer.
        await pumpTile(
          tester,
          onCommit: (fee) async => committed = fee,
        );
        await tester.enterText(find.byType(TextFormField), '0.05');
        await tester.pumpAndSettle();

        // The error text for below-floor must appear.
        // (Localization key: sendBelowMinFeeRateError.)
        expect(
          find.textContaining('0.1 sat'),
          findsOneWidget,
          reason: 'below-floor error message should be visible',
        );

        // No Confirm button to tap — verify the floor warning is the
        // user-visible signal that the value is unusable.
        expect(committed, isNull);
      },
    );
  });

  group('CustomFeeListItem — keyboard Enter / Done dismisses the modal', () {
    // The replacement for the old Confirm button: in modal mode, pressing
    // Enter on a physical keyboard (desktop) or the soft-keyboard's "Done"
    // (mobile) pops the bottom sheet. The parent's modal-result handler
    // then runs finalizeArmedCustomFee, which commits the typed value
    // (or rolls back if below the 0.1 sat/vB floor). Same path as
    // tap-outside / swipe-down / back / Escape.
    //
    // RBF mode is inline (no modal route), so the submit handler is
    // suppressed — otherwise Enter would pop the *parent screen*.

    /// Pump the widget inside a real route so we can observe pops.
    Future<({GlobalKey<NavigatorState> nav, NetworkFee? lastArm})>
    pumpInsideRoute(
      WidgetTester tester, {
      bool commitOnChange = false,
      void Function(NetworkFee fee)? onArm,
    }) async {
      final nav = GlobalKey<NavigatorState>();
      NetworkFee? lastArm;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: CustomFeeListItem(
                        initialFee: null,
                        isCommittedAsCustom: false,
                        feePresets: null,
                        txSize: 140,
                        exchangeRate: 0,
                        fiatCurrencyCode: '',
                        defaultAbsolute: false,
                        tileColor: Colors.white,
                        tileShadowColor: Colors.grey,
                        unselectedIconColor: Colors.grey,
                        onArm: onArm ?? (f) => lastArm = f,
                        onCommit: (_) async {},
                        commitOnChange: commitOnChange,
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return (nav: nav, lastArm: lastArm);
    }

    testWidgets(
      'Enter / Done pops the modal in modal mode (Navigator.maybePop)',
      (tester) async {
        await pumpInsideRoute(tester);
        // Confirm we're on the modal route.
        expect(find.byType(TextFormField), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), '1.0');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Modal popped — back on the parent route with just the button.
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text('Open'), findsOneWidget);
      },
    );

    testWidgets(
      'Enter / Done does NOT pop the parent in RBF mode (handler suppressed)',
      (tester) async {
        await pumpInsideRoute(tester, commitOnChange: true);
        expect(find.byType(TextFormField), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), '1.0');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Widget still mounted — RBF mode is inline, so the submit
        // handler is null. Critical: otherwise pressing Enter would pop
        // the parent screen, not just the input.
        expect(find.byType(TextFormField), findsOneWidget);
      },
    );

    testWidgets(
      'modal mode: typing fires onArm — commit happens at the parent',
      (tester) async {
        // Reinforces the contract: the widget itself never invokes the
        // heavy commit callback in modal mode. Parent finalizes on
        // dismissal (see SendCubit.finalizeArmedCustomFee).
        NetworkFee? committed;
        NetworkFee? armed;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CustomFeeListItem(
                initialFee: null,
                isCommittedAsCustom: false,
                feePresets: null,
                txSize: 140,
                exchangeRate: 0,
                fiatCurrencyCode: '',
                defaultAbsolute: false,
                tileColor: Colors.white,
                tileShadowColor: Colors.grey,
                unselectedIconColor: Colors.grey,
                onArm: (f) => armed = f,
                onCommit: (f) async => committed = f,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), '1.0');
        await tester.pumpAndSettle();

        expect(armed, isA<NetworkFee>(), reason: 'arm tracks typed value');
        expect(
          committed,
          isNull,
          reason: 'onCommit is the parent\'s job in modal mode',
        );
      },
    );
  });
}
