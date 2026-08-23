import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_server_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves the custom server certificate policy', () {
    final server = MempoolServer.existing(
      url: 'mempool.local',
      network: MempoolServerNetwork.bitcoinMainnet,
      isCustom: true,
      validateDomain: false,
    );

    final row = MempoolServerModel.fromEntity(server).toSqlite();
    final rehydrated = MempoolServerModel.fromSqlite(row).toEntity();

    expect(rehydrated.validateDomain, isFalse);
  });
}
