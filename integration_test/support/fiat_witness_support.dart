import 'dart:convert';
import 'dart:io';

/// Support harness for the FUNDED fiat-settlement WITNESS spec
/// (fiat_settlement_funded_witness_test.dart).
///
/// This is the CLIENT-SIDE driver for phases W1 (fiat-only settlement
/// visibility), W3 (pending -> settled transition) and W5 (product matrix) of
/// the full integration certification, plus the W4 mixed-settlement assertions.
/// It NEVER pays and NEVER sends: paying a tiny real amount is done externally
/// by the guarded payer under the coordinator. The spec drives the app side
/// (register a fresh identity, create the product, configure fiat settlement)
/// and then OBSERVES the real Bullnym history projection until settled data
/// renders.
///
/// Handshake with the coordinator is a small set of files under a run-scoped
/// directory:
///   `<handshake>/ready.json`        spec -> coordinator: pay target + params.
///   `<handshake>/<runId>.seed.json` spec -> durable: app-owned recovery words
///                                   (mode-0600, NEVER printed/emitted else).
///   `<handshake>/result.json`       spec -> coordinator: observed final state.
///
/// The recovery capture exists because the witness wallet is created and owned
/// by the app (a fresh on-device seed); the tiny funded amount an interrupted
/// run could strand is recoverable only from that file. It is the ONLY place
/// the words are written, and they are never logged, printed, or put on the
/// coordinator-facing handshake.

/// The Get Paid product the witness exercises. The [wireId] matches the
/// FIAT_WITNESS_PRODUCT define and the Bullnym product path id.
enum FiatWitnessProduct {
  paymentPage('payment_page'),
  pos('pos'),
  lightningAddress('lightning_address'),
  invoice('invoice');

  const FiatWitnessProduct(this.wireId);

  final String wireId;

  static FiatWitnessProduct? fromWire(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    for (final product in FiatWitnessProduct.values) {
      if (product.wireId == v) return product;
    }
    return null;
  }
}

/// The settlement shape the witness expects to observe. The below-minimum
/// behaviour is driven by the tiny paid AMOUNT (payer-side), not by the config:
/// [belowMin] still configures 100% fiat and expects the server to override the
/// conversion to Bitcoin because the amount is under the gateway minimum.
enum FiatWitnessMode {
  fiat100('fiat100'),
  mixed50('mixed50'),
  belowMin('below_min');

  const FiatWitnessMode(this.wireId);

  final String wireId;

  /// The fiat percentage the witness configures for this mode.
  int get fiatPercentage => switch (this) {
    FiatWitnessMode.fiat100 => 100,
    FiatWitnessMode.mixed50 => 50,
    // Below-minimum still asks for 100% fiat; the override comes from the amount.
    FiatWitnessMode.belowMin => 100,
  };

  static FiatWitnessMode? fromWire(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    for (final mode in FiatWitnessMode.values) {
      if (mode.wireId == v) return mode;
    }
    return null;
  }
}

/// Matches the scoped `SELL_TO_FIAT_BALANCE` credential value (`bbak-` + 64 hex).
final _scopedKeyFormat = RegExp(r'^bbak-[0-9a-f]{64}$');

/// A clearly-synthetic, well-formed scoped key the deterministic staging
/// provider accepts as "eligible" (the two hex chars after `bbak-` select the
/// fixture behaviour; `00` = eligible). Used only when no real key handoff is
/// present AND the provider is the fixture — the lane gates this.
const syntheticEligibleScopedKey =
    'bbak-0000000000000000000000000000000000000000000000000000000000000000';

/// Never prints the value; matches on shape only.
bool textLeaksScopedKey(String text) =>
    text.contains(RegExp(r'bbak-[0-9a-f]{8}'));

/// Run configuration for the funded fiat witness, resolved from the process
/// environment (operator-provided) with `--dart-define` fallbacks for device
/// runs. NO mnemonic is injected — the app creates and owns its own seed.
class FiatWitnessConfig {
  static const _productDefine = String.fromEnvironment('FIAT_WITNESS_PRODUCT');
  static const _modeDefine = String.fromEnvironment('FIAT_WITNESS_MODE');
  static const _runIdDefine = String.fromEnvironment('FIAT_WITNESS_RUN_ID');
  static const _handshakeDefine = String.fromEnvironment(
    'FIAT_WITNESS_HANDSHAKE_DIR',
  );
  static const _amountDefine = String.fromEnvironment('FIAT_WITNESS_AMOUNT_SAT');
  static const _scopedKeyDefine = String.fromEnvironment(
    'FIAT_STAGING_SCOPED_KEY_FILE',
  );
  static const _pollTimeoutDefine = String.fromEnvironment(
    'FIAT_WITNESS_POLL_TIMEOUT_SEC',
  );
  static const _settleTimeoutDefine = String.fromEnvironment(
    'FIAT_WITNESS_SETTLE_TIMEOUT_SEC',
  );
  static const _pollIntervalDefine = String.fromEnvironment(
    'FIAT_WITNESS_POLL_INTERVAL_SEC',
  );

