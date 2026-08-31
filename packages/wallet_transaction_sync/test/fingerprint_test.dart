import 'package:test/test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

import 'support/fakes.dart';

/// Golden fingerprint for [goldenTransaction] published through the facade.
/// Byte-level contract: any change to the canonical encoding is a breaking
/// change of the receipt/reconstruction contract and must be intentional.
const goldenFingerprint =
    '55bc5dd6808a596d4e71df7d16411919a3ee4ee0231ca6434969c019f48c3327';

WalletTransaction goldenTransaction() => WalletTransaction(
  txid: 'aa11',
  amountSats: 1500,
  feeSats: 120,
  inputs: const [TransactionInput(txid: 'ff00', vout: 1)],
  outputs: const [TransactionOutput(valueSats: 1380, script: '0014ab')],
  position: AnchoredPosition('000000hash', 4321, DateTime.utc(2026, 1, 2, 3)),
  evidence: const {'source': 'fake'},
  details: const {
    'memo': 'golden',
    'nested': {'depth': 1},
  },
);

Future<String> publishedFingerprint(
  List<WalletTransaction> transactions,
) async {
  final source = RecordingSource()
    ..observationBuilder = (registration) => WalletSourceObservation(
      key: registration.key,
      registration: registration,
      transactions: transactions,
    );
  final facade = buildFacade(source, RecordingMetadata());
  final result = await facade.refreshLocalSnapshot(
    const RefreshLocalSnapshotRequest(testRegistration),
  );
  return okValue(result).snapshot.contentFingerprint;
}

