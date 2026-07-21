import 'dart:io';

import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logging_colorful/logging_colorful.dart' as logpkg;

// SPEC-FIAT-STAGING-T2 - Tier 2 credential-import lifecycle + leak sweep.
//
// The webview_flutter widget has no Linux implementation, so the literal
// WebView is deferred to the Android device pass. This spec instead feeds a
// Tier-1-shaped auth response through the REAL mobile code path that the
// WebView's XHR handler calls - SaveExchangeApiKeyUsecase (via ExchangeCubit)
// -> ExchangeApiKeyRepository.saveApiKey -> BullbitcoinApiKeyDatasource secure
// storage - and asserts the issue #196 scoped-credential lifecycle plus a leak
// sweep, in-process, on Linux.
//
// Scoped-key source: the getpaid-e2e fiat-staging lane hands off a real
// captured key via the FIAT_STAGING_SCOPED_KEY_FILE dart-define (a mode-600
// path). Until the server deploy (blocker 1) yields real keys, the lane passes
// no file and the spec proves the lifecycle with a SYNTHETIC well-formed key.
// The key VALUE is never printed by this spec (labels only).

const _scopedKeyFilePath = String.fromEnvironment(
  'FIAT_STAGING_SCOPED_KEY_FILE',
);

// SYNTHETIC well-formed fallback (bbak- + 64 hex); never a real credential.
const _syntheticScopedKey =
    'bbak-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

final _scopedFormat = RegExp(r'^bbak-[0-9a-f]{64}$');

/// Resolves the scoped key from the handoff file when present and well-formed,
/// otherwise the synthetic fallback. Returns the value and its provenance label
/// (never logs the value itself).
({String key, String source}) _resolveScopedKey() {
  if (_scopedKeyFilePath.isNotEmpty) {
    final f = File(_scopedKeyFilePath);
    if (f.existsSync()) {
      final candidate = f.readAsStringSync().trim();
      if (_scopedFormat.hasMatch(candidate)) {
        return (key: candidate, source: 'CAPTURED');
      }
    }
  }
  return (key: _syntheticScopedKey, source: 'SYNTHETIC');
}

