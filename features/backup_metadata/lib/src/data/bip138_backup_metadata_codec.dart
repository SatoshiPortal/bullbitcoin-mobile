import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart';

import '../domain/backup_metadata_failure.dart';
import '../domain/entities/backup_content.dart';
import '../domain/entities/backup_inventory.dart';
import '../domain/repositories/backup_metadata_codec.dart';

/// Vendor tag of the structured metadata item, version 2.
const backupMetadataVendorTag = 'bull.metadata.v2';

const _maxRecords = 50000;
const _maxWallets = 64;
const _maxDerivations = 20000;
const _maxText = 4096;

final _privateKey = RegExp(
  r'\b[xtyuzvYUZV]prv|\b[5KLc9][1-9A-HJ-NP-Za-km-z]{50,51}\b',
);
final _confidential = RegExp(r'\bct\s*\(', caseSensitive: false);

/// The production codec: a BIP138 envelope whose recipients are the group's
/// public descriptors.
///
/// Three items, each with a closed list of fields:
/// - BIP139: the group's accounts as `multi_bip380` descriptor pairs, which
///   are the descriptors the envelope is encrypted to;
/// - BIP329: Bitcoin labels and freezes, standard fields only;
/// - a Bull vendor item: Liquid labels, wallet attribution of records,
///   account metadata and the BIP85 registry (path, application, status,
///   alias).
///
/// No seed, private key, derived child, passphrase or confidential Liquid
/// descriptor is ever accepted here. Whoever knows one of the group's public
/// descriptors can decrypt the file: it protects metadata from everyone
/// else, not from a holder of an xpub.
final class Bip138BackupMetadataCodec implements BackupMetadataCodec {
  const Bip138BackupMetadataCodec();

  @override
  Result<PreparedBackup, BackupMetadataFailure> prepare(
    BackupGroup group,
    BackupContent content,
  ) {
    try {
      final descriptors = _descriptors(group);
      if (descriptors.isEmpty ||
          descriptors.any((descriptor) => !_isPublic(descriptor))) {
        return const Err(BackupMetadataIncompatibleFailure());
      }
      final items = _items(group, content);
      final digest = sha256.convert(_canonical(items)).toString();
      return Ok((
        digest: digest,
        encrypt: () async {
          try {
            return Ok(
              await bip138Encrypt(
                publicDescriptors: descriptors,
                items: items,
                padded: true,
              ),
            );
          } on Bip138Error catch (error) {
            return Err(_failure(error));
          } on Exception {
            return const Err(BackupMetadataUnexpectedFailure());
          }
        },
      ));
    } on ArgumentError {
      return const Err(BackupMetadataUnexpectedFailure());
    } on FormatException {
      return const Err(BackupMetadataUnexpectedFailure());
    }
  }

  @override
  Future<Result<BackupContent?, BackupMetadataFailure>> decode(
    BackupGroup group,
    Uint8List envelope,
  ) async {
    final List<Bip138Item>? items;
    try {
      items = await bip138Decrypt(
        bytes: envelope,
        candidatePublicDescriptors: _descriptors(group),
      );
    } on Bip138Error catch (error) {
      return switch (error) {
        // The candidates are the group's own public descriptors; none of them
        // can seed a key for this envelope.
        Bip138Error.noEligibleKeys => const Ok(null),
        _ => Err(_failure(error)),
      };
    } on Exception {
      return const Err(BackupMetadataUnexpectedFailure());
    }
    if (items == null) return const Ok(null);
    try {
      return Ok(_read(group, items));
    } on _Rejected {
      return const Err(BackupMetadataUnexpectedFailure());
    } on ArgumentError {
      return const Err(BackupMetadataUnexpectedFailure());
    } on FormatException {
      return const Err(BackupMetadataUnexpectedFailure());
    }
  }

  static BackupMetadataFailure _failure(Bip138Error error) => switch (error) {
    Bip138Error.tooLarge => const BackupMetadataTooLargeFailure(),
    Bip138Error.noEligibleKeys ||
    Bip138Error.descriptorMismatch ||
    Bip138Error.invalidDescriptor => const BackupMetadataIncompatibleFailure(),
    _ => const BackupMetadataUnexpectedFailure(),
  };

  static List<String> _descriptors(BackupGroup group) =>
      ({...group.bitcoinPublicDescriptors}.toList()..sort());

  static bool _isPublic(String descriptor) =>
      descriptor.contains('(') &&
      !_privateKey.hasMatch(descriptor) &&
      !_confidential.hasMatch(descriptor);

  // ---------------------------------------------------------------- write

