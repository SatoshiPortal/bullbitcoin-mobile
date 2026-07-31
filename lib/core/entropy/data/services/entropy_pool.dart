import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:crypto/crypto.dart';

/// Stateful SHA-512 combiner for wallet-generation entropy.
///
/// A fresh touch ceremony and a fresh operating-system CSPRNG draw are both
/// required for every extraction. Touch input is deliberately uncredited: it
/// is a physically distinct hedge against predictable RNG output, not a
/// claimed number of entropy bits.
///
/// Each operation hashes framed input together with the previous 256-bit
/// state. Extraction returns the first half of a SHA-512 digest and retains
/// the second half as the next secret state.
class EntropyPool {
  static const stateSize = 32;
  static const maxExtractBytes = 32;
  static const minOsEntropyBytes = 32;
  static const requiredTouchSamples = 300;

  static const _touchBeginDomain = 'touch-ceremony-begin-v1';
  static const _touchSampleDomain = 'touch-sample-v1';
  static const _touchCompleteDomain = 'touch-ceremony-complete-v1';
  static const _osRngDomain = 'os-rng-v1';

  Uint8List _state = Uint8List(stateSize);
  int _counter = 0;
  int _ceremonyId = 0;
  int _touchSamples = 0;
  bool _ceremonyActive = false;
  bool _ceremonyComplete = false;

  /// Starts a new human-entropy session while retaining all prior pool state.
  ///
  /// Starting again invalidates any unconsumed completion from an older
  /// ceremony, so a completed gesture cannot be reused for a later attempt.
  void beginTouchCeremony() {
    _ceremonyId++;
    _touchSamples = 0;
    _ceremonyActive = true;
    _ceremonyComplete = false;
    _mixInternal(_touchBeginDomain, _encodeU64(_ceremonyId));
  }

  /// Mixes one serialized pointer sample into the active ceremony.
  void mixTouchSample(Uint8List data) {
    if (!_ceremonyActive || _ceremonyComplete) {
      throw TouchEntropyCeremonyStateException(
        'Touch entropy requires an active, incomplete ceremony',
      );
    }
    if (data.isEmpty) {
      throw ArgumentError.value(data, 'data', 'must not be empty');
    }

    _mixInternal(_touchSampleDomain, data);
    _touchSamples++;
  }

  /// Marks the active ceremony ready for one extraction.
  void completeTouchCeremony() {
    if (!_ceremonyActive || _ceremonyComplete) {
      throw TouchEntropyCeremonyStateException(
        'No active touch entropy ceremony can be completed',
      );
    }
    if (_touchSamples < requiredTouchSamples) {
      throw TouchEntropyCeremonyIncompleteException(
        collected: _touchSamples,
        required: requiredTouchSamples,
      );
    }

    _mixInternal(_touchCompleteDomain, _encodeU64(_touchSamples));
    _ceremonyActive = false;
    _ceremonyComplete = true;
  }

  /// Mixes fresh [osEntropy] and returns [length] bytes in one transaction.
  ///
  /// The completed touch ceremony is consumed only after successful
  /// extraction. There is no fallback when either required input is absent.
  Uint8List extractWithOsEntropy(Uint8List osEntropy, int length) {
    if (length <= 0 || length > maxExtractBytes) {
      throw ArgumentError.value(
        length,
        'length',
        'must be between 1 and $maxExtractBytes bytes',
      );
    }
    if (!_ceremonyComplete) {
      throw EntropyPoolNotReadyException(
        'A completed touch entropy ceremony is required',
      );
    }
    if (osEntropy.length < minOsEntropyBytes) {
      throw OsEntropyTooShortException(osEntropy.length);
    }

    _mixInternal(_osRngDomain, osEntropy);

    final input = BytesBuilder(copy: false)
      ..add(_encodeU64(_counter++))
      ..add(_state);
    final buffer = input.takeBytes();
    final digest = Uint8List.fromList(sha512.convert(buffer).bytes);
    _zero(buffer);

    final output = Uint8List.fromList(digest.sublist(0, length));
    _replaceState(digest);
    _zero(digest);

    _ceremonyComplete = false;
    _touchSamples = 0;
    return output;
  }

  void _mixInternal(String domain, Uint8List data) {
    final domainBytes = Uint8List.fromList(utf8.encode(domain));
    final input = BytesBuilder(copy: false)
      ..add(_encodeU64(domainBytes.length))
      ..add(domainBytes)
      ..add(_encodeU64(_counter++))
      ..add(_encodeU64(data.length))
      ..add(data)
      ..add(_state);
    final buffer = input.takeBytes();
    final digest = Uint8List.fromList(sha512.convert(buffer).bytes);
    _zero(buffer);

    _replaceState(digest);
    _zero(digest);
  }

  void _replaceState(Uint8List digest) {
    assert(digest.length == 64);
    final oldState = _state;
    _state = Uint8List.fromList(digest.sublist(stateSize));
    _zero(oldState);
  }

  static void _zero(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  static Uint8List _encodeU64(int value) {
    final bytes = Uint8List(8);
    ByteData.view(bytes.buffer).setUint64(0, value);
    return bytes;
  }
}

class EntropyPoolNotReadyException extends BullException {
  EntropyPoolNotReadyException(super.message);
}

class TouchEntropyCeremonyStateException extends BullException {
  TouchEntropyCeremonyStateException(super.message);
}

class TouchEntropyCeremonyIncompleteException extends BullException {
  TouchEntropyCeremonyIncompleteException({
    required int collected,
    required int required,
  }) : super(
         'Touch entropy ceremony has $collected samples; '
         '$required are required',
       );
}

class OsEntropyTooShortException extends BullException {
  OsEntropyTooShortException(int length)
    : super(
        'Operating-system entropy source delivered $length bytes; '
        'minimum is ${EntropyPool.minOsEntropyBytes}',
      );
}