void main() {
  test('golden fingerprint vector is stable byte for byte', () async {
    expect(
      await publishedFingerprint([goldenTransaction()]),
      goldenFingerprint,
    );
  });

  test('identical re-observation reproduces the same fingerprint', () async {
    final first = await publishedFingerprint([goldenTransaction()]);
    final second = await publishedFingerprint([goldenTransaction()]);
    expect(second, first);
  });

  test('every position field change produces a distinct fingerprint', () async {
    final base = goldenTransaction();
    WalletTransaction withPosition(TransactionPosition position) =>
        WalletTransaction(
          txid: base.txid,
          amountSats: base.amountSats,
          feeSats: base.feeSats,
          inputs: base.inputs,
          outputs: base.outputs,
          position: position,
          evidence: base.evidence,
          details: base.details,
        );

    final variants = <List<WalletTransaction>>[
      [base],
      [
        withPosition(
          AnchoredPosition('other', 4321, DateTime.utc(2026, 1, 2, 3)),
        ),
      ],
      [
        withPosition(
          AnchoredPosition('000000hash', 9999, DateTime.utc(2026, 1, 2, 3)),
        ),
      ],
      [withPosition(AnchoredPosition('000000hash', 4321, DateTime.utc(2027)))],
      [withPosition(SourceReportedConfirmedPosition(4321, DateTime.utc(2026)))],
      [
        withPosition(
          UnconfirmedPosition(DateTime.utc(2026), DateTime.utc(2026, 2)),
        ),
      ],
      [
        withPosition(
          UnconfirmedPosition(DateTime.utc(2026), DateTime.utc(2026, 3)),
        ),
      ],
      [withPosition(const ConflictedPosition('bb22'))],
      [withPosition(const ConflictedPosition('cc33'))],
      [withPosition(EvictedPosition(DateTime.utc(2026, 4)))],
      [withPosition(const UnknownPosition())],
    ];
    final fingerprints = <String>{
      for (final variant in variants) await publishedFingerprint(variant),
    };
    expect(fingerprints, hasLength(variants.length));
  });

  test(
    'identical re-observation keeps the revision while a position change bumps it',
    () async {
      final source = RecordingSource()
        ..observationBuilder = (registration) => WalletSourceObservation(
          key: registration.key,
          registration: registration,
          transactions: [goldenTransaction()],
        );
      final facade = buildFacade(source, RecordingMetadata());
      final first = okValue(
        await facade.synchronizeWallet(
          const SynchronizeWalletRequest(testRegistration),
        ),
      );
      expect(first.snapshot.revision, 1);

      final second = okValue(
        await facade.synchronizeWallet(
          const SynchronizeWalletRequest(testRegistration),
        ),
      );
      expect(second.snapshot.revision, 1);
      expect(
        second.snapshot.contentFingerprint,
        first.snapshot.contentFingerprint,
      );

      source.observationBuilder = (registration) => WalletSourceObservation(
        key: registration.key,
        registration: registration,
        transactions: [
          WalletTransaction(
            txid: 'aa11',
            amountSats: 1500,
            feeSats: 120,
            inputs: const [TransactionInput(txid: 'ff00', vout: 1)],
            outputs: const [
              TransactionOutput(valueSats: 1380, script: '0014ab'),
            ],
            position: const ConflictedPosition('dd44'),
            evidence: const {'source': 'fake'},
            details: const {
              'memo': 'golden',
              'nested': {'depth': 1},
            },
          ),
        ],
      );
      final third = okValue(
        await facade.synchronizeWallet(
          const SynchronizeWalletRequest(testRegistration),
        ),
      );
      expect(third.snapshot.revision, 2);
      expect(
        third.snapshot.contentFingerprint,
        isNot(first.snapshot.contentFingerprint),
      );
    },
  );

  test('map key order does not change the fingerprint', () async {
    WalletTransaction withDetails(Map<String, Object?> details) =>
        WalletTransaction(
          txid: 'aa11',
          amountSats: 1,
          position: const UnknownPosition(),
          details: details,
        );
    final ordered = await publishedFingerprint([
      withDetails(const {'a': 1, 'b': 2}),
    ]);
    final reversed = await publishedFingerprint([
      withDetails(const {'b': 2, 'a': 1}),
    ]);
    expect(reversed, ordered);
  });

  test('every Liquid projection field changes the fingerprint', () async {
    TransactionInput input({
      int originalIndex = 1,
      int value = 100,
      String assetId = 'asset',
      String script = '0014input',
      String standardAddress = 'standard-input',
      String confidentialAddress = 'confidential-input',
      int height = 10,
      bool isSpent = false,
      TransactionChain chain = TransactionChain.external,
    }) => TransactionInput(
      txid: 'previous',
      vout: 2,
      originalIndex: originalIndex,
      value: value,
      assetId: assetId,
      script: script,
      standardAddress: standardAddress,
      confidentialAddress: confidentialAddress,
      height: height,
      isSpent: isSpent,
      chain: chain,
    );
    TransactionOutput output({
      String txid = 'liquid',
      int vout = 2,
      int originalIndex = 2,
      String assetId = 'asset',
      String standardAddress = 'standard-output',
      String confidentialAddress = 'confidential-output',
      int height = 11,
      bool isSpent = false,
      TransactionChain chain = TransactionChain.external,
    }) => TransactionOutput(
      valueSats: 90,
      txid: txid,
      vout: vout,
      script: '0014output',
      originalIndex: originalIndex,
      assetId: assetId,
      standardAddress: standardAddress,
      confidentialAddress: confidentialAddress,
      height: height,
      isSpent: isSpent,
      chain: chain,
    );
    WalletTransaction transaction({
      TransactionInput? mappedInput,
      TransactionOutput? mappedOutput,
      int inputCount = 3,
      int outputCount = 4,
      TransactionDirection direction = TransactionDirection.outgoing,
      bool selfTransfer = false,
      int vsize = 123,
    }) => WalletTransaction(
      txid: 'liquid',
      amountSats: 10,
      feeSats: 1,
      inputs: [mappedInput ?? input()],
      outputs: [mappedOutput ?? output()],
      inputCount: inputCount,
      outputCount: outputCount,
      direction: direction,
      selfTransfer: selfTransfer,
      vsize: vsize,
      position: const UnknownPosition(),
    );

    final variants = [
      transaction(),
      transaction(inputCount: 4),
      transaction(outputCount: 5),
      transaction(direction: TransactionDirection.incoming),
      transaction(selfTransfer: true),
      transaction(vsize: 124),
      transaction(mappedInput: input(originalIndex: 2)),
      transaction(mappedInput: input(value: 101)),
      transaction(mappedInput: input(assetId: 'other')),
      transaction(mappedInput: input(script: 'other')),
      transaction(mappedInput: input(standardAddress: 'other')),
      transaction(mappedInput: input(confidentialAddress: 'other')),
      transaction(mappedInput: input(height: 12)),
      transaction(mappedInput: input(isSpent: true)),
      transaction(mappedInput: input(chain: TransactionChain.internal)),
      transaction(mappedOutput: output(originalIndex: 3)),
      transaction(mappedOutput: output(txid: 'other')),
      transaction(mappedOutput: output(vout: 3)),
      transaction(mappedOutput: output(assetId: 'other')),
      transaction(mappedOutput: output(standardAddress: 'other')),
      transaction(mappedOutput: output(confidentialAddress: 'other')),
      transaction(mappedOutput: output(height: 12)),
      transaction(mappedOutput: output(isSpent: true)),
      transaction(mappedOutput: output(chain: TransactionChain.internal)),
    ];
    final fingerprints = <String>{
      for (final variant in variants) await publishedFingerprint([variant]),
    };

    expect(fingerprints, hasLength(variants.length));
  });
}
