import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/scoped_api_key_model.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/scoped_settlement_key_port.dart';

/// The single edge between the fiat-settlement feature and the scoped
/// credential's plaintext. Reads it per environment from the secure exchange
/// datasource; the value never enters cubit/UI state, logs, or analytics.
class ScopedSettlementKeyAdapter implements ScopedSettlementKeyPort {
  final BullbitcoinApiKeyDatasource _datasource;
  final GetSettingsUsecase _getSettings;

  const ScopedSettlementKeyAdapter({
    required this._datasource,
    required this._getSettings,
  });

  @override
  Future<bool> isPresent() async {
    return (await _read()) != null;
  }

  @override
  Future<String?> readPlaintext() async {
    return (await _read())?.key;
  }

  Future<ScopedApiKeyModel?> _read() async {
    final settings = await _getSettings.execute();
    return _datasource.getSellToFiatBalanceApiKey(
      isTestnet: settings.environment.isTestnet,
    );
  }
}
