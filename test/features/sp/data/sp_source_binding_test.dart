import 'package:bb_mobile/features/sp/data/sp_backend_config_model.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  const source = SpSourceBinding(
    walletId: 'wallet',
    secretId: '12345678',
    externalDescriptor: 'external',
    internalDescriptor: 'internal',
    spAddress: 'public-address',
  );

  test('round trips the complete source with a version', () {
    final json = SpBackendConfigModel(
      network: BitcoinNetwork.signet,
      source: source,
      blindbitUrl: 'https://example.test',
      electrumUrl: 'ssl://example.test:50002',
    ).toJson();
    final restored = SpBackendConfigModel.fromJson(json);
    expect(json['schemaVersion'], 1);
    expect(restored.source, source);
    expect(restored.network, BitcoinNetwork.signet);
  });

  test('legacy config remains unbound', () {
    final restored = SpBackendConfigModel.fromJson({
      'network': 'bitcoin',
      'blindbitUrl': 'https://example.test',
      'electrumUrl': 'ssl://example.test:50002',
    });
    expect(restored.source, isNull);
    expect(restored.network, BitcoinNetwork.mainnet);
  });

  test('unknown versions and partial bindings are rejected', () {
    final legacy = {
      'network': 'signet',
      'blindbitUrl': 'https://example.test',
      'electrumUrl': 'ssl://example.test:50002',
    };
    expect(
      () => SpBackendConfigModel.fromJson({
        ...legacy,
        'schemaVersion': 2,
        'source': {},
      }),
      throwsFormatException,
    );
    expect(
      () => SpBackendConfigModel.fromJson({...legacy, 'schemaVersion': 1}),
      throwsFormatException,
    );
  });
}
