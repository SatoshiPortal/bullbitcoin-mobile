import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/domain/entropy_source.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:crypto/crypto.dart';

/// SHA-512 entropy accumulator modelled on Bitcoin Core's
/// `RNGState::MixExtract` (src/random.cpp).
///
/// Invariants (see also the module tests):
/// - Additivity: every mix hashes the new data *together with* the previous
///   state, so no source — even one returning attacker-chosen bytes — can
///   ever reduce the entropy already in the pool. Sources are concatenated
///   and hashed, never XORed, and nothing can replace the state wholesale.
/// - Mandatory floor: [extract] throws unless the OS RNG and the bdk RNG
///   were both mixed since the last extraction, so output is never weaker
///   than the platform CSPRNG regardless of what the other sources do.
/// - Half-out/half-back: each SHA-512 digest is split — the first 32 bytes
///   are the output, the second 32 bytes become the next secret state and
///   never leave this class. Extraction is capped at 32 bytes per round.
class EntropyPool {
  EntropyPool({this.strengthenBudget = const Duration(milliseconds: 10)});

  /// CPU budget for the strengthening pass run on every extraction.
  /// [Duration.zero] disables strengthening (deterministic mode for tests).
  final Duration strengthenBudget;

  static const _stateSize = 32;
  static const maxExtractBytes = 32;
  static const mandatorySources = {
    EntropySourceName.osRng,
    EntropySourceName.bdkRng,
  };

  Uint8List _state = Uint8List(_stateSize);
  int _counter = 0;
  final Set<String> _mandatoryMixed = {};

  /// Folds [data] from [sourceName] into the pool state.
  ///
  /// Empty data is skipped: "mixed" must always mean real bytes arrived,
  /// never a placeholder.
  void mix(String sourceName, Uint8List data) {
    if (data.isEmpty) return;

    final nameBytes = _utf8(sourceName);
    final input = BytesBuilder(copy: false)
      ..add(_encodeU64(nameBytes.length))
      ..add(nameBytes)
      ..add(_encodeU64(_counter++))
      ..add(_encodeU64(data.length))
      ..add(data)
      ..add(_state);
    final digest = sha512.convert(input.takeBytes()).bytes;

    _replaceState(digest);
    if (mandatorySources.contains(sourceName)) {
      _mandatoryMixed.add(sourceName);
    }
  }

  /// Burns [strengthenBudget] of CPU time iterating SHA-512 over the state,
  /// like Bitcoin Core's `Strengthen()`. The result plus the observed
  /// iteration count and elapsed ticks (scheduler/clock jitter) are folded
  /// back through the normal mix path.
  void strengthen() {
    if (strengthenBudget == Duration.zero) return;

    final stopwatch = Stopwatch()..start();
    var buffer = Uint8List.fromList([..._encodeU64(_counter++), ..._state]);
    var iterations = 0;
    do {
      for (var i = 0; i < 64; i++) {
        buffer = Uint8List.fromList(sha512.convert(buffer).bytes);
        iterations++;
      }
    } while (stopwatch.elapsed < strengthenBudget);
    stopwatch.stop();

    mix(
      EntropySourceName.strengthen,
      Uint8List.fromList([
        ...buffer,
        ..._encodeU64(iterations),
        ..._encodeU64(stopwatch.elapsedTicks),
      ]),
    );
    _zero(buffer);
  }

  /// Returns [length] bytes (max 32) of entropy and advances the state.
  ///
  /// Throws [EntropyPoolNotSeededException] unless every mandatory source
  /// was mixed since the last extraction.
  Uint8List extract(int length) {
    if (length <= 0 || length > maxExtractBytes) {
      throw ArgumentError.value(
        length,
        'length',
        'must be between 1 and $maxExtractBytes bytes',
      );
    }
    final missing = mandatorySources.difference(_mandatoryMixed);
    if (missing.isNotEmpty) {
      throw EntropyPoolNotSeededException(missing);
    }

    strengthen();

    final input = BytesBuilder(copy: false)
      ..add(_encodeU64(_counter++))
      ..add(_state);
    final digest = sha512.convert(input.takeBytes()).bytes;

    _replaceState(digest);
    _mandatoryMixed.clear();
    return Uint8List.fromList(digest.sublist(0, length));
  }

  /// Adopts the second half of [digest] as the new state and best-effort
  /// zeroes the old one (Dart's GC may have made copies; this matches the
  /// hygiene level of the rest of the seed handling code).
  void _replaceState(List<int> digest) {
    assert(digest.length == 64);
    final old = _state;
    _state = Uint8List.fromList(digest.sublist(_stateSize));
    _zero(old);
  }

  static void _zero(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  static Uint8List _utf8(String value) =>
      Uint8List.fromList(utf8.encode(value));

  static Uint8List _encodeU64(int value) {
    final bytes = Uint8List(8);
    ByteData.view(bytes.buffer).setUint64(0, value);
    return bytes;
  }
}

class EntropyPoolNotSeededException extends BullException {
  EntropyPoolNotSeededException(Set<String> missingSources)
    : super(
        'Entropy pool is missing mandatory sources: '
        '${missingSources.join(', ')}',
      );
}
