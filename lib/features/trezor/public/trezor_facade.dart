import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/trezor/application/usecases/prepare_trezor_import_usecase.dart';
import 'package:bb_mobile/features/trezor/application/usecases/verify_address_trezor_usecase.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_account.dart';

/// Public cross-feature API for the Trezor slice.
///
/// Other features (e.g. `import_wallet`, `send`) must depend on this facade
/// rather than on any internal of `lib/features/trezor/`
class TrezorFacade {
  final PrepareTrezorImportUsecase _prepareTrezorImportUsecase;
  final VerifyAddressTrezorUsecase _verifyAddressTrezorUsecase;

  TrezorFacade({
    required PrepareTrezorImportUsecase prepareTrezorImportUsecase,
    required VerifyAddressTrezorUsecase verifyAddressTrezorUsecase,
  }) : _prepareTrezorImportUsecase = prepareTrezorImportUsecase,
       _verifyAddressTrezorUsecase = verifyAddressTrezorUsecase;

  /// Builds a watch-only descriptor entity for the chosen Trezor account,
  /// ready to hand to the import_watch_only_wallet finalize screen. Does
  /// NOT persist the wallet — that happens in the finalize cubit.
  Future<WatchOnlyDescriptorEntity> prepareImport({
    required TrezorAccount account,
    String? label,
  }) {
    return _prepareTrezorImportUsecase.execute(account: account, label: label);
  }

  Future<bool> verifyAddress({
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
  }) {
    return _verifyAddressTrezorUsecase.execute(
      address: address,
      derivationPath: derivationPath,
      scriptType: scriptType,
    );
  }
}
