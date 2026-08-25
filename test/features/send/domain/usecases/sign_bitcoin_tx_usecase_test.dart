import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/sign_bitcoin_tx_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBitcoinSigningPort implements BitcoinSigningPort {
  final ({String psbt, bool isFinalized}) signingResult;
  int signCalls = 0;
  int combineCalls = 0;

  _FakeBitcoinSigningPort(this.signingResult);

  @override
  Future<Result<({String psbt, bool isFinalized}), BitcoinSigningFailure>>
  combinePsbts({
    required String currentPsbt,
    required String signedPsbt,
    required String walletId,
    bool tryFinalize = true,
  }) async {
    combineCalls++;
    return Ok(signingResult);
  }

  @override
  Future<Result<({String psbt, bool isFinalized}), BitcoinSigningFailure>>
  finalizePsbt(String psbt) => throw UnimplementedError();

  @override
  Future<Result<BitcoinWalletPolicy, BitcoinSigningFailure>> getPolicy({
    required String walletId,
  }) => throw UnimplementedError();

  @override
  Future<Result<BitcoinPolicyMaturity, BitcoinSigningFailure>>
  getPolicyMaturity({
    required String walletId,
    required bool includeTimeBasedLocks,
  }) => throw UnimplementedError();

  @override
  Future<Result<BitcoinPsbtReview, BitcoinSigningFailure>> reviewPsbt(
    String psbt, {
    required String walletId,
    bool requireLocalOrigin = true,
  }) => throw UnimplementedError();

  @override
  Future<int> getTxSize({
    required String psbt,
    required String walletId,
  }) async => 120;

  @override
  Future<Result<String, BitcoinSigningFailure>> applyPolicyPreimages({
    required String psbt,
    required List<BitcoinPolicyPreimage> preimages,
  }) => throw UnimplementedError();

  @override
  Future<Result<bool, BitcoinSigningFailure>> validatePolicyPreimage(
    BitcoinPolicyPreimage preimage,
  ) => throw UnimplementedError();

  @override
  Future<Result<({String transaction, int txSize}), BitcoinSigningFailure>>
  verifyFinalTransaction({required String psbt, required String transaction}) =>
      throw UnimplementedError();

  @override
  Future<Result<({bool isFinalized, String psbt}), BitcoinSigningFailure>>
  signPsbt(
    String psbt, {
    required String walletId,
    bool tryFinalize = true,
    String? signerId,
  }) async {
    signCalls++;
    return Ok(signingResult);
  }
}

void main() {
  test(
    'returns a failure when the PSBT is not fully signed by default',
    () async {
      final usecase = SignBitcoinTxUsecase(
        _FakeBitcoinSigningPort((psbt: 'partial', isFinalized: false)),
      );

      final result = await usecase.execute(
        psbt: 'unsigned',
        walletId: 'wallet',
      );

      expect(
        result,
        isA<Err<SignedBitcoinTransaction, BitcoinSigningFailure>>(),
      );
      expect(switch (result) {
        Ok() => null,
        Err(:final failure) => failure.kind,
      }, BitcoinSigningFailureKind.incomplete);
    },
  );

  test(
    'returns a partial PSBT when the caller is coordinating signers',
    () async {
      final usecase = SignBitcoinTxUsecase(
        _FakeBitcoinSigningPort((psbt: 'partial', isFinalized: false)),
      );

      final result = await usecase.execute(
        psbt: 'unsigned',
        walletId: 'wallet',
        requireFinalized: false,
      );
      final signed = (result as Ok).value as SignedBitcoinTransaction;

      expect(signed.signedPsbt, 'partial');
      expect(signed.isFinalized, isFalse);
      expect(signed.txSize, 120);
    },
  );

  test('combines a PSBT returned by an external signer', () async {
    final port = _FakeBitcoinSigningPort((psbt: 'combined', isFinalized: true));
    final usecase = SignBitcoinTxUsecase(port);

    final result = await usecase.execute(
      psbt: 'current',
      externalPsbt: 'external',
      walletId: 'wallet',
    );
    final signed = (result as Ok).value as SignedBitcoinTransaction;

    expect(signed.signedPsbt, 'combined');
    expect(port.combineCalls, 1);
    expect(port.signCalls, 0);
  });
}
