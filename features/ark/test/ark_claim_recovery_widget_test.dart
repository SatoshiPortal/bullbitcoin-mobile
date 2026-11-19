import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/ark_ui.dart';
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/usecases/review_ark_claim_recovery_usecase.dart';
import 'package:bull_ark/src/domain/usecases/rebroadcast_ark_claim_usecase.dart';
import 'package:bull_ark/src/presentation/ark_claim_recovery_cubit.dart';
import 'package:bull_ark/src/ui/ark_claim_recovery_screen.dart';
import 'package:bull_ui/testing.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDetailsTable, BullDetailsTableItem;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import 'ark_claim_recovery_test.dart' show saved, journal, txid;
import 'ark_operations_test.dart' show account;
import 'fake_ark_client.dart';

class Client extends FakeArkClient {
  final pending = Completer<Result<ArkOperation, ArkWalletFailure>>();
  final commands = <ArkSubmission>[];
  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) {
    calls.add('submit');
    commands.add(submission);
    return pending.future;
  }
}

class DelayedReadClient extends Client {
  final firstRead = Completer<Result<ArkSnapshot, ArkWalletFailure>>();
  bool _first = true;
  @override
  Future<Result<ArkSnapshot, ArkWalletFailure>> read(ArkAccountId account) {
    if (!_first) return super.read(account);
    _first = false;
    calls.add('read');
    arguments.add(account);
    return firstRead.future;
  }
}

ArkClaimRecoveryCubit controller(Client client) {
  final repository = ArkRepositoryImpl(client);
  return ArkClaimRecoveryCubit(
    ReviewArkClaimRecoveryUsecase(repository),
    RebroadcastArkClaimUsecase(repository),
    account: account(),
    operationId: 'original-claim',
  );
}

