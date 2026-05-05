import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/pos/application/ports/merchant_key_provider_port.dart';
import 'package:bb_mobile/features/pos/application/ports/nostr_relay_pool_port.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_settlement_descriptor_port.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_storage_port.dart';
import 'package:bb_mobile/features/pos/domain/pos_domain_error.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/authorized_terminal.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_ref.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

class PairTerminalUsecase {
  PairTerminalUsecase({
    required MerchantKeyProviderPort keyProvider,
    required NostrRelayPoolPort relayPool,
    required PosStoragePort storage,
    required PosSettlementDescriptorPort descriptorProvider,
    required GetWalletUsecase getWalletUsecase,
  }) : _keyProvider = keyProvider,
       _relayPool = relayPool,
       _storage = storage,
       _descriptorProvider = descriptorProvider,
       _getWalletUsecase = getWalletUsecase;

  final MerchantKeyProviderPort _keyProvider;
  final NostrRelayPoolPort _relayPool;
  final PosStoragePort _storage;
  final PosSettlementDescriptorPort _descriptorProvider;
  final GetWalletUsecase _getWalletUsecase;

  Future<AuthorizedTerminal> execute({
    required PosRef ref,
    required String pairingCode,
    String terminalName = 'Cashier terminal',
  }) async {
    final identity = await _storage.getProfile(ref);
    if (identity == null) throw StateError('POS profile not found.');
    final announcement = await _relayPool.findPairingAnnouncement(
      relays: identity.relays,
      pairingCode: pairingCode,
    );
    if (announcement == null) throw const PosPairingTimeout();

    final wallet = await _getWalletUsecase.execute(identity.walletId);
    if (wallet == null) throw StateError('Bound Liquid wallet not found.');
    final terminalIndex = await _storage.nextTerminalIndex(ref);
    final descriptor = await _descriptorProvider.descriptorForTerminal(
      wallet: wallet,
      terminalIndex: terminalIndex,
    );
    final keys = await _keyProvider.derive(identity.masterFingerprint);
    final material = nostr.TerminalAuthorizationMaterial.create();
    final authorization = nostr.TerminalAuthorization(
      posRef: ref.nostrAddress,
      terminalPubkey: announcement.pubkey,
      terminalId: material.terminalId,
      terminalName: terminalName,
      pairingCodeHint: pairingCode,
      ctDescriptor: descriptor.ctDescriptor,
      descriptorFingerprint: descriptor.descriptorFingerprint,
      terminalBranch: descriptor.terminalBranch,
      merchantRecoveryPubkey: keys.recoveryPubkey,
      saleBucketSecret: material.saleBucketSecret,
      saleBucketGeneration: material.saleBucketGeneration,
      effectiveFromEpochDay: material.effectiveFromEpochDay,
      expiresAt: material.expiresAt,
      network: identity.network.sdkNetwork,
      serviceConfig: identity.network.sdkServiceConfig,
      paymentMethods: identity.paymentMethods,
      limits: const nostr.PosTerminalLimits(supportsCovenants: false),
      merchantName: identity.name,
      currency: identity.currency,
    );
    final signed = await nostr.buildSignedTerminalAuthorizationEvent(
      authorization: authorization,
      merchantPubkey: ref.merchantPubkey,
      posId: ref.posId,
      merchantPrivkey: keys.merchantPrivkey,
      terminalPubkey: announcement.pubkey,
    );
    final results = await _relayPool.publish(
      relays: identity.relays,
      event: signed,
    );
    final accepted = results.where((result) => result.ok).length;
    if (accepted == 0) {
      throw PosRelayQuorumFailure(reached: accepted, required: 1);
    }

    final terminal = AuthorizedTerminal(
      posRef: ref,
      terminalPubkey: announcement.pubkey,
      terminalId: material.terminalId,
      ctDescriptorRef: _descriptorKey(ref, announcement.pubkey),
      saleBucketSecretRef: _bucketSecretKey(ref, material.terminalId),
      saleBucketGeneration: material.saleBucketGeneration,
      effectiveFromEpochDay: material.effectiveFromEpochDay,
      terminalIndex: terminalIndex,
      authorizedAt: DateTime.now(),
    );
    await _storage.saveAuthorizedTerminal(
      terminal: terminal,
      ctDescriptor: descriptor.ctDescriptor,
      saleBucketSecret: material.saleBucketSecret,
    );
    await _storage.appendObservedEvents(
      ref: ref,
      events: [announcement, signed],
    );
    return terminal;
  }

  String _descriptorKey(PosRef ref, String terminalPubkey) {
    return 'pos_ctd:${ref.merchantPubkey}:${ref.posId}:$terminalPubkey';
  }

  String _bucketSecretKey(PosRef ref, String terminalId) {
    return 'pos_bucket:${ref.merchantPubkey}:${ref.posId}:$terminalId';
  }
}