  static const _defaultAmountSat = 2000;
  static const _defaultPollTimeoutSec = 900; // 15 min for the first real row.
  static const _defaultSettleTimeoutSec = 900; // 15 min pending -> settled.
  static const _defaultPollIntervalSec = 10;

  final FiatWitnessProduct product;
  final FiatWitnessMode mode;
  final String runId;
  final String nym;
  final Directory handshakeDir;
  final int amountSat;
  final String? scopedKeyFilePath;
  final Duration pollTimeout;
  final Duration settleTimeout;
  final Duration pollInterval;

  const FiatWitnessConfig._({
    required this.product,
    required this.mode,
    required this.runId,
    required this.nym,
    required this.handshakeDir,
    required this.amountSat,
    required this.scopedKeyFilePath,
    required this.pollTimeout,
    required this.settleTimeout,
    required this.pollInterval,
  });

  /// The reason this run must be skipped (missing product/mode/handshake dir),
  /// or null when the witness is fully configured. Kept as a value (not a
  /// throw) so a `--dart-define`-less run compiles the spec and self-skips.
  static String? skipReason() {
    if (_resolveProduct() == null) {
      return 'SKIP(FIAT_WITNESS_PRODUCT unset or invalid) - pass '
          '--dart-define=FIAT_WITNESS_PRODUCT=payment_page|pos|'
          'lightning_address|invoice';
    }
    if (_resolveMode() == null) {
      return 'SKIP(FIAT_WITNESS_MODE unset or invalid) - pass '
          '--dart-define=FIAT_WITNESS_MODE=fiat100|mixed50|below_min';
    }
    final handshake = _resolveHandshakePath();
    if (handshake == null) {
      return 'SKIP(FIAT_WITNESS_HANDSHAKE_DIR unset) - the coordinator must '
          'create a handshake directory and pass it as '
          '--dart-define=FIAT_WITNESS_HANDSHAKE_DIR=<dir>';
    }
    return null;
  }

  /// Resolves the full configuration. Only call when [skipReason] is null.
  factory FiatWitnessConfig.fromEnvironment() {
    final product = _resolveProduct();
    final mode = _resolveMode();
    final handshakePath = _resolveHandshakePath();
    if (product == null || mode == null || handshakePath == null) {
      throw StateError(
        'FiatWitnessConfig.fromEnvironment called while unconfigured; guard '
        'the test with FiatWitnessConfig.skipReason() first',
      );
    }

    final handshakeDir = Directory(handshakePath);
    if (!handshakeDir.existsSync()) {
      throw StateError(
        'FIAT_WITNESS_HANDSHAKE_DIR ($handshakePath) does not exist; the '
        'coordinator must create the handshake directory before launch',
      );
    }

    final runId = _cleanNymPart(
      _firstNonEmpty([
            Platform.environment['FIAT_WITNESS_RUN_ID'],
            _runIdDefine,
          ]) ??
          DateTime.now().millisecondsSinceEpoch.toRadixString(36),
    );

    // Fresh nym per run (permanent-names are never reused). `fw` + runId,
    // clamped to the 32-char server cap.
    final rawNym = 'fw$runId';
    final nym = rawNym.length > 32 ? rawNym.substring(0, 32) : rawNym;
    if (nym.isEmpty) {
      throw StateError('FIAT_WITNESS_RUN_ID produced an empty nym');
    }

    final scopedKeyPath = _firstNonEmpty([
      Platform.environment['FIAT_STAGING_SCOPED_KEY_FILE'],
      _scopedKeyDefine,
    ]);

    return FiatWitnessConfig._(
      product: product,
      mode: mode,
      runId: runId,
      nym: nym,
      handshakeDir: handshakeDir,
      amountSat: _intFromEnv(
        _firstNonEmpty([
          Platform.environment['FIAT_WITNESS_AMOUNT_SAT'],
          _amountDefine,
        ]),
        'FIAT_WITNESS_AMOUNT_SAT',
        _defaultAmountSat,
      ),
      scopedKeyFilePath: scopedKeyPath,
      pollTimeout: _durationFromEnvSec(
        _firstNonEmpty([
          Platform.environment['FIAT_WITNESS_POLL_TIMEOUT_SEC'],
          _pollTimeoutDefine,
        ]),
        'FIAT_WITNESS_POLL_TIMEOUT_SEC',
        _defaultPollTimeoutSec,
      ),
      settleTimeout: _durationFromEnvSec(
        _firstNonEmpty([
          Platform.environment['FIAT_WITNESS_SETTLE_TIMEOUT_SEC'],
          _settleTimeoutDefine,
        ]),
        'FIAT_WITNESS_SETTLE_TIMEOUT_SEC',
        _defaultSettleTimeoutSec,
      ),
      pollInterval: _durationFromEnvSec(
        _firstNonEmpty([
          Platform.environment['FIAT_WITNESS_POLL_INTERVAL_SEC'],
          _pollIntervalDefine,
        ]),
        'FIAT_WITNESS_POLL_INTERVAL_SEC',
        _defaultPollIntervalSec,
      ),
    );
  }

