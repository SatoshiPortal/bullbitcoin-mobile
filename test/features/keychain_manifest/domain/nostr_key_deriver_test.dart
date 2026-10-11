import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart' as nostr;

void main() {
  const publicKeyVector =
      'c071c9b02afd19a9d9b240ea9eed3f8ba80f89474953b752471f3d006b63a332';
  final time = DateTime.utc(2026, 9, 18);
  NostrKeyRecord record({
    String? publicKey,
    int identity = 1,
    String purpose = 'Personal identity',
    String description = 'Fixture',
  }) => NostrKeyRecord(
    parentFingerprint: '73c5da0a',
    identity: identity,
    publicKey: publicKey ?? publicKeyVector,
    purpose: purpose,
    description: description,
    createdAt: time,
    updatedAt: time,
  );

  test('public keys use the NIP-19 npub encoding', () {
    final key = record();
    final encoded = NostrKeyDeriver.encodePublicKey(key.publicKey);
    expect(nostr.Bech32Entity.decode(payload: encoded).data, key.publicKey);
    expect(
      nostr.Bech32Entity.decode(payload: encoded).prefix,
      nostr.Nip19Prefix.npub,
    );
  });

  test('names and notes retain the existing form limits', () {
    expect(
      () => record(purpose: 'a' * 80, description: 'b' * 200),
      returnsNormally,
    );
    expect(() => record(purpose: 'a' * 81), throwsFormatException);
    expect(() => record(description: 'b' * 201), throwsFormatException);
    expect(() => record(purpose: 'line\nbreak'), throwsFormatException);
    expect(() => record(description: 'line\nbreak'), throwsFormatException);
  });
}
