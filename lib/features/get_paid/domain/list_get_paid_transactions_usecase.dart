import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_failure.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_failure_mapping.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_transaction.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:meta/meta.dart';

class ListGetPaidTransactionsUsecase {
  final GetPaidDefaultWalletXprvPort _defaultWalletXprv;
  final BullnymFacade _bullnym;
  final NostrIdentityFacade _nostrIdentity;

  const ListGetPaidTransactionsUsecase({
    required this._defaultWalletXprv,
    required this._bullnym,
    required this._nostrIdentity,
  });

  @useResult
  Future<Result<GetPaidTransactionPage, GetPaidFailure>> execute({
    required String cursor,
    required int limit,
  }) async {
    final BullnymAuthSigner signer;
    try {
      final xprv = await _defaultWalletXprv.deriveDefaultWalletXprv();
      signer = BullnymAuthSigner(
        npubHex: _nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(xprv),
        signHashHex: (hash) => _nostrIdentity.signBullnymServerAuthHashFromXprv(
          xprvBase58: xprv,
          messageHashHex: hash,
        ),
      );
    } on Exception catch (error, stack) {
      log.warning(
        'Get Paid transaction identity preparation failed',
        error: error,
        trace: stack,
      );
      return Err(
        GetPaidFailure.localPreparation(
          logMessage: error.runtimeType.toString(),
        ),
      );
    } on ArgumentError catch (error, stack) {
      log.warning(
        'Get Paid transaction identity was invalid',
        error: error,
        trace: stack,
      );
      return Err(
        GetPaidFailure.localPreparation(
          logMessage: error.runtimeType.toString(),
        ),
      );
    }

    final result = await _bullnym.listGetPaidTransactions(
      signer: signer,
      cursor: cursor,
      limit: limit,
    );
    return switch (result) {
      Ok(:final value) => Ok(
        GetPaidTransactionPage(
          transactions: List.unmodifiable(
            value.transactions.map(_mapTransaction),
          ),
          nextCursor: value.nextCursor,
        ),
      ),
      Err(:final failure) => Err(mapBullnymFailureToGetPaid(failure)),
    };
  }

  GetPaidTransaction _mapTransaction(BullnymGetPaidTransaction item) {
    return GetPaidTransaction(
      transactionId: item.transactionId,
      source: switch (item.source) {
        BullnymGetPaidTransactionSource.lightningAddress =>
          GetPaidTransactionSource.lightningAddress,
        BullnymGetPaidTransactionSource.invoice =>
          GetPaidTransactionSource.invoice,
        BullnymGetPaidTransactionSource.paymentPage =>
          GetPaidTransactionSource.paymentPage,
        BullnymGetPaidTransactionSource.pointOfSale =>
          GetPaidTransactionSource.pointOfSale,
      },
      invoiceId: item.invoiceId,
      amountSat: item.amountSat,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        item.receivedAtUnix * 1000,
        isUtc: true,
      ),
      rail: switch (item.rail) {
        BullnymGetPaidTransactionRail.lightning =>
          GetPaidTransactionRail.lightning,
        BullnymGetPaidTransactionRail.liquid => GetPaidTransactionRail.liquid,
        BullnymGetPaidTransactionRail.bitcoin => GetPaidTransactionRail.bitcoin,
      },
      settlementState: switch (item.settlementState) {
        BullnymGetPaidSettlementState.pending => GetPaidSettlementState.pending,
        BullnymGetPaidSettlementState.settled => GetPaidSettlementState.settled,
        BullnymGetPaidSettlementState.problem => GetPaidSettlementState.problem,
      },
      late: item.late,
      comment: item.comment,
    );
  }
}