Widget app(ArkClaimRecoveryCubit cubit) => MaterialApp(
  theme: ThemeData(extensions: testBullExtensions),
  home: ArkClaimRecoveryScreen(cubit: cubit),
);
void main() {
  testWidgets('opening displays saved fee and destination without submitting', (
    tester,
  ) async {
    final client = Client()..snapshot = Ok(journal());
    final cubit = controller(client);
    await tester.pumpWidget(app(cubit));
    await tester.pumpAndSettle();
    expect(find.text(txid), findsOneWidget);
    expect(find.text('saved-public-destination'), findsOneWidget);
    expect(find.text('900'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('Net amount (sats)'), findsOneWidget);
    expect(find.text('Fee (sats)'), findsOneWidget);
    final rows = tester
        .widget<BullDetailsTable>(find.byType(BullDetailsTable))
        .items
        .whereType<BullDetailsTableItem>();
    expect(
      rows.singleWhere((row) => row.label == 'Net amount (sats)').displayValue,
      '900',
    );
    expect(
      rows.singleWhere((row) => row.label == 'Fee (sats)').displayValue,
      '100',
    );
    expect(client.calls, ['read']);
    await tester.pumpWidget(app(cubit));
    await tester.pumpAndSettle();
    expect(client.calls, ['read']);
    await cubit.close();
  });
  testWidgets(
    'double confirmation and lost response never automatically resubmit',
    (tester) async {
      final client = Client()..snapshot = Ok(journal());
      final cubit = controller(client);
      await tester.pumpWidget(app(cubit));
      await tester.pumpAndSettle();
      final confirm = find.text('Resubmit this signed claim');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await cubit.confirm();
      await cubit.load();
      expect(client.commands, hasLength(1));
      expect(client.calls, ['read', 'submit']);
      expect(
        client.commands.single,
        isA<ArkRebroadcastClaim>()
            .having((s) => s.operationId, 'same operation', 'original-claim')
            .having((s) => s.expectedTxid, 'same signed transaction', txid),
      );
      client.pending.complete(
        const Err(ArkOutcomeUnknownFailure('original-claim')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Resubmit this signed claim'), findsNothing);
      expect(client.calls, ['read', 'submit']);
      final refresh = find.text('Refresh');
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(client.calls, ['read', 'submit', 'read']);
      expect(client.commands, hasLength(1));
      expect(find.text('Resubmit this signed claim'), findsOneWidget);
      await cubit.close();
    },
  );
  testWidgets(
    'positive conflict is attention with no automatic recovery action',
    (tester) async {
      final client = Client()..snapshot = Ok(journal());
      final cubit = controller(client);
      await tester.pumpWidget(app(cubit));
      await tester.pumpAndSettle();
      final confirm = find.text('Resubmit this signed claim');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      client.pending.complete(Ok(saved(status: ArkOperationStatus.conflicted)));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'A conflicting transaction was observed. This saved claim cannot be resubmitted.',
        ),
        findsOneWidget,
      );
      expect(find.text('Resubmit this signed claim'), findsNothing);
      expect(client.commands, hasLength(1));
      await cubit.close();
    },
  );
  testWidgets('missing saved evidence never renders a send control', (
    tester,
  ) async {
    final client = Client()
      ..snapshot = Ok(journal(operations: [saved(summary: false)]));
    final cubit = controller(client);
    await tester.pumpWidget(app(cubit));
    await tester.pumpAndSettle();
    expect(find.text('Resubmit this signed claim'), findsNothing);
    expect(client.calls, ['read']);
    await cubit.close();
  });
  testWidgets(
    'published route selector reads saved identity and keeps client host-owned',
    (tester) async {
      final client = Client()..snapshot = Ok(journal());
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => ArkNavigation.reviewClaimRecovery(
                  context,
                  account(),
                  'original-claim',
                ),
                child: const Text('Review saved claim'),
              ),
            ),
          ),
          ...createArkClaimRecoveryRoutes(client: client),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData(extensions: testBullExtensions),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review saved claim'));
      await tester.pumpAndSettle();
      expect(find.text(txid), findsOneWidget);
      expect(client.calls, ['read']);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      expect(client.calls, ['read']);
    },
  );
  testWidgets(
    'route account and client replacement retire old controllers and reload identity',
    (tester) async {
      final first = DelayedReadClient()..snapshot = Ok(journal());
      final other = ArkAccountId(
        parent: account().parent,
        network: BitcoinNetwork.regtest,
        serverIdentity: 'other-public-server',
      );
      ArkOperation replacement(String destination, String byte) => ArkOperation(
        id: 'original-claim',
        kind: ArkOperationKind.claim,
        status: ArkOperationStatus.outcomeUnknown,
        chainSource: Uri.parse('https://captured-chain.example'),
        configGeneration: 3,
        claimRecovery: ArkClaimRecovery(
          txid: List.filled(32, byte).join(),
          destination: destination,
          net: Sats.fromInt(800),
          fee: Sats.fromInt(200),
        ),
      );
      final second = Client()
        ..snapshot = Ok(
          journal(
            id: other,
            operations: [replacement('second-client-destination', '66')],
          ),
        );
      final home = GoRoute(
        path: '/',
        builder: (context, state) => const SizedBox.shrink(),
      );
      final configuration = ValueNotifier(
        RoutingConfig(
          routes: [
            home,
            ...createArkClaimRecoveryRoutes(client: first),
          ],
        ),
      );
      final router = GoRouter.routingConfig(routingConfig: configuration);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData(extensions: testBullExtensions),
          routerConfig: router,
        ),
      );
      router.go(
        '/ark/claim-recovery',
        extra: ArkClaimRecoveryEntry(account(), 'original-claim'),
      );
      await tester.pumpAndSettle();
      final originalController = tester
          .widget<ArkClaimRecoveryScreen>(find.byType(ArkClaimRecoveryScreen))
          .cubit;
      first.snapshot = Ok(
        journal(
          id: other,
          operations: [replacement('other-account-destination', '24')],
        ),
      );
      router.go(
        '/ark/claim-recovery',
        extra: ArkClaimRecoveryEntry(other, 'original-claim'),
      );
      await tester.pumpAndSettle();
      expect(originalController.isClosed, true);
      expect(first.arguments, [account(), other]);
      expect(find.text('saved-public-destination'), findsNothing);
      expect(find.text('other-account-destination'), findsOneWidget);
      first.firstRead.complete(Ok(journal()));
      await tester.pumpAndSettle();
      expect(find.text('saved-public-destination'), findsNothing);
      expect(find.text('other-account-destination'), findsOneWidget);
      final accountController = tester
          .widget<ArkClaimRecoveryScreen>(find.byType(ArkClaimRecoveryScreen))
          .cubit;
      configuration.value = RoutingConfig(
        routes: [
          home,
          ...createArkClaimRecoveryRoutes(client: second),
        ],
      );
      await tester.pumpAndSettle();
      expect(accountController.isClosed, true);
      expect(second.arguments, [other]);
      expect(find.text('other-account-destination'), findsNothing);
      expect(find.text('second-client-destination'), findsOneWidget);
      expect(first.calls, ['read', 'read']);
      expect(second.calls, ['read']);
      expect(first.commands, isEmpty);
      expect(second.commands, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      configuration.dispose();
      expect(first.calls, ['read', 'read']);
      expect(second.calls, ['read']);
    },
  );
}
