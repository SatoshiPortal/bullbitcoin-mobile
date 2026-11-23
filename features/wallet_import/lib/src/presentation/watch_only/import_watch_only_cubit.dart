import 'package:wallet_import/src/domain/watch_only/capture_watch_only_network_usecase.dart';
import 'package:signers/signers.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:wallet_import/src/domain/watch_only/read_watch_only_network_usecase.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/watch_only/import_watch_only_descriptor_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/import_watch_only_xpub_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/parse_watch_only_input_usecase.dart';
import 'package:wallet_import/src/presentation/watch_only/import_watch_only_state.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class ImportWatchOnlyCubit extends Cubit<ImportWatchOnlyState> {
  final ImportWatchOnlyDescriptorUsecase _importWatchOnlyDescriptorUsecase;
  final ImportWatchOnlyXpubUsecase _importWatchOnlyXpubUsecase;
  final ParseWatchOnlyInputUsecase _parseWatchOnlyInputUsecase;
  final ReadWatchOnlyNetworkUsecase _readNetworkUsecase;

  ImportWatchOnlyCubit({
    WatchOnlyWalletEntity? watchOnlyWallet,
    required this._importWatchOnlyDescriptorUsecase,
    required this._importWatchOnlyXpubUsecase,
    required this._parseWatchOnlyInputUsecase,
    required this._readNetworkUsecase,
  }) : super(ImportWatchOnlyState(watchOnlyWallet: watchOnlyWallet));

  Future<void> init() async {
    final wallet = state.watchOnlyWallet;
    if (wallet == null) return;
    final network = await _readNetworkUsecase.execute();
    if (isClosed) return;
    final NetworkEnv environment;
    switch (network) {
      case Ok(:final value):
        environment = value;
      case Err(:final failure):
        emit(state.copyWith(watchOnlyWallet: null, failure: failure));
        return;
    }
    switch (const CaptureWatchOnlyNetworkUsecase().execute(
      wallet,
      environment: environment,
    )) {
      case Ok(:final value):
        emit(state.copyWith(watchOnlyWallet: value));
      case Err(:final failure):
        emit(state.copyWith(watchOnlyWallet: null, failure: failure));
    }
  }

  void updateLabel(String label) {
    final wallet = state.watchOnlyWallet;
    if (wallet == null) return;
    final failure = state.failure;
    emit(
      state.copyWith(
        watchOnlyWallet: wallet.copyWith(label: label),
        failure: failure is LabelRequiredFailure && label.isNotEmpty
            ? null
            : failure,
      ),
    );
  }

  Future<void> import() async {
    emit(state.copyWith(failure: null));

    final wallet = state.watchOnlyWallet;
    if (wallet == null) {
      emit(state.copyWith(failure: const NoWalletSelectedFailure()));
      return;
    }
    if (wallet.label.isEmpty) {
      emit(state.copyWith(failure: const LabelRequiredFailure()));
      return;
    }
    final network = await _readNetworkUsecase.execute();
    if (isClosed) return;
    final NetworkEnv environment;
    switch (network) {
      case Ok(:final value):
        environment = value;
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
        return;
    }
    if (wallet.network.env != environment) {
      emit(state.copyWith(failure: const NetworkMismatchFailure()));
      return;
    }

    final Result<void, ImportWatchOnlyFailure> result;
    if (wallet is WatchOnlyDescriptorEntity) {
      result = await _importWatchOnlyDescriptorUsecase.execute(
        watchOnlyDescriptor: wallet,
      );
    } else if (wallet is WatchOnlyXpubEntity) {
      result = await _importWatchOnlyXpubUsecase.execute(watchOnlyXpub: wallet);
    } else {
      return;
    }

    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(imported: true));
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> parsePastedInput(String input) async {
    final trimmed = input.trim();
    emit(state.copyWith(input: trimmed));
    if (trimmed.length >= 111) {
      final network = await _readNetworkUsecase.execute();
      if (isClosed || state.input != trimmed) return;
      final NetworkEnv environment;
      switch (network) {
        case Ok(:final value):
          environment = value;
        case Err(:final failure):
          emit(state.copyWith(watchOnlyWallet: null, failure: failure));
          return;
      }
      final result = await _parseWatchOnlyInputUsecase.execute(
        trimmed,
        environment: environment,
      );
      if (isClosed || state.input != trimmed) return;
      switch (result) {
        case Ok(:final value):
          emit(state.copyWith(watchOnlyWallet: value, failure: null));
        case Err(:final failure):
          emit(state.copyWith(watchOnlyWallet: null, failure: failure));
      }
    } else {
      emit(state.copyWith(watchOnlyWallet: null, failure: null));
    }
  }

  void onSignerChanged(SignerEntity? value) {
    if (value == null) return;
    final wallet = state.watchOnlyWallet;
    if (wallet == null || wallet.network == BitcoinNetwork.regtest) return;
    final watchOnlyWallet = wallet.copyWith(signer: value);
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet));
  }

  void onSignerDeviceChanged(SignerDevice? device) {
    final entity = state.watchOnlyWallet;
    if (entity is! WatchOnlyDescriptorEntity ||
        entity.network == BitcoinNetwork.regtest) {
      return;
    }

    final watchOnlyWallet = entity.copyWith(
      signerDevice: device,
      signer: device == null ? SignerEntity.none : SignerEntity.remote,
    );
    emit(state.copyWith(watchOnlyWallet: watchOnlyWallet));
  }

  void onDerivationChanged(satoshifier.Derivation? value) {
    final entity = state.watchOnlyWallet;
    if (entity is! WatchOnlyXpubEntity || value == null) return;
    if (entity.network == BitcoinNetwork.regtest &&
        value != satoshifier.Derivation.bip84) {
      return;
    }
    final newPubkey = switch (value) {
      satoshifier.Derivation.bip84 => satoshifier.Bip32Utils.convertToZpub(
        entity.extendedPubkey.pubkey,
      ),
      satoshifier.Derivation.bip49 => satoshifier.Bip32Utils.convertToYpub(
        entity.extendedPubkey.pubkey,
      ),
      satoshifier.Derivation.bip44 => satoshifier.Bip32Utils.convertToXpub(
        entity.extendedPubkey.pubkey,
      ),
    };

    parsePastedInput(newPubkey);
  }
}
