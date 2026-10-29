import 'dart:async';
import 'package:bb_mobile/cbf_lifecycle.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/bitcoin_sync_routing.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Facade extends Mock implements WalletTransactionSyncFacade {}

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Settings extends Mock implements SettingsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final initial in [
    AppLifecycleState.resumed,
    AppLifecycleState.inactive,
    null,
  ]) {
    test(
      'visible lifecycle preserves CBF nodes from initial $initial',
      () async {
        final facade = _Facade(), metadata = _Metadata();
        when(
          () => facade.stopCbfNodes(),
        ).thenAnswer((_) async => const Ok(null));
        final wallets = StreamController<List<WalletMetadataModel>>();
        var stops = 0, starts = 0;
        when(() => facade.pauseCbfNodes()).thenAnswer((_) async {
          stops++;
          return const Ok(null);
        });
        when(() => facade.reconcileCbfWallets(any())).thenAnswer((_) async {
          starts++;
          return const Ok(null);
        });
        when(
          () => metadata.watchSyncPolicies(),
        ).thenAnswer((_) => wallets.stream);
        final lifecycle = CbfLifecycle(
          platform: TargetPlatform.android,
          routing: BitcoinSyncRouting(
            facade: facade,
            settings: _Settings(),
            tor: () => throw StateError('unused'),
          ),
          metadata: metadata,
        );
        addTearDown(() async {
          await lifecycle.dispose();
          await wallets.close();
        });
        Future<void> expectStarts(int count) async {
          for (var index = 0; index < 300 && starts < count; index++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(starts, count);
        }

        lifecycle.start(initial);
        wallets.add([]);
        await expectStarts(1);
        final before = stops;
        lifecycle.onStateChange(AppLifecycleState.inactive);
        lifecycle.onStateChange(AppLifecycleState.resumed);
        expect(stops, before);
        expect(starts, 1);

        for (final background in [
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.detached,
        ]) {
          final previousStops = stops;
          final previousStarts = starts;
          lifecycle.onStateChange(background);
          expect(stops, previousStops + 1);
          lifecycle.onStateChange(AppLifecycleState.inactive);
          expect(stops, previousStops + 1);
          expect(starts, previousStarts);
          lifecycle.onStateChange(AppLifecycleState.resumed);
          await expectStarts(previousStarts + 1);
        }
      },
    );
  }

  for (final platform in [
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    test('hidden desktop $platform keeps its owner until detached', () async {
      final facade = _Facade(), metadata = _Metadata();
      final wallets = StreamController<List<WalletMetadataModel>>();
      var starts = 0, stops = 0;
      when(() => facade.stopCbfNodes()).thenAnswer((_) async => const Ok(null));
      when(() => facade.pauseCbfNodes()).thenAnswer((_) async {
        stops++;
        return const Ok(null);
      });
      when(() => facade.reconcileCbfWallets(any())).thenAnswer((_) async {
        starts++;
        return const Ok(null);
      });
      when(
        () => metadata.watchSyncPolicies(),
      ).thenAnswer((_) => wallets.stream);
      final lifecycle = CbfLifecycle(
        platform: platform,
        routing: BitcoinSyncRouting(
          facade: facade,
          settings: _Settings(),
          tor: () => throw StateError('unused'),
        ),
        metadata: metadata,
      );
      try {
        lifecycle.start(AppLifecycleState.resumed);
        wallets.add([]);
        for (var i = 0; i < 300 && starts == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(starts, 1);
        final before = stops;
        lifecycle.onStateChange(AppLifecycleState.hidden);
        lifecycle.onStateChange(AppLifecycleState.paused);
        lifecycle.onStateChange(AppLifecycleState.resumed);
        expect(stops, before);
        lifecycle.onStateChange(AppLifecycleState.detached);
        expect(stops, before + 1);
      } finally {
        await lifecycle.dispose();
        await wallets.close();
      }
    });
  }

  test(
    'Tor transport changes immediately stop nodes before reverifying routes',
    () async {
      final facade = _Facade(), metadata = _Metadata();
      when(() => facade.stopCbfNodes()).thenAnswer((_) async => const Ok(null));
      final wallets = StreamController<List<WalletMetadataModel>>();
      final transports = StreamController<void>.broadcast(sync: true);
      var stops = 0;
      when(() => facade.pauseCbfNodes()).thenAnswer((_) async {
        stops++;
        return const Ok(null);
      });
      when(
        () => facade.reconcileCbfWallets(any()),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => metadata.watchSyncPolicies(),
      ).thenAnswer((_) => wallets.stream);
      final lifecycle = CbfLifecycle(
        platform: TargetPlatform.android,
        routing: BitcoinSyncRouting(
          facade: facade,
          settings: _Settings(),
          tor: () => throw StateError('No fallback'),
        ),
        metadata: metadata,
        transportChanges: transports.stream,
      );
      lifecycle.start(AppLifecycleState.resumed);
      wallets.add([]);
      await Future<void>.delayed(Duration.zero);
      final before = stops;
      transports.add(null);
      expect(stops, before + 1);
      await lifecycle.dispose();
      await wallets.close();
      await transports.close();
    },
  );
  test(
    'initial foreground gate closes before the first async wallet policy arrives',
    () async {
      final facade = _Facade(), metadata = _Metadata();
      when(() => facade.stopCbfNodes()).thenAnswer((_) async => const Ok(null));
      final wallets = StreamController<List<WalletMetadataModel>>();
      when(
        () => facade.pauseCbfNodes(),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => metadata.watchSyncPolicies(),
      ).thenAnswer((_) => wallets.stream);
      final lifecycle = CbfLifecycle(
        platform: TargetPlatform.android,
        routing: BitcoinSyncRouting(
          facade: facade,
          settings: _Settings(),
          tor: () => throw StateError('unused'),
        ),
        metadata: metadata,
      );
      addTearDown(() async {
        await lifecycle.dispose();
        await wallets.close();
      });
      lifecycle.start(AppLifecycleState.resumed);
      verify(() => facade.setCbfForegroundActive(false)).called(1);
    },
  );
}
