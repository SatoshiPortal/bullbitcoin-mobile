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
    final recoveries = nostr.swapRecoveriesFromEvents(recoveryEvents);
    final executor = nostr.ControllerRecoveryExecutor(
      swapStatusClient: nostr.BoltzSwapStatusClient(
        apiBase: identity.network.sdkNetwork.boltzApiBase,
      ),
      liquidClient: nostr.LiquidTransactionClient(
        apiBase: identity.network.sdkNetwork.liquidEsploraApiBase,
      ),
      claimBuilder: _claimBuilderFactory(identity.network),
    );
    return executor.recoverClaims(
      recoveries,
      terminalId: terminalId,
      feeSatPerVbyte: feeSatPerVbyte,
    );
  }
}
