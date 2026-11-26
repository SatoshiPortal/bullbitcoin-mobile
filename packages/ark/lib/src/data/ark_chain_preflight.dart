import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:primitives/primitives.dart';

import '../../ark.dart';

abstract interface class ArkChainPreflight {
  Future<Result<Uri, ArkWalletFailure>> select(
    ArkAccountConfig config, {
    Uri? requiredSource,
    int? minimumTip,
  });
}

/// Only transport failures before native admission permit provider fallback.
final class HttpArkChainPreflight implements ArkChainPreflight {
  const HttpArkChainPreflight();
  @override
  Future<Result<Uri, ArkWalletFailure>> select(
    ArkAccountConfig config, {
    Uri? requiredSource,
    int? minimumTip,
  }) async {
    final primary = requiredSource ?? config.primaryEsploraUrl;
    try {
      await _probe(primary, config.id.network, minimumTip);
      return Ok(primary);
    } on SocketException {
      return _fallback(config, primary, requiredSource, minimumTip);
    } on TimeoutException {
      return _fallback(config, primary, requiredSource, minimumTip);
    } on Exception {
      return const Err(
        ArkUnavailableFailure(ArkFailureReason.chainUnreachable),
      );
    }
  }

  Future<Result<Uri, ArkWalletFailure>> _fallback(
    ArkAccountConfig config,
    Uri primary,
    Uri? requiredSource,
    int? minimumTip,
  ) async {
    final fallback = config.fallbackEsploraUrl;
    if (requiredSource != null || fallback == null || fallback == primary) {
      return const Err(
        ArkUnavailableFailure(ArkFailureReason.chainUnreachable),
      );
    }
    try {
      await _probe(fallback, config.id.network, minimumTip);
      return Ok(fallback);
    } on Exception {
      return const Err(
        ArkUnavailableFailure(ArkFailureReason.chainUnreachable),
      );
    }
  }

  Future<void> _probe(
    Uri source,
    BitcoinNetwork network,
    int? minimumTip,
  ) async {
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    var reached = false;
    Future<String> get(String suffix) async {
      final path = '${source.path.replaceFirst(RegExp(r'/+$'), '')}/$suffix';
      final request = await http
          .getUrl(source.replace(path: path))
          .timeout(const Duration(seconds: 5));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      reached = true;
      if (response.statusCode != 200) {
        throw const HttpException('Rejected chain endpoint');
      }
      final chunks = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 5))) {
        chunks.addAll(chunk);
        if (chunks.length > 128) {
          throw const FormatException('Oversize chain response');
        }
      }
      return utf8.decode(chunks).trim();
    }

    try {
      final height = int.tryParse(await get('blocks/tip/height'));
      if (height == null ||
          height < 0 ||
          (minimumTip != null && height < minimumTip)) {
        throw const FormatException('Invalid or regressed chain tip');
      }
      final genesis = await get('block-height/0');
      final expected = switch (network) {
        BitcoinNetwork.mainnet =>
          '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f',
        BitcoinNetwork.testnet =>
          '000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943',
        BitcoinNetwork.signet =>
          '00000008819873e925422c1ff0f99f7cc9bbb232af63a077a480a3633bee1ef6',
        BitcoinNetwork.regtest =>
          '0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206',
      };
      if (genesis != expected) {
        throw const FormatException('Wrong chain genesis');
      }
    } on SocketException {
      if (reached) throw const HttpException('Reachable provider interrupted');
      rethrow;
    } on TimeoutException {
      if (reached) throw const HttpException('Reachable provider interrupted');
      rethrow;
    } finally {
      http.close(force: true);
    }
  }
}
