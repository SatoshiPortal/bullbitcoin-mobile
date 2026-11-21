import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/get_bitbox_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/get_ledger_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/ledger/domain/signer_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  // Public account fixture already used by watch_only_wallet_entity_test.dart.
  const xpub =
      'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';
  for (final ledger in [true, false]) {
    test(
      '${ledger ? 'Ledger' : 'BitBox'} reports a captured network mismatch',
      () {
        const account = SignerAccount(
          masterFingerprint: '86241f88',
          derivationPath: "m/84'/0'/0'",
          xpub: xpub,
          scriptType: ScriptType.bip84,
          device: SignerDeviceEntity.ledgerNanoX,
          network: NetworkEnv.testnet,
        );
        final result = ledger
            ? GetLedgerWatchOnlyWalletUsecase().execute(
                account: account,
                label: 'Hardware',
              )
            : GetBitBoxWatchOnlyWalletUsecase().execute(
                account: account,
                label: 'Hardware',
              );
        expect((result as Err).failure, isA<NetworkMismatchFailure>());
      },
    );

    test(
      '${ledger ? 'Ledger' : 'BitBox'} import preserves the captured account',
      () {
        final device = ledger
            ? SignerDeviceEntity.ledgerNanoX
            : SignerDeviceEntity.bitbox02;
        final account = SignerAccount(
          masterFingerprint: '86241f88',
          derivationPath: "m/84'/0'/0'",
          xpub: xpub,
          scriptType: ScriptType.bip84,
          device: device,
          network: NetworkEnv.mainnet,
        );
        final result = ledger
            ? GetLedgerWatchOnlyWalletUsecase().execute(
                account: account,
                label: 'Hardware',
              )
            : GetBitBoxWatchOnlyWalletUsecase().execute(
                account: account,
                label: 'Hardware',
              );
        expect(result, isA<Ok>());
        final wallet = (result as Ok).value as WatchOnlyDescriptorEntity;
        expect(wallet.masterFingerprint, account.masterFingerprint);
        expect(wallet.pubkey, xpub);
        expect(wallet.scriptType, account.scriptType);
        expect(wallet.network.environment, account.network);
        expect(wallet.selectedNetwork, isNotNull);
        expect(wallet.signerDevice, device);
        expect(wallet.label, 'Hardware');
      },
    );
  }
}
