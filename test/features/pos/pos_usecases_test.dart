import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/pos/application/ports/merchant_key_provider_port.dart';
import 'package:bb_mobile/features/pos/application/ports/nostr_relay_pool_port.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_settlement_descriptor_port.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_storage_port.dart';
import 'package:bb_mobile/features/pos/application/pos_cashier_config.dart';
import 'package:bb_mobile/features/pos/application/usecases/init_pos_usecase.dart';
import 'package:bb_mobile/features/pos/application/usecases/pair_terminal_usecase.dart';
import 'package:bb_mobile/features/pos/application/usecases/publish_pos_profile_usecase.dart';
import 'package:bb_mobile/features/pos/application/usecases/revoke_terminal_usecase.dart';
import 'package:bb_mobile/features/pos/application/usecases/watch_sales_usecase.dart';
import 'package:bb_mobile/features/pos/domain/pos_domain_error.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/authorized_terminal.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_identity.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_network.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_profile_settings.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_ref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_pos/nostr_pos_io.dart' as nostr;

void main() {
  final merchantPrivkey = '01' * 32;
  final recoveryPrivkey = '02' * 32;
  final keys = PosMerchantKeys(
    merchantPrivkey: merchantPrivkey,
    merchantPubkey: nostr.publicKeyFromPrivateKey(merchantPrivkey),
    recoveryPrivkey: recoveryPrivkey,
    recoveryPubkey: nostr.publicKeyFromPrivateKey(recoveryPrivkey),
  );

  test('initializes and persists a POS bound to a Liquid wallet', () async {
    final storage = _MemoryPosStorage();
    final usecase = InitPosUsecase(
      keyProvider: _StaticKeyProvider(keys),
      storage: storage,
    );

    final identity = await usecase.execute(
      liquidWallet: _wallet(network: Network.liquidTestnet),
      settings: const PosProfileSettings(name: 'Corner Shop', currency: 'CAD'),
    );

    expect(identity.ref.merchantPubkey, keys.merchantPubkey);
    expect(identity.recoveryPubkey, keys.recoveryPubkey);
    expect(identity.masterFingerprint, 'f23f9fd2');
    expect(identity.walletId, 'wallet-liquidTestnet');
    expect(identity.network, PosNetwork.testnet);
    expect(identity.name, 'Corner Shop');
    expect(identity.currency, 'CAD');
    expect(await storage.getProfile(identity.ref), identity);
  });

  test('rejects non-Liquid wallets during POS initialization', () async {
    final usecase = InitPosUsecase(
      keyProvider: _StaticKeyProvider(keys),
      storage: _MemoryPosStorage(),
    );

    expect(
      () => usecase.execute(
        liquidWallet: _wallet(network: Network.bitcoinMainnet),
        settings: const PosProfileSettings(name: 'BTC Shop', currency: 'CAD'),
      ),
      throwsArgumentError,
    );
  });

  test('publishes a network-aware profile and cashier URL', () async {
    final relayPool = _CapturingRelayPool(accepted: true);
    final usecase = PublishPosProfileUsecase(
      keyProvider: _StaticKeyProvider(keys),
      relayPool: relayPool,
      cashierConfig: const PosCashierConfig(),
    );
    final identity = _identity(keys, network: PosNetwork.testnet);

    final result = await usecase.execute(
      identity,
      cashierBaseUrl: 'https://cashier.example',
    );

    expect(result.acceptedRelays, 1);
    expect(result.event.pubkey, keys.merchantPubkey);
    expect(result.event.kind, nostr.NostrPosKinds.posProfile);
    expect(result.event.tags, contains(equals(['network', 'liquid-testnet'])));
    expect(result.event.tags, contains(equals(['d', identity.ref.posId])));
    final payload = jsonDecode(result.event.content) as Map<String, Object?>;
    expect(
      (payload['swap_providers'] as List).first,
      containsPair('api_base', 'https://api.testnet.boltz.exchange'),
    );
    expect(result.cashierUrl, startsWith('https://cashier.example'));
    expect(relayPool.published.single.id, result.event.id);
  });

  test(
    'threads POS payment-method settings to the profile wire payload',
    () async {
      final relayPool = _CapturingRelayPool(accepted: true);
      final usecase = PublishPosProfileUsecase(
        keyProvider: _StaticKeyProvider(keys),
        relayPool: relayPool,
        cashierConfig: const PosCashierConfig(),
      );
      final identity = _identity(
        keys,
        paymentMethods: const nostr.PosPaymentMethods(
          liquid: true,
          lightningSwap: false,
          boltCard: false,
        ),
      );

      final result = await usecase.execute(identity);
      final payload = jsonDecode(result.event.content) as Map<String, Object?>;

      expect(result.event.tags, contains(equals(['method', 'liquid'])));
      expect(
        result.event.tags,
        isNot(contains(equals(['method', 'lightning_via_swap']))),
      );
      expect(payload['methods'] as List, hasLength(1));
    },
  );

  test('fails profile publishing when no relay accepts the event', () async {
    final usecase = PublishPosProfileUsecase(
      keyProvider: _StaticKeyProvider(keys),
      relayPool: _CapturingRelayPool(accepted: false),
      cashierConfig: const PosCashierConfig(),
    );

    expect(
      () => usecase.execute(_identity(keys)),
      throwsA(isA<PosRelayQuorumFailure>()),
    );
  });

  test(
    'sales watcher queries privacy bucket tags for active terminals',
    () async {
      final storage = _MemoryPosStorage();
      final relayPool = _CapturingRelayPool(accepted: true);
      final identity = _identity(keys);
      final terminalPubkey = nostr.publicKeyFromPrivateKey('03' * 32);
      await storage.saveProfile(identity);
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final effectiveDay = nostr.epochDayFromUnix(nowSeconds);
      await storage.saveAuthorizedTerminal(
        terminal: AuthorizedTerminal(
          posRef: identity.ref,
          terminalPubkey: terminalPubkey,
          terminalId: '04' * 16,
          ctDescriptorRef: 'ctd-ref',
          saleBucketSecretRef: 'bucket-ref',
          saleBucketGeneration: 1,
          effectiveFromEpochDay: effectiveDay,
          terminalIndex: 0,
          authorizedAt: DateTime.now(),
        ),
        ctDescriptor: 'ct-descriptor',
        saleBucketSecret: '05' * 32,
      );
      final usecase = WatchSalesUsecase(
        keyProvider: _StaticKeyProvider(keys),
        relayPool: relayPool,
        storage: storage,
      );

      await usecase.execute(ref: identity.ref, since: nowSeconds);

      final filter = relayPool.queries.single;
      expect(filter, isNot(contains('#a')));
      expect(filter['#x'], isA<List<String>>());
      expect(filter['#x'] as List<String>, isNotEmpty);
      expect(filter['since'], nowSeconds);
    },
  );

  test('pairing approval carries merchant branding and currency', () async {
    final storage = _MemoryPosStorage();
    final identity = _identity(keys, network: PosNetwork.testnet);
    await storage.saveProfile(identity);
    final terminalPrivkey = '03' * 32;
    final announcement = nostr.signNostrPosEvent(
      nostr.buildPairingAnnouncement(
        terminalPubkey: nostr.publicKeyFromPrivateKey(terminalPrivkey),
      ),
      terminalPrivkey,
    );
    final relayPool = _CapturingRelayPool(
      accepted: true,
      pairingAnnouncement: announcement,
    );
    final getWalletUsecase = _MockGetWalletUsecase();
    when(
      () =>
          getWalletUsecase.execute(identity.walletId, sync: any(named: 'sync')),
    ).thenAnswer((_) async => _wallet(network: Network.liquidTestnet));
    final usecase = PairTerminalUsecase(
      keyProvider: _StaticKeyProvider(keys),
      relayPool: relayPool,
      storage: storage,
      descriptorProvider: const _StaticDescriptorProvider(),
      getWalletUsecase: getWalletUsecase,
    );

    await usecase.execute(ref: identity.ref, pairingCode: '4F7G-YJDP');

    final approval = relayPool.published.singleWhere(
      (event) => event.kind == nostr.NostrPosKinds.terminalAuthorization,
    );
    final decrypted = await nostr.nip44DecryptFromPubkey(
      payload: approval.content,
      privateKeyHex: terminalPrivkey,
      publicKeyHex: identity.ref.merchantPubkey,
    );
    final payload = jsonDecode(decrypted) as Map<String, Object?>;
    expect(payload, containsPair('merchant_name', 'Corner Shop'));
    expect(payload, containsPair('currency', 'CAD'));
    expect(
      (payload['swap_providers'] as List).first,
      containsPair('supports_covenants', false),
    );
  });

  test('revokes a terminal using its opaque terminal id', () async {
    final storage = _MemoryPosStorage();
    final relayPool = _CapturingRelayPool(accepted: true);
    final identity = _identity(keys);
    final terminalPubkey = nostr.publicKeyFromPrivateKey('03' * 32);
    await storage.saveProfile(identity);
    final terminal = AuthorizedTerminal(
      posRef: identity.ref,
      terminalPubkey: terminalPubkey,
      terminalId: '04' * 16,
      ctDescriptorRef: 'ctd-ref',
      saleBucketSecretRef: 'bucket-ref',
      saleBucketGeneration: 1,
      effectiveFromEpochDay: 20000,
      terminalIndex: 0,
      authorizedAt: DateTime.now(),
    );
    await storage.saveAuthorizedTerminal(
      terminal: terminal,
      ctDescriptor: 'ct-descriptor',
      saleBucketSecret: '05' * 32,
    );
    final usecase = RevokeTerminalUsecase(
      keyProvider: _StaticKeyProvider(keys),
      relayPool: relayPool,
      storage: storage,
    );

    await usecase.execute(
      ref: identity.ref,
      terminalPubkey: terminal.terminalPubkey,
    );

    final event = relayPool.published.single;
    expect(event.kind, nostr.NostrPosKinds.terminalRevocation);
    expect(
      event.tags,
      contains(equals(['d', '${identity.ref.posId}:${terminal.terminalId}'])),
    );
    expect(
      event.tags.any((tag) => tag.isNotEmpty && tag.first == 'p'),
      isFalse,
    );
    expect(
      (await storage.listAuthorizedTerminals(identity.ref)).single.isRevoked,
      isTrue,
    );
  });
}

