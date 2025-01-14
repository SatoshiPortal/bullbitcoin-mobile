import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/transaction.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/_repository/wallet/internal_network.dart';
import 'package:bb_mobile/_ui/alert.dart';
import 'package:bb_mobile/settings/bloc/broadcasttx_state.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BroadcastTxCubit extends Cubit<BroadcastTxState> {
  BroadcastTxCubit({
    required Barcode barcode,
    required FilePick filePicker,
    required FileStorage fileStorage,
    required AppWalletsRepository appWalletsRepository,
    required NetworkRepository networkRepository,
    required InternalNetworkRepository internalNetworkRepository,
    required BDKTransactions bdkTransactions,
  })  : _bdkTransactions = bdkTransactions,
        _internalNetworkRepository = internalNetworkRepository,
        _networkRepository = networkRepository,
        _appWalletsRepository = appWalletsRepository,
        _fileStorage = fileStorage,
        _barcode = barcode,
        _filePicker = filePicker,
        super(const BroadcastTxState()) {
    clearErrors();
  }

  final FilePick _filePicker;
  final Barcode _barcode;
  final FileStorage _fileStorage;

  final AppWalletsRepository _appWalletsRepository;
  final NetworkRepository _networkRepository;
  final InternalNetworkRepository _internalNetworkRepository;
  final BDKTransactions _bdkTransactions;

  @override
  void onChange(Change<BroadcastTxState> change) {
    final current = change.currentState;
    final next = change.nextState;

    if (current.hasErr() != next.hasErr() && next.hasErr()) {
      BBAlert.showErrorAlertPopUp(
        err: next.getErrors(),
        onClose: () {
          clearErrors();
        },
      );
    }

    super.onChange(change);
  }

  void txChanged(String tx) {
    emit(state.copyWith(tx: tx));
  }

  Future<void> scanQRClicked() async {
    await clearErrors();
    emit(state.copyWith(loadingFile: true, errLoadingFile: ''));
    final (file, err) = await _barcode.scan();
    if (err != null) {
      emit(state.copyWith(loadingFile: false, errLoadingFile: err.toString()));
      return;
    }

    final tx = file!;
    emit(state.copyWith(loadingFile: false, tx: tx));
  }

  Future<void> uploadFileClicked() async {
    await clearErrors();
    emit(state.copyWith(loadingFile: true, errLoadingFile: ''));
    final (file, err) = await _filePicker.pickFile();
    if (err != null) {
      emit(state.copyWith(loadingFile: false, errLoadingFile: err.toString()));
      return;
    }

    final tx =
        file!.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
    emit(state.copyWith(loadingFile: false, tx: tx));
  }

  Future<bool> checkWitnesses(List<bdk.TxIn> inputs) async {
    for (final txIn in inputs) {
      if (txIn.witness.isEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<void> extractTxClicked() async {
    try {
      await clearErrors();
      emit(
        state.copyWith(
          extractingTx: true,
          errExtractingTx: '',
          verified: false,
        ),
      );
      bdk.Transaction bdkTx;
      final tx = state.tx;
      try {
        final decodedTx = hex.decode(tx);
        bdkTx = await bdk.Transaction.fromBytes(transactionBytes: decodedTx);
      } catch (e) {
        final psbt = await bdk.PartiallySignedTransaction.fromString(tx);
        bdkTx = psbt.extractTx();
      }
      final txid = await bdkTx.txid();
      final outputs = await bdkTx.output();
      final inputs = await bdkTx.input();
      final isSigned = await checkWitnesses(inputs);

      Transaction? transaction;
      Wallet? relatedWallet;

      final wallets = _appWalletsRepository.allWallets;

      for (final wallet in wallets) {
        for (final tx in wallet.unsignedTxs) {
          if (tx.txid == txid && !tx.isReceived()) {
            transaction = tx;
            relatedWallet = wallet;
          }
        }
      }
      if (transaction != null) {
        emit(
          state.copyWith(
            recognizedTx: true,
          ),
        );
        if (relatedWallet == null) {
          emit(
            state.copyWith(
              errExtractingTx: 'Could not load related wallet',
            ),
          );
          return;
        }
      } else {
        emit(
          state.copyWith(
            recognizedTx: false,
          ),
        );
      }

      int totalAmount = 0;
      final nOutputs = outputs.length;
      int verifiedOutputs = 0;
      final List<Address> outAddrs = [];
      for (final outpoint in outputs) {
        totalAmount += outpoint.value.toInt();
        final scriptBuf = await bdk.ScriptBuf.fromHex(
          hex.encode(outpoint.scriptPubkey.bytes),
        );
        final addressStruct = await bdk.Address.fromScript(
          script: scriptBuf,
          network: _networkRepository.getBdkNetwork,
        );
        final addressStr = addressStruct.asString();
        if (transaction != null) {
          try {
            final Address relatedAddress = transaction.outAddrs.firstWhere(
              (element) =>
                  element.address == addressStr &&
                  BigInt.from(element.highestPreviousBalance) == outpoint.value,
            );
            outAddrs.add(
              relatedAddress,
            );
            verifiedOutputs += 1;
          } catch (e) {
            outAddrs.add(
              Address(
                address: addressStr,
                kind: AddressKind.external,
                state: AddressStatus.used,
                highestPreviousBalance: outpoint.value.toInt(),
                balance: outpoint.value.toInt(),
              ),
            );
          }
        } else {
          outAddrs.add(
            Address(
              address: addressStr,
              kind: AddressKind.external,
              state: AddressStatus.used,
              highestPreviousBalance: outpoint.value.toInt(),
              balance: outpoint.value.toInt(),
            ),
          );
        }
      }
      final int feeAmount = transaction?.fee ?? 0;

      transaction ??= Transaction(
        txid: txid,
        timestamp: 0,
      );

      transaction = transaction.copyWith(
        fee: feeAmount,
        outAddrs: outAddrs,
      );
      final decodedTx = hex.encode(await bdkTx.serialize());
      if (verifiedOutputs == nOutputs) {
        emit(state.copyWith(verified: true));
      }
      emit(
        state.copyWith(
          extractingTx: false,
          tx: decodedTx,
          transaction: transaction,
          step: BroadcastTxStep.broadcast,
          amount: totalAmount,
          isSigned: isSigned,
        ),
      );
    } on bdk.EncodeException {
      emit(
        state.copyWith(
          extractingTx: false,
          errExtractingTx:
              'Error decoding transaction. Ensure the transaction is valid.',
          step: BroadcastTxStep.import,
          tx: '',
        ),
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(
          extractingTx: false,
          errExtractingTx: e.message,
          step: BroadcastTxStep.import,
          tx: '',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          extractingTx: false,
          errExtractingTx: e.toString(),
          tx: '',
        ),
      );
    }
  }

  Future<void> broadcastClicked() async {
    await clearErrors();
    emit(
      state.copyWith(
        broadcastingTx: true,
        errBroadcastingTx: '',
        errExtractingTx: '',
      ),
    );
    final tx = state.tx;
    final bdkTx =
        await bdk.Transaction.fromBytes(transactionBytes: hex.decode(tx));

    final (blockchain, errB) = _internalNetworkRepository.bdkBlockchain;
    if (errB != null) {
      emit(
        state.copyWith(
          broadcastingTx: false,
          errBroadcastingTx: errB.toString(),
        ),
      );
      return;
    }

    final err =
        await _bdkTransactions.broadcastTx(tx: bdkTx, blockchain: blockchain!);
    if (err != null) {
      emit(
        state.copyWith(
          broadcastingTx: false,
          errBroadcastingTx:
              'Failed to Broadcast.\n\nCheck the following:\n- Internet connection\n- PSBT must be unspent & signed\n- Electrum server availability\n- Check network (mainnet/testnet)\n- Additional Info: $err',
        ),
      );
      return;
    }
    emit(state.copyWith(broadcastingTx: false, sent: true));
  }

  Future<void> downloadPSBTClicked() async {
    await clearErrors();
    emit(state.copyWith(downloadingFile: true, errDownloadingFile: ''));
    final psbt = state.psbtBDK?.toString();
    if (psbt == null || psbt.isEmpty) {
      emit(
        state.copyWith(
          downloadingFile: false,
          errDownloadingFile: 'No PSBT',
        ),
      );
      return;
    }

    final txid = state.transaction?.txid;
    if (txid == null || txid.isEmpty) {
      emit(
        state.copyWith(
          downloadingFile: false,
          errDownloadingFile: 'No TXID',
        ),
      );
      return;
    }

    final errSave = await _fileStorage.savePSBT(
      psbt: psbt,
      txid: txid,
    );
    if (errSave != null) {
      emit(
        state.copyWith(
          downloadingFile: false,
          errDownloadingFile: errSave.toString(),
        ),
      );
      return;
    }

    emit(state.copyWith(downloadingFile: false, downloaded: true));
    await Future.delayed(const Duration(seconds: 4));
    emit(state.copyWith(downloaded: false));
  }

  Future clearErrors() async {
    emit(
      state.copyWith(
        errBroadcastingTx: '',
        errExtractingTx: '',
        errLoadingFile: '',
        errPSBT: '',
        errDownloadingFile: '',
      ),
    );
    await Future.delayed(50.ms);
  }
}