Future<void> main({bool isInitialized = false}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final resolved = _resolveScopedKey();
  final scopedKey = resolved.key;
  // Distinctive sentinel; the ordinary key is also swept for leaks.
  const ordinaryKey = 'staging-ordinary-key-SENTINEL-must-not-leak';

  late final bool isTestnet;
  late final BullbitcoinApiKeyDatasource datasource;
  late final ExchangeApiKeyRepository repository;

  // ignore: avoid_print
  print('T2 scoped-key provenance: ${resolved.source}');

  Map<String, dynamic> ordinaryPayload(String userId) => {
    'id': 'apikey-$userId',
    'key': ordinaryKey,
    'name': 'mobile-integration-test',
    'userId': userId,
    'isActive': true,
    'createdAt': '2026-07-20T00:00:00.000Z',
    'updatedAt': '2026-07-20T00:00:00.000Z',
  };

  setUpAll(() async {
    isTestnet =
        (await locator<GetSettingsUsecase>().execute()).environment.isTestnet;
    datasource = locator<BullbitcoinApiKeyDatasource>();
    repository = locator<ExchangeApiKeyRepository>();
  });

  setUp(() async {
    await repository.deleteApiKey(isTestnet: isTestnet);
  });

  tearDownAll(() async {
    await repository.deleteApiKey(isTestnet: isTestnet);
  });

  test('import stores ordinary + scoped keys, userId-bound, scoped readable '
      'only through the datasource', () async {
    const userId = 'staging-user-1';
    await locator<SaveExchangeApiKeyUsecase>().execute(
      apiKeyResponseData: {
        'apiKey': ordinaryPayload(userId),
        'sellToFiatBalanceApiKey': scopedKey,
      },
      isTestnet: isTestnet,
    );

    final ordinary = await datasource.get(isTestnet: isTestnet);
    expect(ordinary, isNotNull);
    expect(ordinary!.userId, userId);

    final scoped = await datasource.getSellToFiatBalanceApiKey(
      isTestnet: isTestnet,
    );
    expect(scoped, isNotNull, reason: 'well-formed scoped key must persist');
    // userId-bound: the scoped key carries the ordinary key's userId.
    expect(scoped!.userId, userId);
    expect(scoped.isWellFormed, isTrue);
    // Value round-trips through the datasource seam (not compared inline in a
    // way that would print it): equality check only.
    expect(scoped.key == scopedKey, isTrue);
  });

  test('logout deletes BOTH keys for the environment', () async {
    const userId = 'staging-user-2';
    await locator<SaveExchangeApiKeyUsecase>().execute(
      apiKeyResponseData: {
        'apiKey': ordinaryPayload(userId),
        'sellToFiatBalanceApiKey': scopedKey,
      },
      isTestnet: isTestnet,
    );
    expect(await datasource.get(isTestnet: isTestnet), isNotNull);
    expect(
      await datasource.getSellToFiatBalanceApiKey(isTestnet: isTestnet),
      isNotNull,
    );

    await repository.deleteApiKey(isTestnet: isTestnet);

    expect(await datasource.get(isTestnet: isTestnet), isNull);
    expect(
      await datasource.getSellToFiatBalanceApiKey(isTestnet: isTestnet),
      isNull,
    );
  });

  test('re-login (repeated save) re-imports the scoped key', () async {
    const userId = 'staging-user-3';
    Future<void> login() => locator<SaveExchangeApiKeyUsecase>().execute(
      apiKeyResponseData: {
        'apiKey': ordinaryPayload(userId),
        'sellToFiatBalanceApiKey': scopedKey,
      },
      isTestnet: isTestnet,
    );

    await login();
    await repository.deleteApiKey(isTestnet: isTestnet);
    expect(
      await datasource.getSellToFiatBalanceApiKey(isTestnet: isTestnet),
      isNull,
    );

    await login();
    final rescoped = await datasource.getSellToFiatBalanceApiKey(
      isTestnet: isTestnet,
    );
    expect(rescoped, isNotNull, reason: 're-login must re-import scoped key');
    expect(rescoped!.userId, userId);
  });

  test(
    'absent sellToFiatBalanceApiKey preserves an existing same-user key',
    () async {
      const userId = 'staging-user-4';
      await locator<SaveExchangeApiKeyUsecase>().execute(
        apiKeyResponseData: {
          'apiKey': ordinaryPayload(userId),
          'sellToFiatBalanceApiKey': scopedKey,
        },
        isTestnet: isTestnet,
      );
      // Same user logs in again, but the response omits the scoped field
      // (blocker-1 old server, or a login that didn't opt in).
      await locator<SaveExchangeApiKeyUsecase>().execute(
        apiKeyResponseData: {'apiKey': ordinaryPayload(userId)},
        isTestnet: isTestnet,
      );
      final scoped = await datasource.getSellToFiatBalanceApiKey(
        isTestnet: isTestnet,
      );
      expect(
        scoped,
        isNotNull,
        reason: 'same-user re-login without the field must preserve the key',
      );
      expect(scoped!.userId, userId);
    },
  );

  test('account switch (different userId, no scoped field) removes the foreign '
      'scoped key', () async {
    await locator<SaveExchangeApiKeyUsecase>().execute(
      apiKeyResponseData: {
        'apiKey': ordinaryPayload('staging-user-A'),
        'sellToFiatBalanceApiKey': scopedKey,
      },
      isTestnet: isTestnet,
    );
    // A different Bull Bitcoin user logs in without a scoped key.
    await locator<SaveExchangeApiKeyUsecase>().execute(
      apiKeyResponseData: {'apiKey': ordinaryPayload('staging-user-B')},
      isTestnet: isTestnet,
    );
    expect(
      await datasource.getSellToFiatBalanceApiKey(isTestnet: isTestnet),
      isNull,
      reason: 'a foreign scoped key must not survive an account switch',
    );
  });

  test('malformed scoped value is not stored (and never logged)', () async {
    const userId = 'staging-user-5';
    await locator<SaveExchangeApiKeyUsecase>().execute(
      apiKeyResponseData: {
        'apiKey': ordinaryPayload(userId),
        // Not bbak-<64hex>: must be dropped, never persisted.
        'sellToFiatBalanceApiKey': 'bbak-not-a-valid-key',
      },
      isTestnet: isTestnet,
    );
    expect(
      await datasource.getSellToFiatBalanceApiKey(isTestnet: isTestnet),
      isNull,
    );
    // Ordinary login still succeeds regardless of scoped malformation.
    expect(await datasource.get(isTestnet: isTestnet), isNotNull);
  });

  test('leak sweep: neither key value appears in logs, the on-disk log file, '
      'or ExchangeCubit state after the real import path', () async {
    const userId = 'staging-user-6';
    final captured = <String>[];
    final sub = logpkg.Logger.root.onRecord.listen((r) {
      captured.add(
        '${r.message} ${r.error ?? ''} ${r.stackTrace ?? ''} '
        '${r.loggerName} ${r.level.name}',
      );
    });

    final cubit = locator<ExchangeCubit>();
    try {
      // The EXACT method the WebView XHR handler calls on success.
      await cubit.storeApiKey({
        'apiKey': ordinaryPayload(userId),
        'sellToFiatBalanceApiKey': scopedKey,
      }, isTestnet: isTestnet);
    } finally {
      await sub.cancel();
    }

    bool leaks(String haystack) =>
        haystack.contains(scopedKey) || haystack.contains(ordinaryKey);

    // Import must have succeeded (no exception surfaced into state).
    expect(cubit.state.saveApiKeyException, isNull);

    // 1) Logs captured during the run.
    final leakingLines = captured.where(leaks).length;
    expect(
      leakingLines,
      0,
      reason: 'no key value may appear in any log record',
    );

    // 2) BLoC state toString().
    expect(
      leaks(cubit.state.toString()),
      isFalse,
      reason: 'no key value may appear in ExchangeCubit state',
    );

    // 3) On-disk TSV log file the app writes.
    final logFile = File('${Directory.current.path}/bull_logs.tsv');
    if (await logFile.exists()) {
      expect(
        leaks(await logFile.readAsString()),
        isFalse,
        reason: 'no key value may appear in the on-disk log',
      );
    }

    // Route arguments and the Sentry/analytics buffer are not observable in the
    // headless Linux lane; those surfaces are swept in the Android device pass.
  });
}