Wallet _wallet({required Network network}) {
  return Wallet(
    origin: 'wallet-${network.name}',
    network: network,
    masterFingerprint: 'f23f9fd2',
    xpubFingerprint: 'f23f9fd2',
    scriptType: ScriptType.bip84,
    xpub: 'xpub-placeholder',
    externalPublicDescriptor: 'ct(slip77-placeholder,elwpkh(xpub/0/*))',
    internalPublicDescriptor: 'ct(slip77-placeholder,elwpkh(xpub/1/*))',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );
}

PosIdentity _identity(
  PosMerchantKeys keys, {
  PosNetwork network = PosNetwork.mainnet,
  nostr.PosPaymentMethods paymentMethods = nostr.PosPaymentMethods.all,
}) {
  return PosIdentity(
    ref: PosRef(merchantPubkey: keys.merchantPubkey, posId: 'pos-test'),
    walletId: 'wallet-${network.name}',
    masterFingerprint: 'f23f9fd2',
    recoveryPubkey: keys.recoveryPubkey,
    relays: const ['wss://relay.example'],
    network: network,
    name: 'Corner Shop',
    currency: 'CAD',
    createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    paymentMethods: paymentMethods,
  );
}

class _StaticKeyProvider implements MerchantKeyProviderPort {
  const _StaticKeyProvider(this.keys);

