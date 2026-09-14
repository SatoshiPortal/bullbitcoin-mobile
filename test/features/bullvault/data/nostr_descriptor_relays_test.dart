import 'package:bb_mobile/core/nostr/nostr_relay_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/nostr_descriptor_relays.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the configured relays are reviewed, canonical wss endpoints', () {
    expect(NostrDescriptorRelays.configured, hasLength(4));
    expect(NostrDescriptorRelays.configured.map((relay) => relay.toString()), [
      'wss://relay.damus.io',
      'wss://nos.lol',
      'wss://relay.primal.net',
      'wss://relay.nostr.band',
    ]);
    for (final relay in NostrDescriptorRelays.configured) {
      expect(relay.scheme, 'wss');
      // The transport applies the same rule again before it connects.
      NostrDescriptorRelays.parse(relay.toString());
      NostrRelayDatasource.validateRelay(relay);
    }
    expect(
      () => NostrDescriptorRelays.configured.add(Uri.parse('wss://other')),
      throwsUnsupportedError,
    );
  });

  test('canonicalization folds case, the default port and a bare slash', () {
    expect(
      NostrDescriptorRelays.parse('  WSS://Relay.Example:443/  ').toString(),
      'wss://relay.example',
    );
    expect(
      NostrDescriptorRelays.parse('wss://relay.example'),
      NostrDescriptorRelays.parse('WSS://RELAY.EXAMPLE/'),
    );
  });

  test('a non-default port and a path are part of the relay identity', () {
    expect(
      NostrDescriptorRelays.parse('wss://relay.example:444').toString(),
      'wss://relay.example:444',
    );
    expect(
      NostrDescriptorRelays.parse('wss://relay.example:444'),
      isNot(NostrDescriptorRelays.parse('wss://relay.example')),
    );
    expect(
      NostrDescriptorRelays.parse('wss://relay.example/inbox').toString(),
      'wss://relay.example/inbox',
    );
  });

  test('duplicates survive neither spelling nor the constant list', () {
    expect({
      NostrDescriptorRelays.parse('wss://relay.example'),
      NostrDescriptorRelays.parse('wss://Relay.Example:443/'),
    }, hasLength(1));
    expect(
      NostrDescriptorRelays.urls.toSet(),
      hasLength(NostrDescriptorRelays.urls.length),
    );
  });

  test('anything that is not a plain wss endpoint is refused', () {
    for (final value in const [
      'ws://relay.example',
      'https://relay.example',
      'wss://relay.example?token=secret',
      'wss://relay.example#vault',
      'wss://user:pass@relay.example',
      'wss://',
      'relay.example',
      '',
      '   ',
      'not a url at all',
    ]) {
      expect(
        () => NostrDescriptorRelays.parse(value),
        throwsFormatException,
        reason: value,
      );
    }
  });
}
