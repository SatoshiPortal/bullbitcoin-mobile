import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import '../support/fake_ark_client.dart';

void main() {
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'test-server',
  );
  test(
    'frozen fake implements real client and unknown state protects custody',
    () async {
      final snapshot = ArkSnapshot(
        account: account,
        revision: 0,
        observedAt: DateTime.utc(2026, 11, 16),
      );
      final fake = FakeArkClient()..snapshot = Ok(snapshot);
      expect(
        await fake.read(account),
        isA<Ok<ArkSnapshot, ArkWalletFailure>>(),
      );
      expect(snapshot.spendable, isNull);
      expect(snapshot.tipHeight, isNull);
      expect(snapshot.hasFundsOrObligations, isTrue);
    },
  );
  test('only complete fresh zero observations can be unfunded', () {
    final snapshot = ArkSnapshot(
      account: account,
      revision: 1,
      observedAt: DateTime.utc(2026, 11, 16),
      stale: false,
      vtxoCompleteness: ArkSectionCompleteness.complete,
      spendable: Sats.zero,
      pending: Sats.zero,
      confirmedReserve: Sats.zero,
      recovery: ArkRecoveryStatus.complete,
      exits: ArkExitStatus.none,
      obligations: ArkObligationStatus.none,
      pendingBoardCount: 0,
      pendingLightningCount: 0,
      pendingRoundCount: 0,
    );
    expect(snapshot.hasFundsOrObligations, isFalse);
  });
  test('renewal threshold is strict and pending rounds remain excluded', () {
    ArkVtxo vtxo({bool pending = false}) => ArkVtxo(
      id: 'vtxo',
      amount: Sats.fromInt(1000),
      expiryHeight: 2000,
      state: ArkVtxoState.spendable,
      pendingRound: pending,
    );
    expect(vtxo().renewalDueAt(992, 1008), isFalse);
    expect(vtxo().renewalDueAt(993, 1008), isTrue);
    expect(vtxo(pending: true).renewalDueAt(993, 1008), isFalse);
    expect(vtxo().renewalDueAt(2000, 1008), isFalse);
  });
  test('explicit selections reject empty and duplicate ids', () {
    expect(() => ArkQuoteRequest.renewal(ids: []), throwsArgumentError);
    expect(() => ArkQuoteRequest.renewal(ids: ['a', 'a']), throwsArgumentError);
    expect(
      () => ArkQuoteRequest.claim(
        ids: [],
        destination: 'dest',
        maxFee: Sats.fromInt(100),
      ),
      throwsArgumentError,
    );
  });
  test('account identity does not alias separator-bearing server names', () {
    expect(account.canonical, contains('11:test-server'));
    expect(
      () => ArkAccountConfig(
        id: account,
        arkUrl: Uri.parse('http://user:password@localhost'),
        primaryEsploraUrl: Uri.parse('http://localhost'),
      ),
      throwsArgumentError,
    );
  });
  test('pure paste classifier checks HRP, version, checksum and network', () {
    // Public address vector from bark's address codec tests; no key material.
    const address =
        'ark1pwh9vsmezqqpharv69q4z8m6x364d5m5prnmcalcalq9pdmzw0y7mpveck4pcfhezqypczkrrj3lkx5ue4qrf4jc7ztpt9htdttmh2judhqnu7aue8p0y9mqkr4cf5';
    expect(isArkAddress(address, network: BitcoinNetwork.mainnet), isTrue);
    expect(
      isArkAddress(address.toUpperCase(), network: BitcoinNetwork.mainnet),
      isTrue,
    );
    expect(isArkAddress(address, network: BitcoinNetwork.regtest), isFalse);
    expect(
      isArkAddress(
        '${address.substring(0, address.length - 1)}q',
        network: BitcoinNetwork.mainnet,
      ),
      isFalse,
    );
    expect(isArkAddress(' $address', network: BitcoinNetwork.mainnet), isFalse);
    expect(
      isArkAddress('bitcoin:bc1qexample', network: BitcoinNetwork.mainnet),
      isFalse,
    );
  });
  test(
    'scripted client captures the exact account and reviewed recovery command',
    () async {
      final command = ArkSubmission.rebroadcastClaim(
        operationId: 'original',
        expectedTxid: 'a' * 64,
      );
      final fake = FakeArkClient()
        ..submitted = Ok(
          ArkOperation(
            id: 'original',
            kind: ArkOperationKind.claim,
            status: ArkOperationStatus.pending,
            chainSource: Uri.parse('http://localhost'),
            configGeneration: 1,
            claimRecovery: ArkClaimRecovery(
              txid: 'a' * 64,
              destination: 'destination',
              net: Sats.fromInt(900),
              fee: Sats.fromInt(100),
            ),
          ),
        );
      await fake.submit(account, command);
      expect(fake.arguments.single, (account, command));
      expect(command, isA<ArkRebroadcastClaim>());
      expect(
        () => ArkSubmission.rebroadcastClaim(
          operationId: 'original',
          expectedTxid: 'bad',
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'unknown or incomplete inventory remains a protective obligation at zero',
    () {
      for (final completeness in [
        ArkSectionCompleteness.unknown,
        ArkSectionCompleteness.incomplete,
      ]) {
        final snapshot = ArkSnapshot(
          account: account,
          revision: 1,
          observedAt: DateTime.utc(2026),
          stale: false,
          spendable: Sats.zero,
          pending: Sats.zero,
          confirmedReserve: Sats.zero,
          recovery: ArkRecoveryStatus.complete,
          exits: ArkExitStatus.none,
          obligations: ArkObligationStatus.none,
          pendingBoardCount: 0,
          pendingLightningCount: 0,
          pendingRoundCount: 0,
          vtxoCompleteness: completeness,
        );
        expect(snapshot.hasFundsOrObligations, isTrue);
      }
    },
  );
  test('movement evidence copies and freezes caller-owned id lists', () {
    final inputs = ['original'];
    final outputs = ['replacement'];
    final movement = ArkMovement(
      id: 'm',
      kind: ArkMovementKind.renewal,
      status: ArkMovementStatus.successful,
      inputVtxoIds: inputs,
      outputVtxoIds: outputs,
    );
    inputs.clear();
    outputs.clear();
    expect(movement.inputVtxoIds, ['original']);
    expect(movement.outputVtxoIds, ['replacement']);
    expect(() => movement.inputVtxoIds.add('tamper'), throwsUnsupportedError);
  });
}