  final PosMerchantKeys keys;

  @override
  Future<PosMerchantKeys> derive(String masterFingerprint) async => keys;
}

class _CapturingRelayPool implements NostrRelayPoolPort {
  _CapturingRelayPool({required this.accepted, this.pairingAnnouncement});

  final bool accepted;
  final nostr.NostrPosEvent? pairingAnnouncement;
  final published = <nostr.NostrPosEvent>[];
  final queries = <Map<String, Object?>>[];

  @override
  Future<List<nostr.RelayPublishResult>> publish({
    required List<String> relays,
    required nostr.NostrPosEvent event,
  }) async {
    published.add(event);
    return [
      nostr.RelayPublishResult(
        relay: relays.first,
        ok: accepted,
        message: accepted ? null : 'rejected',
      ),
    ];
  }

  @override
  Future<List<nostr.NostrPosEvent>> query({
    required List<String> relays,
    required Map<String, Object?> filter,
  }) async {
    queries.add(filter);
    return const [];
  }

  @override
  Future<nostr.NostrPosEvent?> findPairingAnnouncement({
    required List<String> relays,
    required String pairingCode,
  }) async {
    return pairingAnnouncement;
  }

  @override
  Future<List<nostr.NostrPosEvent>> fetchSwapRecoveryBackups({
    required List<String> relays,
    required String recoveryPubkey,
    required String recoveryPrivkey,
  }) async {
    return const [];
  }

