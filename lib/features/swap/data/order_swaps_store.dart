import 'dart:io';

import 'package:drift/drift.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:legacy_storage/owner_database.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'order_swaps_database.dart';

const _owner = 'order_swaps';

final class OrderSwapsStore {
  static LegacyImportParticipant participant(File file) => ProjectedOwner(
    ownerId: _owner,
    file: file,
    tables: const [
      OwnerTableCopy(
        'order_swaps',
        'local_id,request_id,order_id,purpose,environment,in_network,out_network,'
            'is_in_amount_fixed,requested_amount_sat,quoted_amount_sat,'
            'source_wallet_id,destination_wallet_id,destination,fallback,'
            'bitcoin_address,liquid_address,lightning_invoice,payin_amount_sat,'
            'payout_amount_sat,payin_currency,payout_currency,payin_method,'
            'payout_method,order_type,order_status,payin_status,payout_status,'
            'message_code,bitcoin_transaction_id,liquid_transaction_id,'
            'local_payin_transaction_id,signed_payin_transaction,payin_is_psbt,'
            'order_number,created_at,server_created_at,confirmation_deadline,'
            'sent_at,local_status,last_polled_at,note,server_completed_at,'
            'labels_applied_at',
        orderBy: 'local_id',
      ),
    ],
    open: (admission, {required existing}) =>
        _open(file, admission, existing: existing),
    complete: (_, database) => _verifyIndices(database),
  );

  static Future<Result<OwnerDatabase<OrderSwapsDatabase>, LegacyImportFailure>>
  open(File file, RuntimeAdmission admission) async {
    final opened = await _open(file, admission, existing: true);
    if (opened case Ok(:final value)) {
      final receipt = await ownerReadiness(value.database, _owner);
      if (receipt case Ok(
        value: OwnerReadiness.imported || OwnerReadiness.initialized,
      )) {
        return opened;
      }
      await value.handle.close();
      if (receipt case Err(:final failure)) return Err(failure);
      return const Err(LegacyImportDeferred());
    }
    return opened;
  }
}

Future<bool> _verifyIndices(OrderSwapsDatabase database) async {
  const expected = {
    'order_swaps_request_id': ('request_id', true),
    'order_swaps_local_status': ('local_status', false),
    'order_swaps_source_wallet': ('source_wallet_id', false),
    'order_swaps_destination_wallet': ('destination_wallet_id', false),
    'order_swaps_bitcoin_txid': ('bitcoin_transaction_id', false),
    'order_swaps_liquid_txid': ('liquid_transaction_id', false),
    'order_swaps_local_payin_txid': ('local_payin_transaction_id', false),
  };
  final indices = await database
      .customSelect(
        "SELECT name, \"unique\", partial FROM pragma_index_list('order_swaps') "
        "WHERE origin = 'c'",
      )
      .get();
  if (indices.length != expected.length) return false;
  for (final index in indices) {
    final name = index.read<String>('name');
    final metadata = expected[name];
    if (metadata == null) return false;
    final (column, unique) = metadata;
    if (index.read<int>('unique') != (unique ? 1 : 0) ||
        index.read<int>('partial') != 0) {
      return false;
    }
    final keys = await database
        .customSelect(
          'SELECT name FROM pragma_index_info(?) ORDER BY seqno',
          variables: [Variable(name)],
        )
        .get();
    if (keys.length != 1 || keys.single.read<String>('name') != column) {
      return false;
    }
  }
  return true;
}

Future<Result<OwnerDatabase<OrderSwapsDatabase>, LegacyImportFailure>> _open(
  File file,
  LifecycleAdmission admission, {
  required bool existing,
}) => OwnerDatabase.open(
  admission: admission,
  openExecutor: Secrets.databaseOpener<LegacyImportFailure>(
    module: _owner,
    name: 'main',
    file: file,
    schema: OrderSwapsDatabase.schema,
    deferred: const LegacyImportDeferred(),
    unavailable: const LegacyImportUnavailable(),
  )(existing),
  create: OrderSwapsDatabase.new,
);