  List<Bip138Item> _items(BackupGroup group, BackupContent content) {
    final wallets = [...content.wallets]
      ..sort((a, b) => a.externalDescriptor.compareTo(b.externalDescriptor));
    if (wallets.length > _maxWallets ||
        content.derivations.length > _maxDerivations ||
        content.labels.records.length > _maxRecords) {
      throw ArgumentError('backup content over the limit');
    }
    final accountDescriptors = {
      for (final wallet in wallets) wallet.externalDescriptor,
      for (final wallet in wallets) wallet.internalDescriptor,
    };
    if (!_sameSet(accountDescriptors, group.bitcoinPublicDescriptors)) {
      throw ArgumentError('accounts do not match the recipient descriptors');
    }
    final records = [...content.labels.records]
      ..sort((a, b) {
        final byChain = a.chain.index.compareTo(b.chain.index);
        if (byChain != 0) return byChain;
        final byType = a.type.index.compareTo(b.type.index);
        return byType != 0 ? byType : a.ref.compareTo(b.ref);
      });
    final bitcoin = records.where(
      (record) => record.chain == BackupLabelChain.bitcoin,
    );
    final liquid = records.where(
      (record) => record.chain == BackupLabelChain.liquid,
    );
    final derivations = [...content.derivations]
      ..sort((a, b) => a.path.compareTo(b.path));
    final network = group.network.env.name;
    final account = <Map<String, Object?>>[
      for (final wallet in wallets)
        {
          'type': 'multi_bip380',
          'descriptor': [wallet.externalDescriptor, wallet.internalDescriptor],
        },
    ];
    final vendor = <String, Object?>{
      'v': 2,
      'kind': group.isWatchOnly ? 'watch' : 'seed',
      'liquid': [for (final record in liquid) _record(record)],
      'attribution': [
        for (final record in bitcoin)
          if (record.walletId != null)
            {
              'type': record.type.name,
              'ref': record.ref,
              'wallet': record.walletId,
            },
      ],
      'wallets': [
        for (final wallet in wallets)
          {
            'network': wallet.network.env.name,
            'script': wallet.scriptType.name,
            'external': wallet.externalDescriptor,
            'internal': wallet.internalDescriptor,
            'label': wallet.label,
            'birthday': wallet.birthday?.toUtc().toIso8601String(),
            'watch': wallet.watchOnly,
          },
      ],
      'derivations': [
        for (final derivation in derivations)
          {
            'path': derivation.path,
            'application': derivation.application,
            'status': derivation.status,
            'alias': derivation.alias,
          },
      ],
    };
    return [
      Bip138Item(
        contentType: const Bip138ContentType.bip(number: 139),
        bytes: _json({
          'version': 'BIP139-1',
          'network': network,
          'accounts': account,
        }),
      ),
      Bip138Item(
        contentType: const Bip138ContentType.bip(number: 329),
        bytes: Uint8List.fromList(
          utf8.encode(
            bitcoin.map((record) => '${jsonEncode(_bip329(record))}\n').join(),
          ),
        ),
      ),
      Bip138Item(
        contentType: Bip138ContentType.vendor(
          tag: Uint8List.fromList(utf8.encode(backupMetadataVendorTag)),
        ),
        bytes: _json(vendor),
      ),
    ];
  }

  static Map<String, Object?> _bip329(BackupLabelRecord record) => {
    'type': record.type.name,
    'ref': record.ref,
    'label': ?record.label,
    'origin': ?record.origin,
    'spendable': ?record.spendable,
  };

  static Map<String, Object?> _record(BackupLabelRecord record) => {
    'type': record.type.name,
    'ref': record.ref,
    'label': ?record.label,
    'origin': ?record.origin,
    'spendable': ?record.spendable,
    'wallet': ?record.walletId,
  };

  static Uint8List _json(Object value) =>
      Uint8List.fromList(utf8.encode(jsonEncode(value)));

  static List<int> _canonical(List<Bip138Item> items) {
    final out = BytesBuilder();
    for (final item in items) {
      final type = jsonEncode(item.contentType.toString());
      out
        ..add(utf8.encode('$type:${item.bytes.length}:'))
        ..add(item.bytes);
    }
    return out.toBytes();
  }

  static bool _sameSet(Set<String> a, List<String> b) {
    final other = b.toSet();
    return a.length == other.length && a.containsAll(other);
  }

  // ----------------------------------------------------------------- read

