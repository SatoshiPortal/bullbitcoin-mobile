import 'package:bb_mobile/features/pos/domain/pos_liveness.dart';
import 'package:bb_mobile/features/pos/domain/pos_terminal.dart';
import 'package:bb_mobile/features/pos/domain/pos_validation.dart';
import 'package:bb_mobile/features/pos/domain/usecases/get_supported_display_currencies_usecase.dart';

export 'package:bb_mobile/features/pos/domain/pos_error.dart';
export 'package:bb_mobile/features/pos/domain/pos_liveness.dart';
export 'package:bb_mobile/features/pos/domain/pos_terminal.dart';
export 'package:bb_mobile/features/pos/domain/pos_validation.dart';
export 'package:bb_mobile/features/pos/domain/usecases/get_supported_display_currencies_usecase.dart'
    show DisplayCurrency;

/// Cross-feature contract for the Point of Sale product. Callback-injection
/// shape (the Lightning Address / Payment Page facade precedent): the locator
/// wires each callback to its usecase, keeping the feature's usecases and ports
/// internal.
class PosFacade {
  final Future<PosTerminal?> Function({required String nym}) _findCallback;
  final Future<PosTerminal> Function(PosProvisionCommand command)
  _provisionCallback;
  final Future<PosTerminal?> Function() _archiveCallback;
  final Future<List<DisplayCurrency>> Function() _supportedCurrenciesCallback;
  final Future<PosHealOutcome> Function() _ensurePosLiveCallback;

  const PosFacade({
    required Future<PosTerminal?> Function({required String nym}) find,
    required Future<PosTerminal> Function(PosProvisionCommand command)
    provision,
    required Future<PosTerminal?> Function() archive,
    required Future<List<DisplayCurrency>> Function() supportedCurrencies,
    required Future<PosHealOutcome> Function() ensurePosLive,
  }) : _findCallback = find,
       _provisionCallback = provision,
       _archiveCallback = archive,
       _supportedCurrenciesCallback = supportedCurrencies,
       _ensurePosLiveCallback = ensurePosLive;

  /// Probe the current pos row for `nym`; null when no POS exists yet.
  Future<PosTerminal?> find({required String nym}) => _findCallback(nym: nym);

  Future<PosTerminal> provision(PosProvisionCommand command) =>
      _provisionCallback(command);

  /// Archive ("deactivate") the POS; null when already archived / absent.
  Future<PosTerminal?> archive() => _archiveCallback();

  Future<List<DisplayCurrency>> supportedCurrencies() =>
      _supportedCurrenciesCallback();

  /// DG-3 recovery heal - READ-ONLY liveness classification, never a write.
  Future<PosHealOutcome> ensurePosLive() => _ensurePosLiveCallback();
}
