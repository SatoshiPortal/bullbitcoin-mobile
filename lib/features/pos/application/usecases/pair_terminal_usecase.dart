import 'dart:math';

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
    final terminalId = _randomHex(bytes: 16);
    final saleBucketSecret = nostr.randomSecretHex();
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final effectiveFromEpochDay = nostr.epochDayFromUnix(nowSeconds);
    final expiresAt = DateTime.now().add(const Duration(days: 365));
    final authorization = nostr.TerminalAuthorization(
      posRef: ref.nostrAddress,
      terminalPubkey: announcement.pubkey,
      terminalId: terminalId,
      terminalName: terminalName,
      pairingCodeHint: pairingCode,
      ctDescriptor: descriptor.ctDescriptor,
      descriptorFingerprint: descriptor.descriptorFingerprint,
      terminalBranch: descriptor.terminalBranch,
      merchantRecoveryPubkey: keys.recoveryPubkey,
      saleBucketSecret: saleBucketSecret,
      saleBucketGeneration: 1,
      effectiveFromEpochDay: effectiveFromEpochDay,
      expiresAt: expiresAt.millisecondsSinceEpoch ~/ 1000,
      network: identity.network.sdkNetwork,
    );
    final unsigned = nostr.buildTerminalAuthorizationEvent(
      merchantPubkey: ref.merchantPubkey,
      posId: ref.posId,
      authorization: authorization,
    );
    final encrypted = await nostr.nip44EncryptToPubkey(
      plaintext: unsigned.content,
      privateKeyHex: keys.merchantPrivkey,
      publicKeyHex: announcement.pubkey,
    );
    final signed = nostr.signNostrPosEvent(
      nostr.replaceEventContent(unsigned, encrypted),
      keys.merchantPrivkey,
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
      terminalId: terminalId,
      ctDescriptorRef: _descriptorKey(ref, announcement.pubkey),
      saleBucketSecretRef: _bucketSecretKey(ref, terminalId),
      saleBucketGeneration: 1,
      effectiveFromEpochDay: effectiveFromEpochDay,
      terminalIndex: terminalIndex,
      authorizedAt: DateTime.now(),
    );
    await _storage.saveAuthorizedTerminal(
      terminal: terminal,
      ctDescriptor: descriptor.ctDescriptor,
      saleBucketSecret: saleBucketSecret,
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

  String _randomHex({required int bytes}) {
    final random = Random.secure();
    return List<int>.generate(
      bytes,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
