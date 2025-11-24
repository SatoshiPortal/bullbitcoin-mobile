import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

class ElectrumSettingsModel {
  final ElectrumServerNetwork network;
  final bool validateDomain;
  final int stopGap;
  final int timeout;
  final int retry;
  final String? socks5;

  ElectrumSettingsModel({
    required this.network,
    required this.validateDomain,
    required this.stopGap,
    required this.timeout,
    required this.retry,
    this.socks5,
  });

  ElectrumSettings toEntity() {
    return ElectrumSettings(
      network: network,
      validateDomain: validateDomain,
      stopGap: stopGap,
      timeout: timeout,
      retry: retry,
      socks5: socks5,
    );
  }

  factory ElectrumSettingsModel.fromEntity(ElectrumSettings entity) {
    return ElectrumSettingsModel(
      network: entity.network,
      validateDomain: entity.validateDomain,
      stopGap: entity.stopGap,
      timeout: entity.timeout,
      retry: entity.retry,
      socks5: entity.socks5,
    );
  }

  factory ElectrumSettingsModel.fromSqlite(ElectrumSettingsRow row) {
    return ElectrumSettingsModel(
      network: row.network,
      validateDomain: row.validateDomain,
      stopGap: row.stopGap,
      timeout: row.timeout,
      retry: row.retry,
      socks5: row.socks5,
    );
  }

  ElectrumSettingsCompanion toSqlite() {
    return ElectrumSettingsCompanion.insert(
      network: network,
      validateDomain: validateDomain,
      stopGap: stopGap,
      timeout: timeout,
      retry: retry,
      socks5: Value(socks5), // Should be nullable, so use Value
    );
  }
}
