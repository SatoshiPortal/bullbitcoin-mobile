import 'package:bb_mobile/features/import_watch_only_wallet/public/import_watch_only_facade.dart';
import 'package:bb_mobile/features/trezor/application/usecases/prepare_trezor_import_usecase.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_account.dart';

/// Public cross-feature API for the Trezor slice.
///
/// Other features (e.g. `import_wallet`, `send`) must depend on this facade
/// rather than on any internal of `lib/features/trezor/`
class TrezorFacade {
  final PrepareTrezorImportUsecase _prepareTrezorImportUsecase;

  TrezorFacade({required this._prepareTrezorImportUsecase});

  /// Builds a watch-only descriptor entity for the chosen Trezor account,
  /// ready to hand to the import_watch_only_wallet finalize screen. Does
  /// NOT persist the wallet — that happens in the finalize cubit.
  Future<WatchOnlyDescriptorEntity> prepareImport({
    required TrezorAccount account,
    String? label,
  }) {
    return _prepareTrezorImportUsecase.execute(account: account, label: label);
  }
}
