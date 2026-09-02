import 'dart:convert';

import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_metadata_snapshot_codec.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/portable_settings_fixture.dart';

void main() {
  const codec = WalletMetadataSnapshotCodec();

  test('pins canonical protected-data format v1', () {
    final snapshot = WalletMetadataSnapshot(
      labels: const [
        WalletMetadataLabel(
          type: LabelType.address,
          reference: 'bc1qexample',
          label: 'Savings',
          origin: 'user',
        ),
      ],
      frozenOutpoints: [
        FrozenWalletOutpoint(walletId: 'wallet-1', txId: 'a' * 64, vout: 2),
      ],
      walletPreferences: [
        WalletPreferences(walletRef: 'wallet-1', hideOnHome: true),
      ],
      settings: portableSettingsFixture(),
    );

    final encoded = codec.encode(snapshot);

    expect(
      encoded,
      '{"version":1,"labels":[{"type":"addr","reference":"bc1qexample",'
      '"label":"Savings","origin":"user"}],"frozenOutpoints":['
      '{"walletRef":"wallet-1","txid":"${'a' * 64}","vout":2}],'
      '"walletPreferences":[{"walletRef":"wallet-1","hideOnHome":true}],'
      '"settings":{"bitcoinUnit":"sats","fiatCurrency":"USD",'
      '"language":"unitedStatesEnglish","theme":"dark","hideAmounts":true,'
      '"autoswap":{"enabled":false,"balanceThresholdSats":1000000,'
      '"triggerBalanceSats":2000000,"feeThresholdPercent":3.0,'
      '"alwaysBlock":false,"recipientWalletRef":null},"electrum":['
      '{"network":"bitcoinMainnet","customServers":[],"validateDomain":true,'
      '"stopGap":20,"timeout":10,"retry":3},{"network":"bitcoinTestnet",'
      '"customServers":[],"validateDomain":true,"stopGap":20,"timeout":10,'
      '"retry":3},{"network":"liquidMainnet","customServers":[],'
      '"validateDomain":true,"stopGap":20,"timeout":10,"retry":3},'
      '{"network":"liquidTestnet","customServers":[],"validateDomain":true,'
      '"stopGap":20,"timeout":10,"retry":3}],"mempool":['
      '{"network":"bitcoinMainnet","customServer":null,'
      '"useForFeeEstimation":true},{"network":"bitcoinTestnet",'
      '"customServer":null,"useForFeeEstimation":true},'
      '{"network":"liquidMainnet","customServer":null,'
      '"useForFeeEstimation":true},{"network":"liquidTestnet",'
      '"customServer":null,"useForFeeEstimation":true}],"payjoin":'
      '{"enabled":false,"minimumAmountSats":10000,'
      '"sessionLifetimeSeconds":86400}}}',
    );
    expect(codec.encode(codec.decode(encoded)), encoded);
    expect(
      encoded,
      isNot(
        anyOf([
          contains('useTorProxy'),
          contains('torProxyPort'),
          contains('isSuperuser'),
          contains('isDevModeEnabled'),
          contains('isErrorReportingEnabled'),
          contains('exchangeTestnetBasicAuth'),
          contains('blockTillNextExecution'),
          contains('showWarning'),
        ]),
      ),
    );
  });

  test('accepts conventional JSON whitespace', () {
    final canonical = codec.encode(
      WalletMetadataSnapshot(
        labels: const [],
        frozenOutpoints: const [],
        walletPreferences: const [],
        settings: portableSettingsFixture(),
      ),
    );
    final formatted = const JsonEncoder.withIndent(
      '  ',
    ).convert(jsonDecode(canonical));

    expect(codec.decode('$formatted\n'), isA<WalletMetadataSnapshot>());
  });

  test('rejects unsupported, duplicate, and unknown data', () {
    expect(
      () => codec.decode(
        '{"version":2,"labels":[],"frozenOutpoints":[],'
        '"walletPreferences":[],"settings":{}}',
      ),
      throwsFormatException,
    );
    expect(
      () => codec.decode(
        '{"version":1,"labels":[{"type":"addr","reference":"x",'
        '"label":"same"},{"type":"tx","reference":"x",'
        '"label":"same"}],"frozenOutpoints":[],"walletPreferences":[],'
        '"settings":{}}',
      ),
      throwsFormatException,
    );
    expect(
      () => codec.decode(
        '{"version":1,"labels":[],"frozenOutpoints":[],'
        '"walletPreferences":[{"walletRef":"","hideOnHome":true}],'
        '"settings":{}}',
      ),
      throwsFormatException,
    );
    expect(
      () => codec.decode(
        '{"version":1,"labels":[],"frozenOutpoints":['
        '{"walletRef":"wallet-1","txid":"invalid","vout":0}],'
        '"walletPreferences":[],"settings":{}}',
      ),
      throwsFormatException,
    );
  });
}
