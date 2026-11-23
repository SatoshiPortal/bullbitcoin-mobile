import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/watch_only/import_watch_only_xpub_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';

void main() {
  final extendedPubkey = satoshifier.ExtendedPubkey(
    pubkey: List<int>.filled(78, 0),
    derivation: satoshifier.Derivation.bip84,
    network: satoshifier.Network.bitcoinMainnet,
  );
  entity = WatchOnlyWalletEntity.xpub(
    watchOnlyXpub: satoshifier.WatchOnlyXpub(extendedPubkey: extendedPubkey),
    label: 'My xpub wallet',
  ) as WatchOnlyXpubEntity;
  for (final outcome in <Result<void, ImportWatchOnlyFailure>>[
    const Ok(null),
    const Err(WalletAlreadyExistsFailure()),
    const Err(ImportFailedFailure()),
  ]) {
    test('forwards the selected xpub and its ${outcome.runtimeType}', () async {
      final usecase = ImportWatchOnlyXpubUsecase(({
        required xpub,
        required network,
        required scriptType,
        required label,
      }) async {
        expect(xpub, entity.pubkey);
        expect(network, BitcoinNetwork.mainnet);
        expect(scriptType, ScriptType.bip84);
        expect(label, 'My xpub wallet');
        return outcome;
      });
      expect(await usecase.execute(watchOnlyXpub: entity), same(outcome));
    });
  }
}
