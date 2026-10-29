import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;
import 'package:transaction_sync/transaction_sync.dart';

class _Descriptor extends Mock implements satoshifier.Descriptor {}

class _WatchDescriptor extends Mock
    implements satoshifier.WatchOnlyDescriptor {}

class _Xpub extends Mock implements satoshifier.ExtendedPubkey {}

class _WatchXpub extends Mock implements satoshifier.WatchOnlyXpub {}

void main() {
  for (final (descriptor, expected) in [
    ('tr(key)', BitcoinSyncScriptType.taproot),
    ('wpkh(key)', BitcoinSyncScriptType.segwitV0),
    ('sh(wpkh(key))', BitcoinSyncScriptType.segwitV0),
    ('wsh(multi(keys))', BitcoinSyncScriptType.segwitV0),
    ('pkh(key)', BitcoinSyncScriptType.preSegwit),
  ]) {
    test('parsed descriptor $descriptor carries its output script family', () {
      final parsed = _Descriptor();
      when(() => parsed.combined).thenReturn(descriptor);
      final watch = _WatchDescriptor();
      when(() => watch.descriptor).thenReturn(parsed);
      expect(
        WatchOnlyWalletEntity.descriptor(
          watchOnlyDescriptor: watch,
        ).scanScriptType,
        expected,
      );
    });
  }
  for (final derivation in satoshifier.Derivation.values) {
    test('parsed xpub $derivation carries its chosen derivation family', () {
      final parsed = _Xpub();
      when(() => parsed.derivation).thenReturn(derivation);
      final watch = _WatchXpub();
      when(() => watch.extendedPubkey).thenReturn(parsed);
      expect(
        WatchOnlyWalletEntity.xpub(watchOnlyXpub: watch).scanScriptType,
        derivation == satoshifier.Derivation.bip44
            ? BitcoinSyncScriptType.preSegwit
            : BitcoinSyncScriptType.segwitV0,
      );
    });
  }
}
