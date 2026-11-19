import 'package:ark/ark.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/ark_ui.dart';
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ark/src/ui/ark_board_screen.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart';

import 'ark_board_journey_test.dart' show prepared;
import 'ark_module_composition_test.dart' show Rig, Registry;
import 'ark_operations_test.dart' show account, Provisioner;
import 'ark_settings_flow_test.dart' show config;

class _Funding implements ArkTransferBoardFundingPort {
  final selectedSources = <String>[];
  bool preAdmission;
  ArkBoardPreparation? reviewed;
  final requests = <(ArkAccountConfig, Sats, String)>[];
  int reads = 0;
  _Funding({required this.preAdmission});

  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> prepareFrom(
    ArkAccountConfig config,
    Sats amount, {
    required String sourceWalletId,
  }) async {
    selectedSources.add(sourceWalletId);
    requests.add((config, amount, sourceWalletId));
    final ready = reviewed;
    if (ready != null) return Ok(ready);
    return preAdmission
        ? const Err(ArkInvalidRequestFailure())
        : const Err(ArkSubmissionUncertainFailure('operation'));
  }

  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> prepare(
    ArkAccountConfig config,
    Sats amount,
  ) => throw StateError('Expected explicit source');

  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> readPrepared(
    ArkAccountId account,
    String operationId,
  ) async {
    reads++;
    final ready = reviewed;
    if (ready == null) throw StateError('Unexpected saved review');
    return Ok(ready);
  }

  @override
  Future<Result<ArkOperation, ArkFailure>> confirm(
    ArkAccountId account,
    String operationId,
    String reviewBinding,
  ) => throw StateError('Unexpected signature');
}

class _Source implements ArkBoardSourcePort {
  final value = ArkDisplayData(
    account: account(),
    walletId: 'source-A',
    available: Sats.fromInt(100000),
  );
  int scans = 0;
  @override
  Stream<void> changes(ArkAccountId account) => const Stream.empty();
  @override
  bool accepts(ArkDisplayData observation) => identical(value, observation);
  @override
  Future<Result<ArkDisplayData, ArkFailure>> read(ArkAccountId account) async =>
      Ok(value);
  @override
  Future<Result<ArkDisplayData, ArkFailure>> refresh(
    ArkAccountId account,
  ) async {
    scans++;
    return Ok(value);
  }
}

class _Passive implements ArkDisplayDataPort {
  final ArkDisplayData value;
  _Passive(this.value);
  @override
  Stream<void> changes(ArkAccountId account) => const Stream.empty();
  @override
  Future<Result<ArkDisplayData, ArkFailure>> read(ArkAccountId account) async =>
      Ok(value);
}

