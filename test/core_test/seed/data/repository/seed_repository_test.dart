import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedDatasource extends Mock implements SeedDatasource {}

void main() {
  test('matches an account xpub to the stored seed', () async {
    final source = _MockSeedDatasource();
    final seedBytes = Uint8List.fromList(
      List<int>.generate(32, (index) => index + 1),
    );
    final model = SeedModel.bytes(bytes: seedBytes);
    final fingerprint = model.masterFingerprint;
    final accountXpub = (await Bip32Derivation.getAccountXpub(
      seedBytes: seedBytes,
      scriptType: ScriptType.bip84,
      network: Network.bitcoinMainnet,
    )).toBase58();
    when(() => source.exists(fingerprint)).thenAnswer((_) async => true);
    when(() => source.get(fingerprint)).thenAnswer((_) async => model);

    final repository = SeedRepository(source: source);

    expect(
      await repository.matchesXpubs(
        fingerprint: fingerprint,
        keys: [(derivationPath: "m/84'/0'/0'", xpub: accountXpub)],
      ),
      isTrue,
    );
    expect(
      await repository.matchesXpubs(
        fingerprint: fingerprint,
        keys: [(derivationPath: "m/84'/0'/1'", xpub: accountXpub)],
      ),
      isFalse,
    );
  });
}