  BackupContent? _read(BackupGroup group, List<Bip138Item> items) {
    Bip138Item? accounts;
    Bip138Item? labels;
    Bip138Item? vendor;
    for (final item in items) {
      switch (item.contentType) {
        case Bip138ContentType_Bip(number: 139) when accounts == null:
          accounts = item;
        case Bip138ContentType_Bip(number: 329) when labels == null:
          labels = item;
        case Bip138ContentType_Vendor(:final tag)
            when vendor == null &&
                utf8.decode(tag, allowMalformed: true) ==
                    backupMetadataVendorTag:
          vendor = item;
        default:
          throw const _Rejected();
      }
    }
    if (accounts == null || labels == null || vendor == null) {
      throw const _Rejected();
    }
    final document = _object(jsonDecode(utf8.decode(vendor.bytes)));
    if (document['v'] != 2) throw const _Rejected();
    final kind = document['kind'];
    if (kind != 'seed' && kind != 'watch') throw const _Rejected();
    // A file of the other kind is not this group's file.
    if ((kind == 'watch') != group.isWatchOnly) return null;

    final container = _object(jsonDecode(utf8.decode(accounts.bytes)));
    if (container['version'] != 'BIP139-1') throw const _Rejected();
    if (container['network'] != group.network.env.name) return null;
    final fromContainer = <String>{};
    for (final account in _list(container['accounts'])) {
      final data = _object(account);
      if (data['type'] != 'multi_bip380') throw const _Rejected();
      final pair = _list(data['descriptor']);
      if (pair.length != 2) throw const _Rejected();
      for (final descriptor in pair) {
        fromContainer.add(_text(descriptor, required: true)!);
      }
    }
    final walletsJson = _list(document['wallets']);
    if (walletsJson.isEmpty || walletsJson.length > _maxWallets) {
      throw const _Rejected();
    }
    final wallets = <BackupWallet>[];
    for (final entry in walletsJson) {
      final data = _object(entry);
      final scriptType = ScriptType.values
          .where((value) => value.name == data['script'])
          .firstOrNull;
      final env = NetworkEnv.values
          .where((value) => value.name == data['network'])
          .firstOrNull;
      final external = _text(data['external'], required: true)!;
      final internal = _text(data['internal'], required: true)!;
      final birthday = _text(data['birthday']);
      final watch = data['watch'];
      if (scriptType == null ||
          env != group.network.env ||
          watch is! bool ||
          !_isPublic(external) ||
          !_isPublic(internal)) {
        throw const _Rejected();
      }
      wallets.add(
        BackupWallet(
          network: group.network,
          scriptType: scriptType,
          externalDescriptor: external,
          internalDescriptor: internal,
          label: _text(data['label']),
          birthday: birthday == null ? null : DateTime.parse(birthday),
          watchOnly: watch,
        ),
      );
    }
    final fromVendor = {
      for (final wallet in wallets) wallet.externalDescriptor,
      for (final wallet in wallets) wallet.internalDescriptor,
    };
    // The descriptors the file is encrypted to are the descriptors of its
    // accounts, and the file must be reachable from this group.
    if (fromVendor.length != fromContainer.length ||
        !fromVendor.containsAll(fromContainer) ||
        !fromVendor.any(group.bitcoinPublicDescriptors.contains)) {
      throw const _Rejected();
    }

    final attribution = <(BackupLabelType, String), String>{};
    for (final entry in _list(document['attribution'])) {
      final data = _object(entry);
      final type = _type(data['type']);
      attribution[(type, _text(data['ref'], required: true)!)] = _text(
        data['wallet'],
        required: true,
      )!;
    }
    final records = <BackupLabelRecord>[];
    final lines = utf8.decode(labels.bytes).split('\n');
    for (final line in lines) {
      if (line.isEmpty) continue;
      final data = _object(jsonDecode(line));
      final type = _type(data['type']);
      final ref = _text(data['ref'], required: true)!;
      final spendable = data['spendable'];
      if (spendable != null && spendable is! bool) throw const _Rejected();
      records.add(
        BackupLabelRecord(
          chain: BackupLabelChain.bitcoin,
          type: type,
          ref: ref,
          label: _text(data['label']),
          origin: _text(data['origin']),
          spendable: spendable as bool?,
          walletId: attribution[(type, ref)],
        ),
      );
    }
    for (final entry in _list(document['liquid'])) {
      final data = _object(entry);
      final spendable = data['spendable'];
      if (spendable != null && spendable is! bool) throw const _Rejected();
      records.add(
        BackupLabelRecord(
          chain: BackupLabelChain.liquid,
          type: _type(data['type']),
          ref: _text(data['ref'], required: true)!,
          label: _text(data['label']),
          origin: _text(data['origin']),
          spendable: spendable as bool?,
          walletId: _text(data['wallet']),
        ),
      );
    }
    if (records.length > _maxRecords) throw const _Rejected();
    final derivationsJson = _list(document['derivations']);
    if (derivationsJson.length > _maxDerivations) throw const _Rejected();
    if (group.isWatchOnly && derivationsJson.isNotEmpty) {
      throw const _Rejected();
    }
    final derivations = [
      for (final entry in derivationsJson)
        BackupDerivation(
          path: _text(_object(entry)['path'], required: true)!,
          application: _text(_object(entry)['application'], required: true)!,
          status: _text(_object(entry)['status'], required: true)!,
          alias: _text(_object(entry)['alias']),
        ),
    ];
    return BackupContent(
      labels: LabelsSnapshot(
        records: records,
        unattributedCount: 0,
        skippedCount: 0,
      ),
      wallets: wallets,
      derivations: derivations,
    );
  }

  static BackupLabelType _type(Object? value) =>
      BackupLabelType.values.where((type) => type.name == value).firstOrNull ??
      (throw const _Rejected());

  static Map<String, Object?> _object(Object? value) =>
      value is Map ? value.cast<String, Object?>() : throw const _Rejected();

  static List<Object?> _list(Object? value) =>
      value is List ? value.cast<Object?>() : throw const _Rejected();

  static String? _text(Object? value, {bool required = false}) {
    if (value == null) return required ? throw const _Rejected() : null;
    if (value is! String || value.length > _maxText) {
      throw const _Rejected();
    }
    if (required && value.isEmpty) throw const _Rejected();
    return value;
  }
}

final class _Rejected implements Exception {
  const _Rejected();
}