void main() {
  for (final transfer in [false, true]) {
    testWidgets('Board source entry and retired actions transfer=$transfer', (
      tester,
    ) async {
      final rig = Rig();
      final source = _Source();
      final funding = _Funding(preAdmission: !transfer);
      final selectedSources = funding.selectedSources;
      final feature = ArkFeature(
        rig.selection,
        config: config(),
        client: rig.client,
        preferences: rig.preferences,
        provisioning: Provisioner(),
        registry: Registry(),
        boardFunding: funding,
        boardSource: source,
      );
      rig.routing.value = RoutingConfig(routes: rig.routes(feature));
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      if (transfer) {
        rig.router.go(
          '/ark/board',
          extra: ArkTransferBoardEntry(
            account: account(),
            sourceWalletId: 'source-A',
            amount: Sats.fromInt(20000),
          ),
        );
        await tester.pumpAndSettle();
        expect(selectedSources, ['source-A']);
        expect(source.scans, 0);
      } else {
        await tester.tap(find.text('Board to Ark'));
        await tester.pumpAndSettle();
        expect(source.scans, 1);
        final amount = tester.widget<ArkBoardAmountScreen>(
          find.byType(ArkBoardAmountScreen),
        );
        final oldRefresh = amount.onRefreshSource;
        final oldReview = amount.onReviewRequest;
        if (oldRefresh == null || oldReview == null) {
          throw StateError('Expected live source actions');
        }
        // Even if the host's default moves to B without a display event, the
        // prepared command remains explicitly pinned to the rendered source A.
        oldReview(amount.config, Sats.fromInt(20000));
        await tester.pumpAndSettle();
        expect(selectedSources, ['source-A']);
        oldRefresh();
        oldReview(amount.config, Sats.fromInt(20000));
        await tester.pumpAndSettle();
        expect(source.scans, 1);
        expect(selectedSources, ['source-A']);
        final editing = tester.widget<ArkBoardAmountScreen>(
          find.byType(ArkBoardAmountScreen),
        );
        final refresh = editing.onRefreshSource;
        if (refresh == null) {
          throw StateError('Expected renewed editing Refresh');
        }
        refresh();
        await tester.pumpAndSettle();
        expect(source.scans, 2);
        funding.preAdmission = false;
        final current = tester.widget<ArkBoardAmountScreen>(
          find.byType(ArkBoardAmountScreen),
        );
        final review = current.onReviewRequest;
        if (review == null) throw StateError('Expected renewed editing Review');
        review(current.config, Sats.fromInt(20000));
        await tester.pumpAndSettle();
        expect(selectedSources, ['source-A', 'source-A']);
        refresh();
        await tester.pumpAndSettle();
        expect(
          source.scans,
          2,
          reason: 'A retired pending callback cannot scan',
        );
      }
      feature.invalidate();
    });
  }
  testWidgets(
    'Transfer keeps passive fiat and never installs ordinary source actions',
    (tester) async {
      final rig = Rig();
      final source = _Source();
      final passive = _Passive(
        ArkDisplayData(
          account: account(),
          walletId: 'source-wallet',
          available: Sats.fromInt(100000),
          price: BitcoinPrice(
            currency: SupportedCurrency.cad,
            fiatAmount: 100000,
            fetchedAt: DateTime.utc(2026, 11, 17),
          ),
        ),
      );
      final funding = _Funding(preAdmission: false)..reviewed = prepared();
      final accountConfig = config();
      final feature = ArkFeature(
        rig.selection,
        config: accountConfig,
        client: rig.client,
        preferences: rig.preferences,
        provisioning: Provisioner(),
        registry: Registry(),
        boardFunding: funding,
        displayData: passive,
        boardSource: source,
      );
      rig.routing.value = RoutingConfig(routes: rig.routes(feature));
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      rig.router.go(
        '/ark/board',
        extra: ArkTransferBoardEntry(
          account: account(),
          sourceWalletId: 'source-wallet',
          amount: Sats.fromInt(1000),
        ),
      );
      await tester.pumpAndSettle();
      expect(funding.requests, [
        (accountConfig, Sats.fromInt(1000), 'source-wallet'),
      ]);
      expect(funding.reads, 1);
      expect(source.scans, 0);
      expect(find.text('1.00 CAD'), findsOneWidget);
      final screen = tester.widget<ArkBoardScreen>(find.byType(ArkBoardScreen));
      expect(screen.displayData, same(passive.value));
      expect(screen.onSourceEntry, isNull);
      expect(screen.onRefreshSource, isNull);
      expect(screen.sourceReady, isNull);
      feature.invalidate();
    },
  );
  testWidgets('an optional legacy host still prepares without prepareFrom', (
    tester,
  ) async {
    final rig = Rig();
    final passive = _Passive(
      ArkDisplayData(
        account: account(),
        walletId: 'legacy-source-A',
        available: Sats.fromInt(100000),
      ),
    );
    final feature = ArkFeature(
      rig.selection,
      config: config(),
      client: rig.client,
      preferences: rig.preferences,
      provisioning: Provisioner(),
      registry: Registry(),
      boardFunding: rig.boardFunding,
      displayData: passive,
    );
    rig.routing.value = RoutingConfig(routes: rig.routes(feature));
    await tester.pumpWidget(rig.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Board to Ark'));
    await tester.pumpAndSettle();
    final amount = tester.widget<ArkBoardAmountScreen>(
      find.byType(ArkBoardAmountScreen),
    );
    expect(amount.displayData?.walletId, 'legacy-source-A');
    final review = amount.onReviewRequest;
    if (review == null) throw StateError('Expected legacy Review');
    review(amount.config, Sats.fromInt(20000));
    await tester.pumpAndSettle();
    expect(rig.boardFunding.calls, ['prepare']);
  });
}
