import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/fees/custom_fee_list_item.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for [CustomFeeListItem] — the shared custom-fee tile used
/// by send, swap, and RBF.
///
/// **Architectural contract under test:** the widget never computes a fee
/// from `rate × vsize`. In modal mode (commitOnChange=false) the parent
/// builds an unsigned PSBT in response to a debounced [onPreview] call
/// and reports the real fee back via [previewFeeSat] / [previewLoading].
/// While loading, the preview row renders a shimmer. When a real fee
/// arrives, the row renders it verbatim. RBF mode (commitOnChange=true)
/// commits on every keystroke instead.
void main() {
  Future<void> pumpTile(
    WidgetTester tester, {
    NetworkFee? initialFee,
    bool isCommittedAsCustom = false,
    bool commitOnChange = false,
    bool allowAbsoluteToggle = true,
    int txSize = 140,
    int? previewFeeSat,
    bool previewLoading = false,
    void Function(NetworkFee fee)? onArm,
    VoidCallback? onDisarm,
    void Function(NetworkFee fee)? onPreview,
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
            onDisarm: onDisarm,
            onPreview: onPreview,
            onCommit: onCommit ?? (_) async {},
            allowAbsoluteToggle: allowAbsoluteToggle,
            commitOnChange: commitOnChange,
            previewFeeSat: previewFeeSat,
            previewLoading: previewLoading,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Material tileMaterial(WidgetTester tester) => tester.widget<Material>(
    find
        .descendant(of: find.byType(InkWell), matching: find.byType(Material))
        .first,
  );

  group('CustomFeeListItem — initial input', () {
    testWidgets(
      'input is empty when no fee has been committed yet',
      (tester) async {
        await pumpTile(tester);
        final field =
            tester.widget<TextFormField>(find.byType(TextFormField));
        expect(field.controller!.text, '');
      },
    );

    testWidgets(
      'input prefills with the committed relative fee on reopen',
      (tester) async {
        // Reopening the modal must show the previously-committed value
        // instead of an empty field — otherwise the user can't tell what
        // they last picked. Round-trip on common rates is exact (0.5 ↔
        // 125 sat/kwu).
        await pumpTile(
          tester,
          initialFee: NetworkFee.relativeFromSatPerVbyte(0.5),
        );
        final field =
            tester.widget<TextFormField>(find.byType(TextFormField));
        expect(field.controller!.text, '0.5');
      },
    );

    testWidgets(
      'input prefills with the committed absolute fee on reopen',
      (tester) async {
        await pumpTile(
          tester,
          initialFee: const NetworkFee.absolute(1234),
        );
        final field =
            tester.widget<TextFormField>(find.byType(TextFormField));
        expect(field.controller!.text, '1234');
      },
    );

    testWidgets(
      'trailing zeros are trimmed when prefilling a relative fee',
      (tester) async {
        // 1.0 sat/vB should render as "1", not "1.00" — matches what the
        // user would have typed.
        await pumpTile(
          tester,
          initialFee: NetworkFee.relativeFromSatPerVbyte(1.0),
        );
        final field =
            tester.widget<TextFormField>(find.byType(TextFormField));
        expect(field.controller!.text, '1');
      },
    );
  });

  group('CustomFeeListItem — keystroke dispatch', () {
    testWidgets(
      'modal mode arms synchronously and triggers onPreview after the '
      'debounce window',
      (tester) async {
        NetworkFee? armed;
        NetworkFee? previewed;
        await pumpTile(
          tester,
          onArm: (fee) => armed = fee,
          onPreview: (fee) => previewed = fee,
        );

        await tester.enterText(find.byType(TextFormField), '0.5');
        await tester.pump();
        expect(armed, isA<NetworkFee>(), reason: 'arm is synchronous');
        expect(previewed, isNull, reason: 'preview debounced');

        await tester.pump(const Duration(milliseconds: 400));
        expect(previewed, isA<NetworkFee>(), reason: 'debounce fired');
        expect(
          (previewed! as RelativeFee).satPerVbyte,
          closeTo(0.5, 0.003),
        );
      },
    );

    testWidgets(
      'RBF mode (commitOnChange=true) bypasses arm/preview and commits per '
      'keystroke',
      (tester) async {
        NetworkFee? armed;
        NetworkFee? previewed;
        NetworkFee? committed;
        await pumpTile(
          tester,
          commitOnChange: true,
          onArm: (fee) => armed = fee,
          onPreview: (fee) => previewed = fee,
          onCommit: (fee) async => committed = fee,
        );

        await tester.enterText(find.byType(TextFormField), '2.5');
        await tester.pump();

        expect(armed, isNull);
        expect(previewed, isNull);
        expect(committed, isA<NetworkFee>());
        expect(
          (committed! as RelativeFee).satPerVbyte,
          closeTo(2.5, 0.003),
        );
      },
    );

    testWidgets(
      'RBF mode does NOT commit a below-floor rate (BDK would build a '
      'PSBT no node would relay)',
      (tester) async {
        NetworkFee? committed;
        await pumpTile(
          tester,
          commitOnChange: true,
          onCommit: (fee) async => committed = fee,
        );
        // 0.05 sat/vByte < NetworkFeeRelayPolicy.minRelaySatPerVbyte.
        // The build-time banner ("Fee Rate Too Low") shows the user why
        // nothing's being committed; the modal-mode equivalent gate
        // lives in finalizeArmedCustomFee/_onCustomFeeFinalized.
        await tester.enterText(find.byType(TextFormField), '0.05');
        await tester.pump();
        expect(committed, isNull);
      },
    );

    testWidgets(
      'fast typing only previews once after the user pauses',
      (tester) async {
        var previewCount = 0;
        NetworkFee? lastPreviewed;
        await pumpTile(
          tester,
          onPreview: (fee) {
            previewCount++;
            lastPreviewed = fee;
          },
        );

        await tester.enterText(find.byType(TextFormField), '0.1');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(find.byType(TextFormField), '0.5');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(find.byType(TextFormField), '0.55');
        await tester.pump(const Duration(milliseconds: 400));

        expect(previewCount, 1);
        expect(
          (lastPreviewed! as RelativeFee).satPerVbyte,
          closeTo(0.55, 0.003),
        );
      },
    );

    testWidgets(
      'unmount before the debounce fires cancels the preview',
      (tester) async {
        var previewCount = 0;
        await pumpTile(tester, onPreview: (_) => previewCount++);

        await tester.enterText(find.byType(TextFormField), '1.0');
        await tester.pump(const Duration(milliseconds: 100));

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pump(const Duration(milliseconds: 400));

        expect(previewCount, 0);
      },
    );
  });

  group('CustomFeeListItem — preview line', () {
    testWidgets('renders shimmer while previewLoading is true', (
      tester,
    ) async {
      // pumpTile uses pumpAndSettle internally, which never returns once
      // a Shimmer is alive (perpetual animation). Mount with no initial
      // fee so the preview row isn't rendered yet, then type — that
      // mounts the shimmer once we're past pumpAndSettle.
      await pumpTile(tester, previewLoading: true);
      await tester.enterText(find.byType(TextFormField), '0.5');
      await tester.pump();
      expect(
        find.byType(LoadingLineContent),
        findsOneWidget,
        reason: 'shimmer placeholder while caller builds the unsigned PSBT',
      );
    });

    testWidgets(
      'renders the real fee verbatim when previewFeeSat is supplied',
      (tester) async {
        await pumpTile(tester, previewFeeSat: 29);
        await tester.enterText(find.byType(TextFormField), '0.132');
        await tester.pumpAndSettle();
        expect(find.textContaining('~ 29 sats'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'renders only the rate when no preview yet and not loading',
      (tester) async {
        // Pre-debounce state: user just typed, no preview has been built.
        // The widget never invents a sat count — only the rate is shown
        // (in the preview row's BBText). Match the rate unit string to
        // disambiguate from the TextFormField's EditableText also
        // containing "0.5".
        await pumpTile(tester);
        await tester.enterText(find.byType(TextFormField), '0.5');
        await tester.pump();

        expect(find.byType(LoadingLineContent), findsNothing);
        expect(find.textContaining(' ~ '), findsNothing,
            reason: 'no sat-count rendered');
        expect(find.textContaining('sats/vB'), findsAtLeastNWidgets(1),
            reason: 'rate suffix is shown');
      },
    );

    testWidgets('preview row hidden entirely when nothing typed', (
      tester,
    ) async {
      await pumpTile(tester);
      expect(find.byType(LoadingLineContent), findsNothing);
    });
  });

  group('CustomFeeListItem — focus drives highlight', () {
    testWidgets('tile starts dim when not committed and field unfocused', (
      tester,
    ) async {
      await pumpTile(tester);
      expect(tileMaterial(tester).elevation, 1.0);
    });

    testWidgets('focusing the field raises elevation', (tester) async {
      await pumpTile(tester);
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(tileMaterial(tester).elevation, 4.0);
    });

    testWidgets(
      'didUpdateWidget drops focus when isCommittedAsCustom goes true → false',
      (tester) async {
        // Regression guard for the double-selection bug: when the parent
        // moves the selection off custom, the widget must release focus
        // or two tiles appear active simultaneously.
        await pumpTile(tester, isCommittedAsCustom: true);
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();
        expect(tileMaterial(tester).elevation, 4.0);

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
        expect(tileMaterial(tester).elevation, 1.0);
      },
    );
  });

  group('CustomFeeListItem — no Confirm button anywhere', () {
    testWidgets('modal mode has no Confirm button', (tester) async {
      await pumpTile(tester);
      expect(find.textContaining('Confirm'), findsNothing);
    });
    testWidgets('RBF mode has no Confirm button either', (tester) async {
      await pumpTile(tester, commitOnChange: true);
      expect(find.textContaining('Confirm'), findsNothing);
    });
  });

  group('CustomFeeListItem — sub-0.1 sat/vByte floor', () {
    testWidgets('shows the below-floor error text', (tester) async {
      await pumpTile(tester);
      await tester.enterText(find.byType(TextFormField), '0.05');
      await tester.pumpAndSettle();
      expect(find.textContaining('0.1 sat'), findsOneWidget);
    });
  });

  group('CustomFeeListItem — keyboard dismissal', () {
    testWidgets('Enter / Done pops the modal in modal mode', (tester) async {
      late BuildContext routeContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) {
              routeContext = ctx;
              return Scaffold(
                body: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: ctx,
                    builder: (_) => CustomFeeListItem(
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
                    ),
                  ),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '1.0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNothing);
      // Avoid unused-warning on routeContext (used to keep the route
      // alive in scope).
      expect(routeContext.mounted, isTrue);
    });

    testWidgets('Enter / Done does NOT pop the parent in RBF mode', (
      tester,
    ) async {
      await pumpTile(tester, commitOnChange: true);
      await tester.enterText(find.byType(TextFormField), '1.0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });

  group('CustomFeeListItem — disarm on clear (modal mode)', () {
    testWidgets('flipping the abs/rel toggle disarms the parent', (
      tester,
    ) async {
      var armCount = 0;
      var disarmCount = 0;
      await pumpTile(
        tester,
        onArm: (_) => armCount++,
        onDisarm: () => disarmCount++,
      );
      // Type a value → arms the parent.
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.pump();
      expect(armCount, greaterThan(0));
      expect(disarmCount, 0);

      // Flip the absolute/relative toggle → field resets to empty, so the
      // parent must be disarmed (otherwise the stale "2" would commit on
      // dismissal despite an empty field).
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(disarmCount, 1);
    });

    testWidgets('clearing the field disarms the parent', (tester) async {
      var disarmCount = 0;
      await pumpTile(
        tester,
        onArm: (_) {},
        onDisarm: () => disarmCount++,
      );
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.pump();
      expect(disarmCount, 0);

      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
      expect(disarmCount, 1);
    });

    testWidgets('RBF mode (commitOnChange) never disarms', (tester) async {
      var disarmCount = 0;
      await pumpTile(
        tester,
        commitOnChange: true,
        allowAbsoluteToggle: false,
        onDisarm: () => disarmCount++,
      );
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
      expect(disarmCount, 0);
    });
  });
}
