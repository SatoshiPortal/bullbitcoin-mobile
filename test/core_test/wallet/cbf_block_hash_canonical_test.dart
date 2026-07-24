import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the exact byte-order contract `DefaultCbfScanTypeResolver`
/// (`cbf_scan_type_resolver.dart`) relies on when it turns a persisted
/// `WalletMetadataModel.birthdayCheckpoint`'s hex `blockHash` string into
/// `bdk.BlockHash.fromString(hex: ...)` for `bdk.BlockId`/
/// `bdk.OtherRecoveryPoint`.
///
/// Exercises the real FFI-backed `bdk.BlockHash` from the pinned dependency
/// (`bull_sdk` git ref `507c54893f561a339b8da787cf9b2e0cd9ab9659` /
/// `bdk_dart` git ref `fbf8952ed7056c9663e4bd47dddc8b4994580532`, see
/// `pubspec.yaml`) — not a fake or a hand-rolled reimplementation — so a
/// future bump of that pin that silently changed `BlockHash`'s byte-order
/// contract would fail here rather than only showing up as a wrong
/// recovery-scan start point at runtime.
///
/// Bitcoin block hashes are conventionally *displayed* (hex strings, RPC
/// output, block explorers) in reversed-byte order relative to how they are
/// serialized on the wire/in a block header (`BlockHash.serialize()` below)
/// — the well-known "block hash endianness" gotcha. This suite pins down
/// both directions of that conversion for the exact `BlockHash` API
/// `CbfScanTypeResolver` and `WalletBirthdayCheckpoint` use.
void main() {
  // 32 sequential bytes (0x00..0x1f) — deterministic and, being
  // non-palindromic, guaranteed to expose a byte-order mistake (unlike an
  // all-zero or symmetric fixture, which a reversal bug could pass anyway).
  final displayHex = List.generate(
    32,
    (i) => i,
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final displayBytes = Uint8List.fromList(hex.decode(displayHex));

  test('displayHex fixture is a well-formed 64-lowercase-hex block hash', () {
    expect(displayHex.length, 64);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(displayHex), isTrue);
  });

  group('bdk.BlockHash canonical round-trip', () {
    test('fromString(hex:) round-trips through toString() back to the exact '
        'same display hex — this is the round trip '
        'CbfScanTypeResolver/WalletBirthdayCheckpoint depend on when a '
        'persisted checkpoint hash is turned into a BlockHash and back', () {
      final blockHash = bdk.BlockHash.fromString(hex: displayHex);

      expect(blockHash.toString(), displayHex);
    });

    test('fromBytes(bytes:) constructed from serialize()\'s own output '
        'round-trips through toString() back to the same display hex', () {
      final original = bdk.BlockHash.fromString(hex: displayHex);
      final roundTripped = bdk.BlockHash.fromBytes(bytes: original.serialize());

      expect(roundTripped.toString(), displayHex);
      expect(roundTripped, original);
    });
  });

  group('bdk.BlockHash endianness', () {
    test('serialize() returns the reversed byte order of the display hex — '
        'the internal/wire byte order is the reverse of how the hash is '
        'displayed, the standard Bitcoin block-hash endianness convention', () {
      final blockHash = bdk.BlockHash.fromString(hex: displayHex);

      final serialized = blockHash.serialize();

      expect(serialized, displayBytes.reversed.toList());
      // Not a no-op check: this fixture is deliberately non-palindromic,
      // so a resolver/serializer that forgot to reverse bytes at all
      // would fail the assertion above rather than passing vacuously.
      expect(serialized, isNot(displayBytes));
    });

    test('fromBytes(bytes:) treats its input as already being in that same '
        'reversed (internal/wire) byte order, not the display order', () {
      final internalOrderBytes = Uint8List.fromList(
        displayBytes.reversed.toList(),
      );

      final blockHash = bdk.BlockHash.fromBytes(bytes: internalOrderBytes);

      expect(blockHash.toString(), displayHex);
    });
  });
}