  @override
  Future<List<nostr.RelayPublishResult>> publishSwapRecoveryBackup({
    required List<String> relays,
    required nostr.NostrPosEvent recoveryEvent,
    required String recoveryPubkey,
    required String recoveryPrivkey,
  }) async {
    published.add(recoveryEvent);
    return [
      nostr.RelayPublishResult(
        relay: relays.first,
        ok: accepted,
        message: accepted ? null : 'rejected',
      ),
    ];
  }
}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _StaticDescriptorProvider implements PosSettlementDescriptorPort {
  const _StaticDescriptorProvider();

  @override
  Future<PosSettlementDescriptor> descriptorForTerminal({
    required Wallet wallet,
    required int terminalIndex,
  }) async {
    return const PosSettlementDescriptor(
      ctDescriptor: 'ct-descriptor',
      descriptorFingerprint: 'fingerprint',
      terminalBranch: 0,
    );
  }
}

class _MemoryPosStorage implements PosStoragePort {
  final profiles = <PosRef, PosIdentity>{};
  final terminals = <PosRef, List<AuthorizedTerminal>>{};
  final bucketSecrets = <String, String>{};
  final events = <PosRef, List<nostr.NostrPosEvent>>{};

  @override
  Future<void> saveProfile(PosIdentity identity) async {
    profiles[identity.ref] = identity;
  }

  @override
  Future<List<PosIdentity>> listProfiles() async => profiles.values.toList();

  @override
  Future<PosIdentity?> getProfile(PosRef ref) async => profiles[ref];

  @override
  Future<PosIdentity?> getLatestProfile() async {
    if (profiles.isEmpty) return null;
    return profiles.values.last;
  }

  @override
  Future<int> nextTerminalIndex(PosRef ref) async {
    return terminals[ref]?.length ?? 0;
  }

  @override
  Future<void> saveAuthorizedTerminal({
    required AuthorizedTerminal terminal,
    required String ctDescriptor,
    required String saleBucketSecret,
  }) async {
    terminals.putIfAbsent(terminal.posRef, () => []).add(terminal);
    bucketSecrets[terminal.saleBucketSecretRef] = saleBucketSecret;
  }

  @override
  Future<List<AuthorizedTerminal>> listAuthorizedTerminals(PosRef ref) async {
    return terminals[ref] ?? const [];
  }

  @override
  Future<String?> readTerminalDescriptor(AuthorizedTerminal terminal) async {
    return 'ct-descriptor';
  }

  @override
  Future<String?> readTerminalSaleBucketSecret(
    AuthorizedTerminal terminal,
  ) async {
    return bucketSecrets[terminal.saleBucketSecretRef];
  }

  @override
  Future<void> markTerminalRevoked({
    required PosRef ref,
    required String terminalPubkey,
    required DateTime revokedAt,
  }) async {
    final items = terminals[ref];
    if (items == null) return;
    final index = items.indexWhere(
      (item) => item.terminalPubkey == terminalPubkey,
    );
    if (index == -1) return;
    final current = items[index];
    items[index] = AuthorizedTerminal(
      posRef: current.posRef,
      terminalPubkey: current.terminalPubkey,
      terminalId: current.terminalId,
      ctDescriptorRef: current.ctDescriptorRef,
      saleBucketSecretRef: current.saleBucketSecretRef,
      saleBucketGeneration: current.saleBucketGeneration,
      effectiveFromEpochDay: current.effectiveFromEpochDay,
      terminalIndex: current.terminalIndex,
      authorizedAt: current.authorizedAt,
      revokedAt: revokedAt,
    );
  }

  @override
  Future<void> appendObservedEvents({
    required PosRef ref,
    required Iterable<nostr.NostrPosEvent> events,
  }) async {
    this.events.putIfAbsent(ref, () => []).addAll(events);
  }

  @override
  Future<List<nostr.NostrPosEvent>> listObservedEvents(PosRef ref) async {
    return events[ref] ?? const [];
  }
}
