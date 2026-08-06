import 'package:freezed_annotation/freezed_annotation.dart';

part 'service_status.freezed.dart';

/// [disabled]: the service is intentionally turned off by the user (e.g.
/// payjoin off in settings), so it is neither reachable-checked nor a
/// problem — distinct from [unknown] (not checked / indeterminate).
enum ServiceStatus { online, offline, unknown, disabled }

@freezed
sealed class ServiceStatusInfo with _$ServiceStatusInfo {
  const factory ServiceStatusInfo({
    required ServiceStatus status,
    required String name,
    DateTime? lastChecked,
  }) = _ServiceStatusInfo;

  const ServiceStatusInfo._();

  bool get isOnline => status == ServiceStatus.online;
  bool get isOffline => status == ServiceStatus.offline;
  bool get isUnknown => status == ServiceStatus.unknown;
  bool get isDisabled => status == ServiceStatus.disabled;
}

@freezed
sealed class AllServicesStatus with _$AllServicesStatus {
  const factory AllServicesStatus({
    @Default(
      ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Internet Connection',
        lastChecked: null,
      ),
    )
    ServiceStatusInfo internetConnection,
    @Default(
      ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Bitcoin Electrum',
        lastChecked: null,
      ),
    )
    ServiceStatusInfo bitcoinElectrum,
    @Default(
      ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Liquid Electrum',
        lastChecked: null,
      ),
    )
    ServiceStatusInfo liquidElectrum,
    @Default(
      ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Payjoin',
        lastChecked: null,
      ),
    )
    ServiceStatusInfo payjoin,
    @Default(
      ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Pricer',
        lastChecked: null,
      ),
    )
    ServiceStatusInfo pricer,
    @Default(
      ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Mempool',
        lastChecked: null,
      ),
    )
    ServiceStatusInfo mempool,
    @Default(
      ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Tor',
        lastChecked: null,
      ),
    )
    ServiceStatusInfo tor,
    @Default(
      ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Recoverbull',
        lastChecked: null,
      ),
    )
    ServiceStatusInfo recoverbull,
    @Default(null) DateTime? lastChecked,
  }) = _AllServicesStatus;

  const AllServicesStatus._();

  bool get allServicesOnline =>
      internetConnection.isOnline &&
      bitcoinElectrum.isOnline &&
      liquidElectrum.isOnline &&
      // Payjoin is opt-in: disabled is not a fault (see _checkPayjoinService).
      (payjoin.isOnline || payjoin.isDisabled) &&
      pricer.isOnline &&
      mempool.isOnline &&
      (tor.isOnline || tor.isUnknown) &&
      (recoverbull.isOnline || recoverbull.isUnknown);

  bool get hasAnyServiceOffline => !allServicesOnline;
}
