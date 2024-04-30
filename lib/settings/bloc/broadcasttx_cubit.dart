import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/repository/network.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';
import 'package:bb_mobile/_ui/alert.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/broadcasttx_state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BroadcastTxCubit extends Cubit<BroadcastTxState> {
  BroadcastTxCubit({
    required Barcode barcode,
    required FilePick filePicker,
    required FileStorage fileStorage,
    required HomeCubit homeCubit,
    required NetworkCubit networkCubit,
    required NetworkRepository networkRepository,
    required WalletsRepository walletsRepository,
    required BDKTransactions bdkTransactions,
  })  : _bdkTransactions = bdkTransactions,
        _walletsRepository = walletsRepository,
        _networkRepository = networkRepository,
        _networkCubit = networkCubit,
        _homeCubit = homeCubit,
        _fileStorage = fileStorage,
        _barcode = barcode,
        _filePicker = filePicker,
        super(const BroadcastTxState()) {
    clearErrors();
  }

  final FilePick _filePicker;
  final Barcode _barcode;
  final FileStorage _fileStorage;
  final HomeCubit _homeCubit;
  final NetworkCubit _networkCubit;
  final NetworkRepository _networkRepository;
  final WalletsRepository _walletsRepository;
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

  void scanQRClicked() async {
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

  void uploadFileClicked() async {
    await clearErrors();
    emit(state.copyWith(loadingFile: true, errLoadingFile: ''));
    final (file, err) = await _filePicker.pickFile();
    if (err != null) {
      emit(state.copyWith(loadingFile: false, errLoadingFile: err.toString()));
      return;
    }
    // remove carriage return and newline from file read strings
    final tx =
        file!.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
    emit(state.copyWith(loadingFile: false, tx: tx));
  }

  void extractTxClicked() async {
    try {
      await clearErrors();
      emit(
        state.copyWith(
          extractingTx: true,
          errExtractingTx: '',
          verified: false,
        ),
      );
      final tx = state.tx;
      var isPsbt = false;
      try {
        // check if = is in the string
        hex.decode(tx);
      } catch (e) {
        isPsbt = true;
      }

      if (isPsbt) {
        final psbt = await bdk.PartiallySignedTransaction.fromString(tx);
        bdk.Transaction bdkTx = await psbt.extractTx();
        final txid = await bdkTx.txid();

        // loop wallet txs if txid match
        // get address
        // check if psbt outaddresses matches send tx address
        // if not show warning
        // if no tx matches skip checks
        Transaction? transaction;
        WalletBloc? relatedWallet;
        final wallets = _homeCubit.state.walletBlocs ?? [];

        for (final wallet in wallets) {
          for (final tx
              in wallet.state.wallet?.unsignedTxs ?? <Transaction>[]) {
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
          final (bdkWallet, errLoading) =
              _walletsRepository.getBdkWallet(relatedWallet.state.wallet!.id);
          if (errLoading != null) {
            emit(
              state.copyWith(
                errExtractingTx: errLoading.toString(),
              ),
            );
            return;
          }
          final (bdkTxFinResp, txErr) = await _bdkTransactions.signTx(
            psbt: tx,
            bdkWallet: bdkWallet!,
          );
          if (txErr != null) {
            emit(
              state.copyWith(
                errExtractingTx:
                    'Error finalizing psbt. Ensure the psbt is signed.',
              ),
            );
            return;
          } else
            bdkTx = bdkTxFinResp!.$1;
        } else {
          emit(
            state.copyWith(
              recognizedTx: false,
            ),
          );
        }
        final feeAmount = await psbt.feeAmount();
        final outputs = await bdkTx.output();

        int totalAmount = 0;
        final List<Address> outAddrs = [];

        final nOutputs = outputs.length;
        int verifiedOutputs = 0;
        for (final outpoint in outputs) {
          final scriptBuf =
              await bdk.ScriptBuf.fromHex(outpoint.scriptPubkey.toString());
          totalAmount += outpoint.value;
          final addressStruct = await bdk.Address.fromScript(
            script: scriptBuf,
            network: _networkCubit.state.getBdkNetwork(),
          );
          if (transaction != null) {
            try {
              final Address relatedAddress = transaction.outAddrs.firstWhere(
                (element) =>
                    element.address == addressStruct.toString() &&
                    element.highestPreviousBalance == outpoint.value,
              );
              outAddrs.add(
                relatedAddress,
              );
              verifiedOutputs += 1;
            } catch (e) {
              outAddrs.add(
                Address(
                  address: addressStruct.toString(),
                  kind: AddressKind.external,
                  state: AddressStatus.used,
                  highestPreviousBalance: outpoint.value,
                  balance: outpoint.value,
                ),
              );
            }
          } else {
            outAddrs.add(
              Address(
                address: addressStruct.toString(),
                kind: AddressKind.external,
                state: AddressStatus.used,
                highestPreviousBalance: outpoint.value,
                balance: outpoint.value,
              ),
            );
          }
        }

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
            psbtBDK: psbt,
            transaction: transaction,
            step: BroadcastTxStep.broadcast,
            amount: totalAmount,
            // this is the sum of outputs so its not really what we are sending
          ),
        );
      } else {
        // its a hex
        final bdkTx =
            await bdk.Transaction.fromBytes(transactionBytes: hex.decode(tx));
        final txid = await bdkTx.txid();
        final outputs = await bdkTx.output();
        Transaction? transaction;
        WalletBloc? relatedWallet;

        final wallets = _homeCubit.state.walletBlocs ?? [];
        for (final wallet in wallets) {
          for (final tx
              in wallet.state.wallet?.unsignedTxs ?? <Transaction>[]) {
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
          totalAmount += outpoint.value;
          final scriptBuf =
              await bdk.ScriptBuf.fromHex(outpoint.scriptPubkey.toString());
          final addressStruct = await bdk.Address.fromScript(
            script: scriptBuf,
            network: _networkCubit.state.getBdkNetwork(),
          );
          if (transaction != null) {
            try {
              final Address relatedAddress = transaction.outAddrs.firstWhere(
                (element) =>
                    element.address == addressStruct.toString() &&
                    element.highestPreviousBalance == outpoint.value,
              );
              outAddrs.add(
                relatedAddress,
              );
              verifiedOutputs += 1;
            } catch (e) {
              outAddrs.add(
                Address(
                  address: addressStruct.toString(),
                  kind: AddressKind.external,
                  state: AddressStatus.used,
                  highestPreviousBalance: outpoint.value,
                  balance: outpoint.value,
                ),
              );
            }
          } else {
            outAddrs.add(
              Address(
                address: addressStruct.toString(),
                kind: AddressKind.external,
                state: AddressStatus.used,
                highestPreviousBalance: outpoint.value,
                balance: outpoint.value,
              ),
            );
          }
        }
        final int feeAmount = transaction?.fee ?? 0;
        // sum of input values - output values = fees

        // TODO: timestamp needs to be properly set
        transaction ??= Transaction(
          txid: txid,
          timestamp: 0,
        );
        // transaction ??= Transaction(txid: txid);
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
            // this is the sum of outputs so its not really what we are sending
          ),
        );
      }
    } on bdk.EncodeException {
      emit(
        state.copyWith(
          extractingTx: false,
          errExtractingTx:
              'Error decoding transaction. Ensure the transaction is valid.',
          // step: BroadcastTxStep.import,
          tx: '',
        ),
      );
    } on Exception catch (e) {
      emit(
        state.copyWith(
          extractingTx: false,
          errExtractingTx: e.message,
          // step: BroadcastTxStep.import,
          tx: '',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          extractingTx: false,
          errExtractingTx: e.toString(),
          // step: BroadcastTxStep.import,
          tx: '',
        ),
      );
    }
  }

  void broadcastClicked() async {
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

    final (blockchain, errB) = _networkRepository.bdkBlockchain;
    if (errB == null) {
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
      // final error =
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

  void downloadPSBTClicked() async {
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

    // final (appDocDir, err) = await fileStorage.getDownloadDirectory();
    // if (err != null) {
    //   emit(
    //     state.copyWith(
    //       downloadingFile: false,
    //       errDownloadingFile: err.toString(),
    //     ),
    //   );
    //   return;
    // }
    // final file = File(appDocDir! + '/bullbitcoin_psbt/$txid.psbt');
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
