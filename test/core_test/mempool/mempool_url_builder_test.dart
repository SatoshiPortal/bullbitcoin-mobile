import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/services/mempool_url_builder.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockActiveServerUsecase extends Mock
    implements GetActiveMempoolServerUsecase {}

void main() {
  test(
    'Payjoin transaction links open details and preserve ownership',
    () async {
      final activeServer = _MockActiveServerUsecase();
      when(() => activeServer.execute(isTestnet: false, isLiquid: false))
          .thenAnswer(
            (_) async => Ok(
              MempoolServer.existing(
                url: 'mempool.bullbitcoin.com',
                network: MempoolServerNetwork.bitcoinMainnet,
                isCustom: false,
              ),
            ),
          );

      final url = await MempoolUrlBuilder(
        getActiveMempoolServerUsecase: activeServer,
      ).bitcoinTxid('txid', isTestnet: false, fragment: 'pj=1:rss:rs');

      expect(
        url,
        'https://mempool.bullbitcoin.com/tx/txid?showDetails=true#pj=1:rss:rs',
      );
    },
  );

  test(
    'Liquid testnet links use the configured server and TLS setting',
    () async {
      final activeServer = _MockActiveServerUsecase();
      when(() => activeServer.execute(isTestnet: true, isLiquid: true))
          .thenAnswer(
            (_) async => Ok(
              MempoolServer.existing(
                url: 'liquid.example.com:8080',
                network: MempoolServerNetwork.liquidTestnet,
                isCustom: true,
                enableSsl: false,
              ),
            ),
          );
      final builder = MempoolUrlBuilder(
        getActiveMempoolServerUsecase: activeServer,
      );

      expect(
        await builder.liquidAddress('address', isTestnet: true),
        'http://liquid.example.com:8080/address/address',
      );
      expect(
        await builder.liquidTxid(
          'txid',
          isTestnet: true,
          unblindedUrl: 'tx/txid#blinded=details',
        ),
        'http://liquid.example.com:8080/tx/txid#blinded=details',
      );
    },
  );
}
