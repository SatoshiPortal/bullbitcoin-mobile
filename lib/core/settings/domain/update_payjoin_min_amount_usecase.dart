import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

/// Persists the minimum receive amount below which a payjoin is not offered
/// (the sender falls back to a normal transaction). A higher threshold raises
/// the stake a probing sender must risk per attempt; see the receiver-side
/// UTXO probing attack (BIP78).
class UpdatePayjoinMinAmountUsecase {
  final SettingsRepository _settingsRepository;

  UpdatePayjoinMinAmountUsecase({required this._settingsRepository});

  Future<void> execute({required int payjoinMinAmountSat}) async {
    await _settingsRepository.setPayjoinMinAmountSat(payjoinMinAmountSat);
  }
}
