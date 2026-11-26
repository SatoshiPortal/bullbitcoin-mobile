import 'dart:async';

import 'package:ark/ark.dart';
import 'package:ark/funding.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test(
    'regtest waits for the authority to commit possible signer exposure',
    () async {
      final authority = _Authority();
      final guard = ArkFundingSigningGuard(authority: authority);
      var admitted = false;
      final pending = guard
          .admit(
            walletId: 'source',
            network: BitcoinNetwork.regtest,
            unsignedPsbt: 'unsigned',
          )
          .then((result) {
            admitted = true;
            return result;
          });
      await Future<void>.delayed(Duration.zero);
      expect(authority.request, ('source', BitcoinNetwork.regtest, 'unsigned'));
      expect(admitted, isFalse);
      authority.completion.complete(const Err(ArkStorageFailure()));
      expect(await pending, isA<Err<void, ArkWalletFailure>>());
    },
  );

  test(
    'ordinary regtest requires positive current evidence of absence',
    () async {
      final evidence = _Installation();
      final guard = ArkFundingSigningGuard(
        authority: null,
        installation: evidence,
      );
      final admitted = await guard.admit(
        walletId: 'ordinary',
        network: BitcoinNetwork.regtest,
        unsignedPsbt: 'unsigned',
      );
      expect(admitted, isA<Ok<void, ArkWalletFailure>>());
      evidence.unprovisioned = false;
      expect(
        await guard.admit(
          walletId: 'ordinary',
          network: BitcoinNetwork.regtest,
          unsignedPsbt: 'unsigned',
        ),
        isA<Err<void, ArkWalletFailure>>(),
      );
    },
  );
}

final class _Authority implements ArkFundingSigningAuthority {
  final completion = Completer<Result<void, ArkWalletFailure>>();
  (String, BitcoinNetwork, String)? request;

  @override
  Future<Result<void, ArkWalletFailure>> recordOrdinarySigning({
    required String walletId,
    required BitcoinNetwork network,
    required String unsignedPsbt,
  }) {
    request = (walletId, network, unsignedPsbt);
    return completion.future;
  }
}

final class _Installation implements ArkInstallationEvidence {
  bool unprovisioned = true;

  @override
  Future<bool> remainsUnprovisioned() async => unprovisioned;
}
