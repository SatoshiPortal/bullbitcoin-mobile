import 'package:bb_mobile/features/pos/application/ports/merchant_key_provider_port.dart';
import 'package:bb_mobile/features/pos/application/ports/nostr_relay_pool_port.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_storage_port.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_network.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_ref.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

typedef PosRecoveryClaimBuilderFactory =
    nostr.RecoveryClaimBuilder Function(PosNetwork network);

class RunSwapRecoveryUsecase {
  RunSwapRecoveryUsecase({
    required MerchantKeyProviderPort keyProvider,
    required NostrRelayPoolPort relayPool,
    required PosStoragePort storage,
    required PosRecoveryClaimBuilderFactory claimBuilderFactory,
  }) : _keyProvider = keyProvider,
       _relayPool = relayPool,
       _storage = storage,
       _claimBuilderFactory = claimBuilderFactory;

  final MerchantKeyProviderPort _keyProvider;
  final NostrRelayPoolPort _relayPool;
  final PosStoragePort _storage;
  final PosRecoveryClaimBuilderFactory _claimBuilderFactory;

  Future<List<nostr.ControllerRecoveryResult>> execute({
    required PosRef ref,
    String? terminalId,
    double? feeSatPerVbyte,
  }) async {
    final identity = await _storage.getProfile(ref);
    if (identity == null) throw StateError('POS profile not found.');
    final keys = await _keyProvider.derive(identity.masterFingerprint);
    final recoveryEvents = await _relayPool.fetchSwapRecoveryBackups(
      relays: identity.relays,
      recoveryPubkey: keys.recoveryPubkey,
      recoveryPrivkey: keys.recoveryPrivkey,
    );
    await _storage.appendObservedEvents(ref: ref, events: recoveryEvents);
    final observedEvents = await _storage.listObservedEvents(ref);
    final recoveries = nostr.swapRecoveriesFromEvents(observedEvents);
    final executor = nostr.ControllerRecoveryExecutor(
      swapStatusClient: nostr.BoltzSwapStatusClient(
        apiBase: identity.network.sdkNetwork.boltzApiBase,
        webSocketUrl: identity.network.sdkNetwork.boltzWebSocketUrl,
        webSocketTimeout: const Duration(seconds: 20),
      ),
      liquidClient: nostr.LiquidTransactionClient(
        apiBase: identity.network.sdkNetwork.liquidEsploraApiBase,
      ),
      claimBuilder: _claimBuilderFactory(identity.network),
    );
    final results = await executor.recoverClaims(
      recoveries,
      terminalId: terminalId,
      feeSatPerVbyte: feeSatPerVbyte,
      lockupPollTimeout: const Duration(seconds: 60),
      lockupPollInterval: const Duration(seconds: 5),
    );
    await _appendLocalRecoveryCompletionEvents(
      ref: ref,
      relays: identity.relays,
      recoveryPubkey: keys.recoveryPubkey,
      recoveryPrivkey: keys.recoveryPrivkey,
      recoveries: recoveries,
      results: results,
      feeSatPerVbyte: feeSatPerVbyte,
    );
    return results;
  }

  Future<void> _appendLocalRecoveryCompletionEvents({
    required PosRef ref,
    required List<String> relays,
    required String recoveryPubkey,
    required String recoveryPrivkey,
    required List<nostr.SwapRecoverySummary> recoveries,
    required List<nostr.ControllerRecoveryResult> results,
    required double? feeSatPerVbyte,
  }) async {
    final bySwapId = {
      for (final recovery in recoveries) recovery.swapId: recovery,
    };
    final terminals = await _storage.listAuthorizedTerminals(ref);
    final terminalPubkeysById = {
      for (final terminal in terminals)
        terminal.terminalId: terminal.terminalPubkey,
    };
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final events = <nostr.NostrPosEvent>[];
    for (final result in results) {
      final recovery = bySwapId[result.swapId];
      if (recovery == null) continue;
      final claimTxid = result.claimTxid ?? recovery.claimTxid;
      if (claimTxid == null || claimTxid.isEmpty) continue;
      if (result.status != 'broadcast' && result.status != 'already_claimed') {
        continue;
      }
      final terminalPubkey = recovery.terminalId == null
          ? null
          : terminalPubkeysById[recovery.terminalId!];
      final event = nostr.buildUnsignedEvent(
        pubkey: terminalPubkey ?? recoveryPubkey,
        kind: nostr.NostrPosKinds.swapRecoveryBackup,
        tags: [
          ['sale', recovery.saleId],
          ['swap', recovery.swapId],
        ],
        createdAt: now,
        content: {
          'sale_id': recovery.saleId,
          'payment_attempt_id': recovery.paymentAttemptId,
          'swap_id': recovery.swapId,
          'terminal_id': recovery.terminalId,
          'encrypted_local_blob': recovery.encryptedLocalBlob,
          'expires_at': recovery.expiresAt,
          'lockup_txid': recovery.lockupTxid,
          'lockup_tx_hex': recovery.lockupTxHex,
          'claim': {
            'mode': 'standard',
            'claim_tx_hex': recovery.claimTxHex,
            'claim_txid': claimTxid,
            'replaced_claim_txids': recovery.replacedClaimTxids,
            'claim_prepared_at': null,
            'claim_broadcast_at': now,
            'claim_confirmed_at': null,
            'claim_fee_sat_per_vbyte': feeSatPerVbyte,
            'claim_rbf_count': 0,
          },
        },
      );
      events.add(event);
      await _relayPool.publishSwapRecoveryBackup(
        relays: relays,
        recoveryEvent: event,
        recoveryPubkey: recoveryPubkey,
        recoveryPrivkey: recoveryPrivkey,
      );
    }
    if (events.isNotEmpty) {
      await _storage.appendObservedEvents(ref: ref, events: events);
    }
  }
}
