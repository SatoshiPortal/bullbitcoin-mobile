import 'package:test/test.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

import 'support/fakes.dart';

/// Golden fingerprint for [goldenTransaction] published through the facade.
/// Byte-level contract: any change to the canonical encoding is a breaking
/// change of the receipt/reconstruction contract and must be intentional.
const goldenFingerprint =
    '6297aea455c4e909dd5ed38c2fcba50234febcc5e832b73a97bbdbca6e8007e5';

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
}
