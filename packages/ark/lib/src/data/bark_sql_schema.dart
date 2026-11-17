import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../ark.dart';

/// Pure, transaction-neutral schema42 guard; never opens or writes a database.
/// Expected identity comes from trusted setup, never from the DB being checked.
final class BarkSqlSchema {
  final ArkAccountId account;
  final String expectedNativeFingerprint;
  final String expectedServerPubkey;
  BarkSqlSchema(
    this.account,
    this.expectedNativeFingerprint,
    this.expectedServerPubkey,
  );
  static const sourceSchemaId =
      'bark@303682063ed7559b06dcf37c5cb37bb7037b943f/schema42';
  // SHA256 of canonical [table_xinfo,foreign_key_list,[index_list,index_xinfo]].
  // Source bark/schema.sql SHA256 8e434dedbaee82808563f3af8b5cafd83c261d7e6851700d70326d02554c7665.
  // Complete tuples/fixture provenance: SQL-OBSERVER-CONSTRUCTION-ASTRA-REVIEW.
  static const layouts = {
    'migrations':
        '8e6d4bbefdcececc963ffb0872e8efd834409b294792342e8392d6b1e5a2cb0c',
    'bark_properties':
        '2bc58ce76355e23c9631541b0f5b4cf54a9c470dbe82055952f17d1f37dac5b3',
    'bark_vtxo':
        'e8542036596ed05137031e56bd754a5c0df34d94745d61dd2dedd62276e53295',
    'bark_vtxo_state':
        '4257c07739097300079ea2ca0df3e79c2ddd21309e8735f9a81d332cfeda3b63',
    'bark_wallet_action_checkpoint':
        '0493c5e317b67e8e992528550f41bc4456c534a6d18e80b4a05407d67393921e',
    'bark_vtxo_key':
        '16e43bfda39da41b4baf884f4e2a9d44c005d190efdc3a6a2e5857989dbbaac3',
    'bark_pending_lightning_receive':
        '036c75b4f3f2ec1c9f182335db6f971dca68a0dc0f38348fbb6ff6d1eb7af028',
    'bark_settled_lightning_receive':
        'e3d9d3c41a42c4c101310006e49715fd440c1bb2c7b3b25aa4fd2eba57f6cc80',
    'bark_exit_states':
        'fb34d5761c16e53d422208ea04c1699fe3f492fbae8aabcaffcac1e7884a9922',
    'bark_exit_child_transactions':
        '262a3bddc6117571858563569caa4c389cdf3a6d23a9866ba1830f8dd42b2a86',
  };
  bool get permitted =>
      account.network == BitcoinNetwork.regtest &&
      RegExp(r'^[0-9a-f]{8}$').hasMatch(expectedNativeFingerprint) &&
      expectedServerPubkey.isNotEmpty;
  static String hash(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();

  Result<void, ArkWalletFailure> validate(Database db) {
    if (!permitted) {
      return const Err(ArkValidationFailure(ArkFailureReason.identityMismatch));
    }
    try {
      final version = db.select(
        'SELECT value FROM migrations ORDER BY value DESC LIMIT 1',
      );
      if (version.length != 1 ||
          version.single['value'] is! int ||
          version.single['value'] != 42) {
        throw const FormatException();
      }
      for (final table in layouts.keys) {
        final object = db.select(
          'SELECT type,sql FROM sqlite_schema WHERE name=?',
          [table],
        );
        if (object.length != 1 ||
            object.single['type'] != 'table' ||
            object.single['sql'] is! String ||
            !(object.single['sql'] as String).toUpperCase().startsWith(
              'CREATE TABLE',
            )) {
          throw const FormatException();
        }
        final indexes = db.select(
          'SELECT seq,name,"unique",origin,partial FROM pragma_index_list(?) ORDER BY seq',
          [table],
        );
        final layout = [
          db
              .select(
                'SELECT cid,name,type,"notnull",dflt_value,pk,hidden FROM pragma_table_xinfo(?) ORDER BY cid',
                [table],
              )
              .map((r) => r.values.toList())
              .toList(),
          db
              .select('SELECT * FROM pragma_foreign_key_list(?)', [table])
              .map((r) => r.values.toList())
              .toList(),
          [
            for (final index in indexes)
              [
                index.values.toList(),
                db
                    .select(
                      'SELECT seqno,cid,name,desc,coll,key FROM pragma_index_xinfo(?) ORDER BY seqno',
                      [index['name']],
                    )
                    .map((r) => r.values.toList())
                    .toList(),
              ],
          ],
        ];
        if (hash(layout) != layouts[table]) throw const FormatException();
      }
      final properties = db.select(
        'SELECT id,network,fingerprint,server_pubkey FROM bark_properties LIMIT 2',
      );
      if (properties.length != 1 ||
          properties.single['id'] != '1' ||
          properties.single['network'] != 'regtest' ||
          properties.single['fingerprint'] != expectedNativeFingerprint ||
          properties.single['server_pubkey'] != expectedServerPubkey) {
        return const Err(
          ArkValidationFailure(ArkFailureReason.identityMismatch),
        );
      }
      return const Ok(null);
    } on FormatException {
      return const Err(ArkStorageFailure(ArkFailureReason.storeIncompatible));
    } on SqliteException {
      return const Err(ArkStorageFailure());
    }
  }
}
