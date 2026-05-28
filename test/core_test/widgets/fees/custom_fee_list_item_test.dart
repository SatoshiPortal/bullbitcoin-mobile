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
    bool showConfirmButton = true,
    int txSize = 140,
    int? committedAbsoluteFeesSat,
    void Function(NetworkFee fee)? onArm,
    Future<void> Function(NetworkFee fee)? onCommit,
    VoidCallback? onDisarm,
    VoidCallback? onConfirmed,
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
            onDisarm: onDisarm,
            onConfirmed: onConfirmed,
            allowAbsoluteToggle: allowAbsoluteToggle,
            showConfirmButton: showConfirmButton,
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
                showConfirmButton: true,
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

  group('CustomFeeListItem — dispose', () {
    testWidgets(
      'onDisarm fires when the widget is unmounted in modal mode',
      (tester) async {
        var disarmed = false;
        await pumpTile(tester, onDisarm: () => disarmed = true);

        // Replace the widget tree — triggers the tile's dispose.
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(
          disarmed,
          isTrue,
          reason:
              'modal mode relies on dispose to roll back the cubit arm '
              'state when the modal closes without Confirm',
        );
      },
    );

    testWidgets('onDisarm does NOT fire in RBF mode', (tester) async {
      // RBF eagerly commits on every keystroke, so there is no arm to roll
      // back on dispose. The widget should not invoke a (likely-irrelevant)
      // onDisarm callback in this mode.
      var disarmed = false;
      await pumpTile(
        tester,
        commitOnChange: true,
        onDisarm: () => disarmed = true,
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(disarmed, isFalse);
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
          find.textContaining('= 29 sats'),
          findsOneWidget,
          reason: 'unedited tile must surface the real BDK fee',
        );
        // And NOT the naive prediction.
          expect(find.textContaining('= 18 sats'), findsNothing);
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
      expect(find.textContaining('= 70 sats'), findsOneWidget);
      expect(find.textContaining('= 29 sats'), findsNothing);
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
        expect(find.textContaining('= 18 sats'), findsOneWidget);
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

        // Tapping confirm must not commit (button is disabled).
        await tester.tap(find.byType(InkWell).last, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(committed, isNull);
      },
    );
  });
}