  File get readyFile => _fileIn('ready.json');
  File get resultFile => _fileIn('result.json');

  /// The durable, mode-0600 recovery capture for THIS run. One file per run so
  /// a re-run never clobbers a prior wallet's material.
  File get seedFile =>
      File('${handshakeDir.path}${Platform.pathSeparator}$runId.seed.json');

  File _fileIn(String name) =>
      File('${handshakeDir.path}${Platform.pathSeparator}$name');

  /// Reads the operator-provided scoped key from the mode-600 handoff file when
  /// present and well-formed; otherwise null (the caller may fall back to the
  /// synthetic eligible key when the provider is the fixture). The value is
  /// never logged or returned anywhere it could be printed.
  String? capturedScopedKey() {
    final path = scopedKeyFilePath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final value = file.readAsStringSync().trim();
    return _scopedKeyFormat.hasMatch(value) ? value : null;
  }

  /// Atomic publish: write to a sibling temp file then rename over the target so
  /// the coordinator never observes a half-written document.
  Future<void> writeJsonAtomic(File file, Map<String, Object?> data) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  /// Writes the recovery capture with owner-only (0600) permissions, BEFORE any
  /// funding. The content is the recovery material; it is written only to this
  /// local durable file and NEVER logged, printed, or emitted on the handshake.
  /// Returns the absolute path (safe to reference in a checkpoint).
  Future<String> writeSeedCapture(Map<String, Object?> secret) async {
    final file = seedFile;
    // Create empty, lock down the mode, THEN write, so the secret bytes never
    // exist on disk under a world-readable mode even briefly.
    await file.create(recursive: true);
    await _chmod('600', file.path);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(secret),
      flush: true,
    );
    await _chmod('600', file.path);
    return file.path;
  }

  static Future<void> _chmod(String mode, String path) async {
    final result = await Process.run('chmod', [mode, path]);
    if (result.exitCode != 0) {
      throw StateError('chmod $mode $path failed: ${result.stderr}');
    }
  }

  static FiatWitnessProduct? _resolveProduct() => FiatWitnessProduct.fromWire(
    _firstNonEmpty([
      Platform.environment['FIAT_WITNESS_PRODUCT'],
      _productDefine,
    ]),
  );

  static FiatWitnessMode? _resolveMode() => FiatWitnessMode.fromWire(
    _firstNonEmpty([Platform.environment['FIAT_WITNESS_MODE'], _modeDefine]),
  );

  static String? _resolveHandshakePath() => _firstNonEmpty([
    Platform.environment['FIAT_WITNESS_HANDSHAKE_DIR'],
    _handshakeDefine,
  ]);

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static String _cleanNymPart(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static int _intFromEnv(String? raw, String name, int fallback) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return fallback;
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) {
      throw StateError('$name must be a positive integer (got: $value)');
    }
    return parsed;
  }

  static Duration _durationFromEnvSec(String? raw, String name, int fallback) =>
      Duration(seconds: _intFromEnv(raw, name, fallback));
}

/// Redacts an order id to its first 8 characters for the coordinator-facing
/// result file (enough to correlate against the server journal, not the full
/// identifier). Empty stays empty.
String redactOrderId(String orderId) {
  final trimmed = orderId.trim();
  if (trimmed.length <= 8) return trimmed;
  return '${trimmed.substring(0, 8)}...';
}

/// Emits a single machine-readable checkpoint line. Only non-secret run
/// metadata is ever included — never the mnemonic, passphrase, scoped key, or
/// any signer material.
void witnessCheckpoint(
  String step, {
  String status = 'ok',
  Map<String, Object?> data = const {},
}) {
  final payload = <String, Object?>{
    'step': step,
    'status': status,
    'ts': DateTime.now().toUtc().toIso8601String(),
    ...data,
  };
  // ignore: avoid_print
  print('CHECKPOINT ${jsonEncode(payload)}');
}
