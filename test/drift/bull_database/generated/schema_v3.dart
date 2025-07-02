// dart format width=80
import 'dart:typed_data' as i2;
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';

class Transactions extends Table
    with TableInfo<Transactions, TransactionsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Transactions(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> txid = GeneratedColumn<String>(
    'txid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> size = GeneratedColumn<String>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> vsize = GeneratedColumn<String>(
    'vsize',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> locktime = GeneratedColumn<int>(
    'locktime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> vin = GeneratedColumn<String>(
    'vin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> vout = GeneratedColumn<String>(
    'vout',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> blockhash = GeneratedColumn<String>(
    'blockhash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> confirmations = GeneratedColumn<int>(
    'confirmations',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
    'time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> blocktime = GeneratedColumn<int>(
    'blocktime',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    txid,
    version,
    size,
    vsize,
    locktime,
    vin,
    vout,
    blockhash,
    height,
    confirmations,
    time,
    blocktime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  Set<GeneratedColumn> get $primaryKey => {txid};
  @override
  TransactionsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionsData(
      txid:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}txid'],
          )!,
      version:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}version'],
          )!,
      size:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}size'],
          )!,
      vsize:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}vsize'],
          )!,
      locktime:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}locktime'],
          )!,
      vin:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}vin'],
          )!,
      vout:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}vout'],
          )!,
      blockhash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blockhash'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      confirmations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confirmations'],
      ),
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time'],
      ),
      blocktime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blocktime'],
      ),
    );
  }

  @override
  Transactions createAlias(String alias) {
    return Transactions(attachedDatabase, alias);
  }
}

class TransactionsData extends DataClass
    implements Insertable<TransactionsData> {
  final String txid;
  final int version;
  final String size;
  final String vsize;
  final int locktime;
  final String vin;
  final String vout;
  final String? blockhash;
  final int? height;
  final int? confirmations;
  final int? time;
  final int? blocktime;
  const TransactionsData({
    required this.txid,
    required this.version,
    required this.size,
    required this.vsize,
    required this.locktime,
    required this.vin,
    required this.vout,
    this.blockhash,
    this.height,
    this.confirmations,
    this.time,
    this.blocktime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['txid'] = Variable<String>(txid);
    map['version'] = Variable<int>(version);
    map['size'] = Variable<String>(size);
    map['vsize'] = Variable<String>(vsize);
    map['locktime'] = Variable<int>(locktime);
    map['vin'] = Variable<String>(vin);
    map['vout'] = Variable<String>(vout);
    if (!nullToAbsent || blockhash != null) {
      map['blockhash'] = Variable<String>(blockhash);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || confirmations != null) {
      map['confirmations'] = Variable<int>(confirmations);
    }
    if (!nullToAbsent || time != null) {
      map['time'] = Variable<int>(time);
    }
    if (!nullToAbsent || blocktime != null) {
      map['blocktime'] = Variable<int>(blocktime);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      txid: Value(txid),
      version: Value(version),
      size: Value(size),
      vsize: Value(vsize),
      locktime: Value(locktime),
      vin: Value(vin),
      vout: Value(vout),
      blockhash:
          blockhash == null && nullToAbsent
              ? const Value.absent()
              : Value(blockhash),
      height:
          height == null && nullToAbsent ? const Value.absent() : Value(height),
      confirmations:
          confirmations == null && nullToAbsent
              ? const Value.absent()
              : Value(confirmations),
      time: time == null && nullToAbsent ? const Value.absent() : Value(time),
      blocktime:
          blocktime == null && nullToAbsent
              ? const Value.absent()
              : Value(blocktime),
    );
  }

  factory TransactionsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionsData(
      txid: serializer.fromJson<String>(json['txid']),
      version: serializer.fromJson<int>(json['version']),
      size: serializer.fromJson<String>(json['size']),
      vsize: serializer.fromJson<String>(json['vsize']),
      locktime: serializer.fromJson<int>(json['locktime']),
      vin: serializer.fromJson<String>(json['vin']),
      vout: serializer.fromJson<String>(json['vout']),
      blockhash: serializer.fromJson<String?>(json['blockhash']),
      height: serializer.fromJson<int?>(json['height']),
      confirmations: serializer.fromJson<int?>(json['confirmations']),
      time: serializer.fromJson<int?>(json['time']),
      blocktime: serializer.fromJson<int?>(json['blocktime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'txid': serializer.toJson<String>(txid),
      'version': serializer.toJson<int>(version),
      'size': serializer.toJson<String>(size),
      'vsize': serializer.toJson<String>(vsize),
      'locktime': serializer.toJson<int>(locktime),
      'vin': serializer.toJson<String>(vin),
      'vout': serializer.toJson<String>(vout),
      'blockhash': serializer.toJson<String?>(blockhash),
      'height': serializer.toJson<int?>(height),
      'confirmations': serializer.toJson<int?>(confirmations),
      'time': serializer.toJson<int?>(time),
      'blocktime': serializer.toJson<int?>(blocktime),
    };
  }

  TransactionsData copyWith({
    String? txid,
    int? version,
    String? size,
    String? vsize,
    int? locktime,
    String? vin,
    String? vout,
    Value<String?> blockhash = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<int?> confirmations = const Value.absent(),
    Value<int?> time = const Value.absent(),
    Value<int?> blocktime = const Value.absent(),
  }) => TransactionsData(
    txid: txid ?? this.txid,
    version: version ?? this.version,
    size: size ?? this.size,
    vsize: vsize ?? this.vsize,
    locktime: locktime ?? this.locktime,
    vin: vin ?? this.vin,
    vout: vout ?? this.vout,
    blockhash: blockhash.present ? blockhash.value : this.blockhash,
    height: height.present ? height.value : this.height,
    confirmations:
        confirmations.present ? confirmations.value : this.confirmations,
    time: time.present ? time.value : this.time,
    blocktime: blocktime.present ? blocktime.value : this.blocktime,
  );
  TransactionsData copyWithCompanion(TransactionsCompanion data) {
    return TransactionsData(
      txid: data.txid.present ? data.txid.value : this.txid,
      version: data.version.present ? data.version.value : this.version,
      size: data.size.present ? data.size.value : this.size,
      vsize: data.vsize.present ? data.vsize.value : this.vsize,
      locktime: data.locktime.present ? data.locktime.value : this.locktime,
      vin: data.vin.present ? data.vin.value : this.vin,
      vout: data.vout.present ? data.vout.value : this.vout,
      blockhash: data.blockhash.present ? data.blockhash.value : this.blockhash,
      height: data.height.present ? data.height.value : this.height,
      confirmations:
          data.confirmations.present
              ? data.confirmations.value
              : this.confirmations,
      time: data.time.present ? data.time.value : this.time,
      blocktime: data.blocktime.present ? data.blocktime.value : this.blocktime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsData(')
          ..write('txid: $txid, ')
          ..write('version: $version, ')
          ..write('size: $size, ')
          ..write('vsize: $vsize, ')
          ..write('locktime: $locktime, ')
          ..write('vin: $vin, ')
          ..write('vout: $vout, ')
          ..write('blockhash: $blockhash, ')
          ..write('height: $height, ')
          ..write('confirmations: $confirmations, ')
          ..write('time: $time, ')
          ..write('blocktime: $blocktime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    txid,
    version,
    size,
    vsize,
    locktime,
    vin,
    vout,
    blockhash,
    height,
    confirmations,
    time,
    blocktime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionsData &&
          other.txid == this.txid &&
          other.version == this.version &&
          other.size == this.size &&
          other.vsize == this.vsize &&
          other.locktime == this.locktime &&
          other.vin == this.vin &&
          other.vout == this.vout &&
          other.blockhash == this.blockhash &&
          other.height == this.height &&
          other.confirmations == this.confirmations &&
          other.time == this.time &&
          other.blocktime == this.blocktime);
}

class TransactionsCompanion extends UpdateCompanion<TransactionsData> {
  final Value<String> txid;
  final Value<int> version;
  final Value<String> size;
  final Value<String> vsize;
  final Value<int> locktime;
  final Value<String> vin;
  final Value<String> vout;
  final Value<String?> blockhash;
  final Value<int?> height;
  final Value<int?> confirmations;
  final Value<int?> time;
  final Value<int?> blocktime;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.txid = const Value.absent(),
    this.version = const Value.absent(),
    this.size = const Value.absent(),
    this.vsize = const Value.absent(),
    this.locktime = const Value.absent(),
    this.vin = const Value.absent(),
    this.vout = const Value.absent(),
    this.blockhash = const Value.absent(),
    this.height = const Value.absent(),
    this.confirmations = const Value.absent(),
    this.time = const Value.absent(),
    this.blocktime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String txid,
    required int version,
    required String size,
    required String vsize,
    required int locktime,
    required String vin,
    required String vout,
    this.blockhash = const Value.absent(),
    this.height = const Value.absent(),
    this.confirmations = const Value.absent(),
    this.time = const Value.absent(),
    this.blocktime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : txid = Value(txid),
       version = Value(version),
       size = Value(size),
       vsize = Value(vsize),
       locktime = Value(locktime),
       vin = Value(vin),
       vout = Value(vout);
  static Insertable<TransactionsData> custom({
    Expression<String>? txid,
    Expression<int>? version,
    Expression<String>? size,
    Expression<String>? vsize,
    Expression<int>? locktime,
    Expression<String>? vin,
    Expression<String>? vout,
    Expression<String>? blockhash,
    Expression<int>? height,
    Expression<int>? confirmations,
    Expression<int>? time,
    Expression<int>? blocktime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (txid != null) 'txid': txid,
      if (version != null) 'version': version,
      if (size != null) 'size': size,
      if (vsize != null) 'vsize': vsize,
      if (locktime != null) 'locktime': locktime,
      if (vin != null) 'vin': vin,
      if (vout != null) 'vout': vout,
      if (blockhash != null) 'blockhash': blockhash,
      if (height != null) 'height': height,
      if (confirmations != null) 'confirmations': confirmations,
      if (time != null) 'time': time,
      if (blocktime != null) 'blocktime': blocktime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? txid,
    Value<int>? version,
    Value<String>? size,
    Value<String>? vsize,
    Value<int>? locktime,
    Value<String>? vin,
    Value<String>? vout,
    Value<String?>? blockhash,
    Value<int?>? height,
    Value<int?>? confirmations,
    Value<int?>? time,
    Value<int?>? blocktime,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      txid: txid ?? this.txid,
      version: version ?? this.version,
      size: size ?? this.size,
      vsize: vsize ?? this.vsize,
      locktime: locktime ?? this.locktime,
      vin: vin ?? this.vin,
      vout: vout ?? this.vout,
      blockhash: blockhash ?? this.blockhash,
      height: height ?? this.height,
      confirmations: confirmations ?? this.confirmations,
      time: time ?? this.time,
      blocktime: blocktime ?? this.blocktime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (txid.present) {
      map['txid'] = Variable<String>(txid.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (size.present) {
      map['size'] = Variable<String>(size.value);
    }
    if (vsize.present) {
      map['vsize'] = Variable<String>(vsize.value);
    }
    if (locktime.present) {
      map['locktime'] = Variable<int>(locktime.value);
    }
    if (vin.present) {
      map['vin'] = Variable<String>(vin.value);
    }
    if (vout.present) {
      map['vout'] = Variable<String>(vout.value);
    }
    if (blockhash.present) {
      map['blockhash'] = Variable<String>(blockhash.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (confirmations.present) {
      map['confirmations'] = Variable<int>(confirmations.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (blocktime.present) {
      map['blocktime'] = Variable<int>(blocktime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('txid: $txid, ')
          ..write('version: $version, ')
          ..write('size: $size, ')
          ..write('vsize: $vsize, ')
          ..write('locktime: $locktime, ')
          ..write('vin: $vin, ')
          ..write('vout: $vout, ')
          ..write('blockhash: $blockhash, ')
          ..write('height: $height, ')
          ..write('confirmations: $confirmations, ')
          ..write('time: $time, ')
          ..write('blocktime: $blocktime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class WalletMetadatas extends Table
    with TableInfo<WalletMetadatas, WalletMetadatasData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  WalletMetadatas(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> masterFingerprint =
      GeneratedColumn<String>(
        'master_fingerprint',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<String> xpubFingerprint = GeneratedColumn<String>(
    'xpub_fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> isEncryptedVaultTested =
      GeneratedColumn<bool>(
        'is_encrypted_vault_tested',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_encrypted_vault_tested" IN (0, 1))',
        ),
      );
  late final GeneratedColumn<bool> isPhysicalBackupTested =
      GeneratedColumn<bool>(
        'is_physical_backup_tested',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_physical_backup_tested" IN (0, 1))',
        ),
      );
  late final GeneratedColumn<int> latestEncryptedBackup = GeneratedColumn<int>(
    'latest_encrypted_backup',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> latestPhysicalBackup = GeneratedColumn<int>(
    'latest_physical_backup',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> xpub = GeneratedColumn<String>(
    'xpub',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> externalPublicDescriptor =
      GeneratedColumn<String>(
        'external_public_descriptor',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<String> internalPublicDescriptor =
      GeneratedColumn<String>(
        'internal_public_descriptor',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    masterFingerprint,
    xpubFingerprint,
    isEncryptedVaultTested,
    isPhysicalBackupTested,
    latestEncryptedBackup,
    latestPhysicalBackup,
    xpub,
    externalPublicDescriptor,
    internalPublicDescriptor,
    source,
    isDefault,
    label,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_metadatas';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletMetadatasData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletMetadatasData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      masterFingerprint:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}master_fingerprint'],
          )!,
      xpubFingerprint:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}xpub_fingerprint'],
          )!,
      isEncryptedVaultTested:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_encrypted_vault_tested'],
          )!,
      isPhysicalBackupTested:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_physical_backup_tested'],
          )!,
      latestEncryptedBackup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latest_encrypted_backup'],
      ),
      latestPhysicalBackup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latest_physical_backup'],
      ),
      xpub:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}xpub'],
          )!,
      externalPublicDescriptor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}external_public_descriptor'],
          )!,
      internalPublicDescriptor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}internal_public_descriptor'],
          )!,
      source:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source'],
          )!,
      isDefault:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_default'],
          )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  WalletMetadatas createAlias(String alias) {
    return WalletMetadatas(attachedDatabase, alias);
  }
}

class WalletMetadatasData extends DataClass
    implements Insertable<WalletMetadatasData> {
  final String id;
  final String masterFingerprint;
  final String xpubFingerprint;
  final bool isEncryptedVaultTested;
  final bool isPhysicalBackupTested;
  final int? latestEncryptedBackup;
  final int? latestPhysicalBackup;
  final String xpub;
  final String externalPublicDescriptor;
  final String internalPublicDescriptor;
  final String source;
  final bool isDefault;
  final String? label;
  final DateTime? syncedAt;
  const WalletMetadatasData({
    required this.id,
    required this.masterFingerprint,
    required this.xpubFingerprint,
    required this.isEncryptedVaultTested,
    required this.isPhysicalBackupTested,
    this.latestEncryptedBackup,
    this.latestPhysicalBackup,
    required this.xpub,
    required this.externalPublicDescriptor,
    required this.internalPublicDescriptor,
    required this.source,
    required this.isDefault,
    this.label,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['master_fingerprint'] = Variable<String>(masterFingerprint);
    map['xpub_fingerprint'] = Variable<String>(xpubFingerprint);
    map['is_encrypted_vault_tested'] = Variable<bool>(isEncryptedVaultTested);
    map['is_physical_backup_tested'] = Variable<bool>(isPhysicalBackupTested);
    if (!nullToAbsent || latestEncryptedBackup != null) {
      map['latest_encrypted_backup'] = Variable<int>(latestEncryptedBackup);
    }
    if (!nullToAbsent || latestPhysicalBackup != null) {
      map['latest_physical_backup'] = Variable<int>(latestPhysicalBackup);
    }
    map['xpub'] = Variable<String>(xpub);
    map['external_public_descriptor'] = Variable<String>(
      externalPublicDescriptor,
    );
    map['internal_public_descriptor'] = Variable<String>(
      internalPublicDescriptor,
    );
    map['source'] = Variable<String>(source);
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  WalletMetadatasCompanion toCompanion(bool nullToAbsent) {
    return WalletMetadatasCompanion(
      id: Value(id),
      masterFingerprint: Value(masterFingerprint),
      xpubFingerprint: Value(xpubFingerprint),
      isEncryptedVaultTested: Value(isEncryptedVaultTested),
      isPhysicalBackupTested: Value(isPhysicalBackupTested),
      latestEncryptedBackup:
          latestEncryptedBackup == null && nullToAbsent
              ? const Value.absent()
              : Value(latestEncryptedBackup),
      latestPhysicalBackup:
          latestPhysicalBackup == null && nullToAbsent
              ? const Value.absent()
              : Value(latestPhysicalBackup),
      xpub: Value(xpub),
      externalPublicDescriptor: Value(externalPublicDescriptor),
      internalPublicDescriptor: Value(internalPublicDescriptor),
      source: Value(source),
      isDefault: Value(isDefault),
      label:
          label == null && nullToAbsent ? const Value.absent() : Value(label),
      syncedAt:
          syncedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(syncedAt),
    );
  }

  factory WalletMetadatasData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletMetadatasData(
      id: serializer.fromJson<String>(json['id']),
      masterFingerprint: serializer.fromJson<String>(json['masterFingerprint']),
      xpubFingerprint: serializer.fromJson<String>(json['xpubFingerprint']),
      isEncryptedVaultTested: serializer.fromJson<bool>(
        json['isEncryptedVaultTested'],
      ),
      isPhysicalBackupTested: serializer.fromJson<bool>(
        json['isPhysicalBackupTested'],
      ),
      latestEncryptedBackup: serializer.fromJson<int?>(
        json['latestEncryptedBackup'],
      ),
      latestPhysicalBackup: serializer.fromJson<int?>(
        json['latestPhysicalBackup'],
      ),
      xpub: serializer.fromJson<String>(json['xpub']),
      externalPublicDescriptor: serializer.fromJson<String>(
        json['externalPublicDescriptor'],
      ),
      internalPublicDescriptor: serializer.fromJson<String>(
        json['internalPublicDescriptor'],
      ),
      source: serializer.fromJson<String>(json['source']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      label: serializer.fromJson<String?>(json['label']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'masterFingerprint': serializer.toJson<String>(masterFingerprint),
      'xpubFingerprint': serializer.toJson<String>(xpubFingerprint),
      'isEncryptedVaultTested': serializer.toJson<bool>(isEncryptedVaultTested),
      'isPhysicalBackupTested': serializer.toJson<bool>(isPhysicalBackupTested),
      'latestEncryptedBackup': serializer.toJson<int?>(latestEncryptedBackup),
      'latestPhysicalBackup': serializer.toJson<int?>(latestPhysicalBackup),
      'xpub': serializer.toJson<String>(xpub),
      'externalPublicDescriptor': serializer.toJson<String>(
        externalPublicDescriptor,
      ),
      'internalPublicDescriptor': serializer.toJson<String>(
        internalPublicDescriptor,
      ),
      'source': serializer.toJson<String>(source),
      'isDefault': serializer.toJson<bool>(isDefault),
      'label': serializer.toJson<String?>(label),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  WalletMetadatasData copyWith({
    String? id,
    String? masterFingerprint,
    String? xpubFingerprint,
    bool? isEncryptedVaultTested,
    bool? isPhysicalBackupTested,
    Value<int?> latestEncryptedBackup = const Value.absent(),
    Value<int?> latestPhysicalBackup = const Value.absent(),
    String? xpub,
    String? externalPublicDescriptor,
    String? internalPublicDescriptor,
    String? source,
    bool? isDefault,
    Value<String?> label = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => WalletMetadatasData(
    id: id ?? this.id,
    masterFingerprint: masterFingerprint ?? this.masterFingerprint,
    xpubFingerprint: xpubFingerprint ?? this.xpubFingerprint,
    isEncryptedVaultTested:
        isEncryptedVaultTested ?? this.isEncryptedVaultTested,
    isPhysicalBackupTested:
        isPhysicalBackupTested ?? this.isPhysicalBackupTested,
    latestEncryptedBackup:
        latestEncryptedBackup.present
            ? latestEncryptedBackup.value
            : this.latestEncryptedBackup,
    latestPhysicalBackup:
        latestPhysicalBackup.present
            ? latestPhysicalBackup.value
            : this.latestPhysicalBackup,
    xpub: xpub ?? this.xpub,
    externalPublicDescriptor:
        externalPublicDescriptor ?? this.externalPublicDescriptor,
    internalPublicDescriptor:
        internalPublicDescriptor ?? this.internalPublicDescriptor,
    source: source ?? this.source,
    isDefault: isDefault ?? this.isDefault,
    label: label.present ? label.value : this.label,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  WalletMetadatasData copyWithCompanion(WalletMetadatasCompanion data) {
    return WalletMetadatasData(
      id: data.id.present ? data.id.value : this.id,
      masterFingerprint:
          data.masterFingerprint.present
              ? data.masterFingerprint.value
              : this.masterFingerprint,
      xpubFingerprint:
          data.xpubFingerprint.present
              ? data.xpubFingerprint.value
              : this.xpubFingerprint,
      isEncryptedVaultTested:
          data.isEncryptedVaultTested.present
              ? data.isEncryptedVaultTested.value
              : this.isEncryptedVaultTested,
      isPhysicalBackupTested:
          data.isPhysicalBackupTested.present
              ? data.isPhysicalBackupTested.value
              : this.isPhysicalBackupTested,
      latestEncryptedBackup:
          data.latestEncryptedBackup.present
              ? data.latestEncryptedBackup.value
              : this.latestEncryptedBackup,
      latestPhysicalBackup:
          data.latestPhysicalBackup.present
              ? data.latestPhysicalBackup.value
              : this.latestPhysicalBackup,
      xpub: data.xpub.present ? data.xpub.value : this.xpub,
      externalPublicDescriptor:
          data.externalPublicDescriptor.present
              ? data.externalPublicDescriptor.value
              : this.externalPublicDescriptor,
      internalPublicDescriptor:
          data.internalPublicDescriptor.present
              ? data.internalPublicDescriptor.value
              : this.internalPublicDescriptor,
      source: data.source.present ? data.source.value : this.source,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      label: data.label.present ? data.label.value : this.label,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletMetadatasData(')
          ..write('id: $id, ')
          ..write('masterFingerprint: $masterFingerprint, ')
          ..write('xpubFingerprint: $xpubFingerprint, ')
          ..write('isEncryptedVaultTested: $isEncryptedVaultTested, ')
          ..write('isPhysicalBackupTested: $isPhysicalBackupTested, ')
          ..write('latestEncryptedBackup: $latestEncryptedBackup, ')
          ..write('latestPhysicalBackup: $latestPhysicalBackup, ')
          ..write('xpub: $xpub, ')
          ..write('externalPublicDescriptor: $externalPublicDescriptor, ')
          ..write('internalPublicDescriptor: $internalPublicDescriptor, ')
          ..write('source: $source, ')
          ..write('isDefault: $isDefault, ')
          ..write('label: $label, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    masterFingerprint,
    xpubFingerprint,
    isEncryptedVaultTested,
    isPhysicalBackupTested,
    latestEncryptedBackup,
    latestPhysicalBackup,
    xpub,
    externalPublicDescriptor,
    internalPublicDescriptor,
    source,
    isDefault,
    label,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletMetadatasData &&
          other.id == this.id &&
          other.masterFingerprint == this.masterFingerprint &&
          other.xpubFingerprint == this.xpubFingerprint &&
          other.isEncryptedVaultTested == this.isEncryptedVaultTested &&
          other.isPhysicalBackupTested == this.isPhysicalBackupTested &&
          other.latestEncryptedBackup == this.latestEncryptedBackup &&
          other.latestPhysicalBackup == this.latestPhysicalBackup &&
          other.xpub == this.xpub &&
          other.externalPublicDescriptor == this.externalPublicDescriptor &&
          other.internalPublicDescriptor == this.internalPublicDescriptor &&
          other.source == this.source &&
          other.isDefault == this.isDefault &&
          other.label == this.label &&
          other.syncedAt == this.syncedAt);
}

class WalletMetadatasCompanion extends UpdateCompanion<WalletMetadatasData> {
  final Value<String> id;
  final Value<String> masterFingerprint;
  final Value<String> xpubFingerprint;
  final Value<bool> isEncryptedVaultTested;
  final Value<bool> isPhysicalBackupTested;
  final Value<int?> latestEncryptedBackup;
  final Value<int?> latestPhysicalBackup;
  final Value<String> xpub;
  final Value<String> externalPublicDescriptor;
  final Value<String> internalPublicDescriptor;
  final Value<String> source;
  final Value<bool> isDefault;
  final Value<String?> label;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const WalletMetadatasCompanion({
    this.id = const Value.absent(),
    this.masterFingerprint = const Value.absent(),
    this.xpubFingerprint = const Value.absent(),
    this.isEncryptedVaultTested = const Value.absent(),
    this.isPhysicalBackupTested = const Value.absent(),
    this.latestEncryptedBackup = const Value.absent(),
    this.latestPhysicalBackup = const Value.absent(),
    this.xpub = const Value.absent(),
    this.externalPublicDescriptor = const Value.absent(),
    this.internalPublicDescriptor = const Value.absent(),
    this.source = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.label = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletMetadatasCompanion.insert({
    required String id,
    required String masterFingerprint,
    required String xpubFingerprint,
    required bool isEncryptedVaultTested,
    required bool isPhysicalBackupTested,
    this.latestEncryptedBackup = const Value.absent(),
    this.latestPhysicalBackup = const Value.absent(),
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required String source,
    required bool isDefault,
    this.label = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       masterFingerprint = Value(masterFingerprint),
       xpubFingerprint = Value(xpubFingerprint),
       isEncryptedVaultTested = Value(isEncryptedVaultTested),
       isPhysicalBackupTested = Value(isPhysicalBackupTested),
       xpub = Value(xpub),
       externalPublicDescriptor = Value(externalPublicDescriptor),
       internalPublicDescriptor = Value(internalPublicDescriptor),
       source = Value(source),
       isDefault = Value(isDefault);
  static Insertable<WalletMetadatasData> custom({
    Expression<String>? id,
    Expression<String>? masterFingerprint,
    Expression<String>? xpubFingerprint,
    Expression<bool>? isEncryptedVaultTested,
    Expression<bool>? isPhysicalBackupTested,
    Expression<int>? latestEncryptedBackup,
    Expression<int>? latestPhysicalBackup,
    Expression<String>? xpub,
    Expression<String>? externalPublicDescriptor,
    Expression<String>? internalPublicDescriptor,
    Expression<String>? source,
    Expression<bool>? isDefault,
    Expression<String>? label,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (masterFingerprint != null) 'master_fingerprint': masterFingerprint,
      if (xpubFingerprint != null) 'xpub_fingerprint': xpubFingerprint,
      if (isEncryptedVaultTested != null)
        'is_encrypted_vault_tested': isEncryptedVaultTested,
      if (isPhysicalBackupTested != null)
        'is_physical_backup_tested': isPhysicalBackupTested,
      if (latestEncryptedBackup != null)
        'latest_encrypted_backup': latestEncryptedBackup,
      if (latestPhysicalBackup != null)
        'latest_physical_backup': latestPhysicalBackup,
      if (xpub != null) 'xpub': xpub,
      if (externalPublicDescriptor != null)
        'external_public_descriptor': externalPublicDescriptor,
      if (internalPublicDescriptor != null)
        'internal_public_descriptor': internalPublicDescriptor,
      if (source != null) 'source': source,
      if (isDefault != null) 'is_default': isDefault,
      if (label != null) 'label': label,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletMetadatasCompanion copyWith({
    Value<String>? id,
    Value<String>? masterFingerprint,
    Value<String>? xpubFingerprint,
    Value<bool>? isEncryptedVaultTested,
    Value<bool>? isPhysicalBackupTested,
    Value<int?>? latestEncryptedBackup,
    Value<int?>? latestPhysicalBackup,
    Value<String>? xpub,
    Value<String>? externalPublicDescriptor,
    Value<String>? internalPublicDescriptor,
    Value<String>? source,
    Value<bool>? isDefault,
    Value<String?>? label,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return WalletMetadatasCompanion(
      id: id ?? this.id,
      masterFingerprint: masterFingerprint ?? this.masterFingerprint,
      xpubFingerprint: xpubFingerprint ?? this.xpubFingerprint,
      isEncryptedVaultTested:
          isEncryptedVaultTested ?? this.isEncryptedVaultTested,
      isPhysicalBackupTested:
          isPhysicalBackupTested ?? this.isPhysicalBackupTested,
      latestEncryptedBackup:
          latestEncryptedBackup ?? this.latestEncryptedBackup,
      latestPhysicalBackup: latestPhysicalBackup ?? this.latestPhysicalBackup,
      xpub: xpub ?? this.xpub,
      externalPublicDescriptor:
          externalPublicDescriptor ?? this.externalPublicDescriptor,
      internalPublicDescriptor:
          internalPublicDescriptor ?? this.internalPublicDescriptor,
      source: source ?? this.source,
      isDefault: isDefault ?? this.isDefault,
      label: label ?? this.label,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (masterFingerprint.present) {
      map['master_fingerprint'] = Variable<String>(masterFingerprint.value);
    }
    if (xpubFingerprint.present) {
      map['xpub_fingerprint'] = Variable<String>(xpubFingerprint.value);
    }
    if (isEncryptedVaultTested.present) {
      map['is_encrypted_vault_tested'] = Variable<bool>(
        isEncryptedVaultTested.value,
      );
    }
    if (isPhysicalBackupTested.present) {
      map['is_physical_backup_tested'] = Variable<bool>(
        isPhysicalBackupTested.value,
      );
    }
    if (latestEncryptedBackup.present) {
      map['latest_encrypted_backup'] = Variable<int>(
        latestEncryptedBackup.value,
      );
    }
    if (latestPhysicalBackup.present) {
      map['latest_physical_backup'] = Variable<int>(latestPhysicalBackup.value);
    }
    if (xpub.present) {
      map['xpub'] = Variable<String>(xpub.value);
    }
    if (externalPublicDescriptor.present) {
      map['external_public_descriptor'] = Variable<String>(
        externalPublicDescriptor.value,
      );
    }
    if (internalPublicDescriptor.present) {
      map['internal_public_descriptor'] = Variable<String>(
        internalPublicDescriptor.value,
      );
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletMetadatasCompanion(')
          ..write('id: $id, ')
          ..write('masterFingerprint: $masterFingerprint, ')
          ..write('xpubFingerprint: $xpubFingerprint, ')
          ..write('isEncryptedVaultTested: $isEncryptedVaultTested, ')
          ..write('isPhysicalBackupTested: $isPhysicalBackupTested, ')
          ..write('latestEncryptedBackup: $latestEncryptedBackup, ')
          ..write('latestPhysicalBackup: $latestPhysicalBackup, ')
          ..write('xpub: $xpub, ')
          ..write('externalPublicDescriptor: $externalPublicDescriptor, ')
          ..write('internalPublicDescriptor: $internalPublicDescriptor, ')
          ..write('source: $source, ')
          ..write('isDefault: $isDefault, ')
          ..write('label: $label, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Labels extends Table with TableInfo<Labels, LabelsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Labels(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> ref = GeneratedColumn<String>(
    'ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<bool> spendable = GeneratedColumn<bool>(
    'spendable',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("spendable" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [label, ref, type, origin, spendable];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'labels';
  @override
  Set<GeneratedColumn> get $primaryKey => {label, ref};
  @override
  LabelsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LabelsData(
      label:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}label'],
          )!,
      ref:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}ref'],
          )!,
      type:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}type'],
          )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      ),
      spendable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}spendable'],
      ),
    );
  }

  @override
  Labels createAlias(String alias) {
    return Labels(attachedDatabase, alias);
  }
}

class LabelsData extends DataClass implements Insertable<LabelsData> {
  final String label;
  final String ref;
  final String type;
  final String? origin;
  final bool? spendable;
  const LabelsData({
    required this.label,
    required this.ref,
    required this.type,
    this.origin,
    this.spendable,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['label'] = Variable<String>(label);
    map['ref'] = Variable<String>(ref);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    if (!nullToAbsent || spendable != null) {
      map['spendable'] = Variable<bool>(spendable);
    }
    return map;
  }

  LabelsCompanion toCompanion(bool nullToAbsent) {
    return LabelsCompanion(
      label: Value(label),
      ref: Value(ref),
      type: Value(type),
      origin:
          origin == null && nullToAbsent ? const Value.absent() : Value(origin),
      spendable:
          spendable == null && nullToAbsent
              ? const Value.absent()
              : Value(spendable),
    );
  }

  factory LabelsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LabelsData(
      label: serializer.fromJson<String>(json['label']),
      ref: serializer.fromJson<String>(json['ref']),
      type: serializer.fromJson<String>(json['type']),
      origin: serializer.fromJson<String?>(json['origin']),
      spendable: serializer.fromJson<bool?>(json['spendable']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'label': serializer.toJson<String>(label),
      'ref': serializer.toJson<String>(ref),
      'type': serializer.toJson<String>(type),
      'origin': serializer.toJson<String?>(origin),
      'spendable': serializer.toJson<bool?>(spendable),
    };
  }

  LabelsData copyWith({
    String? label,
    String? ref,
    String? type,
    Value<String?> origin = const Value.absent(),
    Value<bool?> spendable = const Value.absent(),
  }) => LabelsData(
    label: label ?? this.label,
    ref: ref ?? this.ref,
    type: type ?? this.type,
    origin: origin.present ? origin.value : this.origin,
    spendable: spendable.present ? spendable.value : this.spendable,
  );
  LabelsData copyWithCompanion(LabelsCompanion data) {
    return LabelsData(
      label: data.label.present ? data.label.value : this.label,
      ref: data.ref.present ? data.ref.value : this.ref,
      type: data.type.present ? data.type.value : this.type,
      origin: data.origin.present ? data.origin.value : this.origin,
      spendable: data.spendable.present ? data.spendable.value : this.spendable,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LabelsData(')
          ..write('label: $label, ')
          ..write('ref: $ref, ')
          ..write('type: $type, ')
          ..write('origin: $origin, ')
          ..write('spendable: $spendable')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(label, ref, type, origin, spendable);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LabelsData &&
          other.label == this.label &&
          other.ref == this.ref &&
          other.type == this.type &&
          other.origin == this.origin &&
          other.spendable == this.spendable);
}

class LabelsCompanion extends UpdateCompanion<LabelsData> {
  final Value<String> label;
  final Value<String> ref;
  final Value<String> type;
  final Value<String?> origin;
  final Value<bool?> spendable;
  final Value<int> rowid;
  const LabelsCompanion({
    this.label = const Value.absent(),
    this.ref = const Value.absent(),
    this.type = const Value.absent(),
    this.origin = const Value.absent(),
    this.spendable = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LabelsCompanion.insert({
    required String label,
    required String ref,
    required String type,
    this.origin = const Value.absent(),
    this.spendable = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : label = Value(label),
       ref = Value(ref),
       type = Value(type);
  static Insertable<LabelsData> custom({
    Expression<String>? label,
    Expression<String>? ref,
    Expression<String>? type,
    Expression<String>? origin,
    Expression<bool>? spendable,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (label != null) 'label': label,
      if (ref != null) 'ref': ref,
      if (type != null) 'type': type,
      if (origin != null) 'origin': origin,
      if (spendable != null) 'spendable': spendable,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LabelsCompanion copyWith({
    Value<String>? label,
    Value<String>? ref,
    Value<String>? type,
    Value<String?>? origin,
    Value<bool?>? spendable,
    Value<int>? rowid,
  }) {
    return LabelsCompanion(
      label: label ?? this.label,
      ref: ref ?? this.ref,
      type: type ?? this.type,
      origin: origin ?? this.origin,
      spendable: spendable ?? this.spendable,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (ref.present) {
      map['ref'] = Variable<String>(ref.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (spendable.present) {
      map['spendable'] = Variable<bool>(spendable.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LabelsCompanion(')
          ..write('label: $label, ')
          ..write('ref: $ref, ')
          ..write('type: $type, ')
          ..write('origin: $origin, ')
          ..write('spendable: $spendable, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Settings extends Table with TableInfo<Settings, SettingsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Settings(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  late final GeneratedColumn<String> environment = GeneratedColumn<String>(
    'environment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> bitcoinUnit = GeneratedColumn<String>(
    'bitcoin_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> hideAmounts = GeneratedColumn<bool>(
    'hide_amounts',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hide_amounts" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<bool> isSuperuser = GeneratedColumn<bool>(
    'is_superuser',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_superuser" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    environment,
    bitcoinUnit,
    language,
    currency,
    hideAmounts,
    isSuperuser,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      environment:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}environment'],
          )!,
      bitcoinUnit:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}bitcoin_unit'],
          )!,
      language:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}language'],
          )!,
      currency:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}currency'],
          )!,
      hideAmounts:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}hide_amounts'],
          )!,
      isSuperuser:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_superuser'],
          )!,
    );
  }

  @override
  Settings createAlias(String alias) {
    return Settings(attachedDatabase, alias);
  }
}

class SettingsData extends DataClass implements Insertable<SettingsData> {
  final int id;
  final String environment;
  final String bitcoinUnit;
  final String language;
  final String currency;
  final bool hideAmounts;
  final bool isSuperuser;
  const SettingsData({
    required this.id,
    required this.environment,
    required this.bitcoinUnit,
    required this.language,
    required this.currency,
    required this.hideAmounts,
    required this.isSuperuser,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['environment'] = Variable<String>(environment);
    map['bitcoin_unit'] = Variable<String>(bitcoinUnit);
    map['language'] = Variable<String>(language);
    map['currency'] = Variable<String>(currency);
    map['hide_amounts'] = Variable<bool>(hideAmounts);
    map['is_superuser'] = Variable<bool>(isSuperuser);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      environment: Value(environment),
      bitcoinUnit: Value(bitcoinUnit),
      language: Value(language),
      currency: Value(currency),
      hideAmounts: Value(hideAmounts),
      isSuperuser: Value(isSuperuser),
    );
  }

  factory SettingsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsData(
      id: serializer.fromJson<int>(json['id']),
      environment: serializer.fromJson<String>(json['environment']),
      bitcoinUnit: serializer.fromJson<String>(json['bitcoinUnit']),
      language: serializer.fromJson<String>(json['language']),
      currency: serializer.fromJson<String>(json['currency']),
      hideAmounts: serializer.fromJson<bool>(json['hideAmounts']),
      isSuperuser: serializer.fromJson<bool>(json['isSuperuser']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'environment': serializer.toJson<String>(environment),
      'bitcoinUnit': serializer.toJson<String>(bitcoinUnit),
      'language': serializer.toJson<String>(language),
      'currency': serializer.toJson<String>(currency),
      'hideAmounts': serializer.toJson<bool>(hideAmounts),
      'isSuperuser': serializer.toJson<bool>(isSuperuser),
    };
  }

  SettingsData copyWith({
    int? id,
    String? environment,
    String? bitcoinUnit,
    String? language,
    String? currency,
    bool? hideAmounts,
    bool? isSuperuser,
  }) => SettingsData(
    id: id ?? this.id,
    environment: environment ?? this.environment,
    bitcoinUnit: bitcoinUnit ?? this.bitcoinUnit,
    language: language ?? this.language,
    currency: currency ?? this.currency,
    hideAmounts: hideAmounts ?? this.hideAmounts,
    isSuperuser: isSuperuser ?? this.isSuperuser,
  );
  SettingsData copyWithCompanion(SettingsCompanion data) {
    return SettingsData(
      id: data.id.present ? data.id.value : this.id,
      environment:
          data.environment.present ? data.environment.value : this.environment,
      bitcoinUnit:
          data.bitcoinUnit.present ? data.bitcoinUnit.value : this.bitcoinUnit,
      language: data.language.present ? data.language.value : this.language,
      currency: data.currency.present ? data.currency.value : this.currency,
      hideAmounts:
          data.hideAmounts.present ? data.hideAmounts.value : this.hideAmounts,
      isSuperuser:
          data.isSuperuser.present ? data.isSuperuser.value : this.isSuperuser,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsData(')
          ..write('id: $id, ')
          ..write('environment: $environment, ')
          ..write('bitcoinUnit: $bitcoinUnit, ')
          ..write('language: $language, ')
          ..write('currency: $currency, ')
          ..write('hideAmounts: $hideAmounts, ')
          ..write('isSuperuser: $isSuperuser')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    environment,
    bitcoinUnit,
    language,
    currency,
    hideAmounts,
    isSuperuser,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsData &&
          other.id == this.id &&
          other.environment == this.environment &&
          other.bitcoinUnit == this.bitcoinUnit &&
          other.language == this.language &&
          other.currency == this.currency &&
          other.hideAmounts == this.hideAmounts &&
          other.isSuperuser == this.isSuperuser);
}

class SettingsCompanion extends UpdateCompanion<SettingsData> {
  final Value<int> id;
  final Value<String> environment;
  final Value<String> bitcoinUnit;
  final Value<String> language;
  final Value<String> currency;
  final Value<bool> hideAmounts;
  final Value<bool> isSuperuser;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.environment = const Value.absent(),
    this.bitcoinUnit = const Value.absent(),
    this.language = const Value.absent(),
    this.currency = const Value.absent(),
    this.hideAmounts = const Value.absent(),
    this.isSuperuser = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    required String environment,
    required String bitcoinUnit,
    required String language,
    required String currency,
    required bool hideAmounts,
    required bool isSuperuser,
  }) : environment = Value(environment),
       bitcoinUnit = Value(bitcoinUnit),
       language = Value(language),
       currency = Value(currency),
       hideAmounts = Value(hideAmounts),
       isSuperuser = Value(isSuperuser);
  static Insertable<SettingsData> custom({
    Expression<int>? id,
    Expression<String>? environment,
    Expression<String>? bitcoinUnit,
    Expression<String>? language,
    Expression<String>? currency,
    Expression<bool>? hideAmounts,
    Expression<bool>? isSuperuser,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (environment != null) 'environment': environment,
      if (bitcoinUnit != null) 'bitcoin_unit': bitcoinUnit,
      if (language != null) 'language': language,
      if (currency != null) 'currency': currency,
      if (hideAmounts != null) 'hide_amounts': hideAmounts,
      if (isSuperuser != null) 'is_superuser': isSuperuser,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? environment,
    Value<String>? bitcoinUnit,
    Value<String>? language,
    Value<String>? currency,
    Value<bool>? hideAmounts,
    Value<bool>? isSuperuser,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      environment: environment ?? this.environment,
      bitcoinUnit: bitcoinUnit ?? this.bitcoinUnit,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      hideAmounts: hideAmounts ?? this.hideAmounts,
      isSuperuser: isSuperuser ?? this.isSuperuser,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (environment.present) {
      map['environment'] = Variable<String>(environment.value);
    }
    if (bitcoinUnit.present) {
      map['bitcoin_unit'] = Variable<String>(bitcoinUnit.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (hideAmounts.present) {
      map['hide_amounts'] = Variable<bool>(hideAmounts.value);
    }
    if (isSuperuser.present) {
      map['is_superuser'] = Variable<bool>(isSuperuser.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('environment: $environment, ')
          ..write('bitcoinUnit: $bitcoinUnit, ')
          ..write('language: $language, ')
          ..write('currency: $currency, ')
          ..write('hideAmounts: $hideAmounts, ')
          ..write('isSuperuser: $isSuperuser')
          ..write(')'))
        .toString();
  }
}

class PayjoinSenders extends Table
    with TableInfo<PayjoinSenders, PayjoinSendersData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PayjoinSenders(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> isTestnet = GeneratedColumn<bool>(
    'is_testnet',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_testnet" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
    'sender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
    'wallet_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> originalPsbt = GeneratedColumn<String>(
    'original_psbt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> originalTxId = GeneratedColumn<String>(
    'original_tx_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> amountSat = GeneratedColumn<int>(
    'amount_sat',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> expireAfterSec = GeneratedColumn<int>(
    'expire_after_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> proposalPsbt = GeneratedColumn<String>(
    'proposal_psbt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> txId = GeneratedColumn<String>(
    'tx_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<bool> isExpired = GeneratedColumn<bool>(
    'is_expired',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_expired" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    uri,
    isTestnet,
    sender,
    walletId,
    originalPsbt,
    originalTxId,
    amountSat,
    createdAt,
    expireAfterSec,
    proposalPsbt,
    txId,
    isExpired,
    isCompleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payjoin_senders';
  @override
  Set<GeneratedColumn> get $primaryKey => {uri};
  @override
  PayjoinSendersData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayjoinSendersData(
      uri:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}uri'],
          )!,
      isTestnet:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_testnet'],
          )!,
      sender:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}sender'],
          )!,
      walletId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}wallet_id'],
          )!,
      originalPsbt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}original_psbt'],
          )!,
      originalTxId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}original_tx_id'],
          )!,
      amountSat:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}amount_sat'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}created_at'],
          )!,
      expireAfterSec:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}expire_after_sec'],
          )!,
      proposalPsbt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proposal_psbt'],
      ),
      txId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tx_id'],
      ),
      isExpired:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_expired'],
          )!,
      isCompleted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_completed'],
          )!,
    );
  }

  @override
  PayjoinSenders createAlias(String alias) {
    return PayjoinSenders(attachedDatabase, alias);
  }
}

class PayjoinSendersData extends DataClass
    implements Insertable<PayjoinSendersData> {
  final String uri;
  final bool isTestnet;
  final String sender;
  final String walletId;
  final String originalPsbt;
  final String originalTxId;
  final int amountSat;
  final int createdAt;
  final int expireAfterSec;
  final String? proposalPsbt;
  final String? txId;
  final bool isExpired;
  final bool isCompleted;
  const PayjoinSendersData({
    required this.uri,
    required this.isTestnet,
    required this.sender,
    required this.walletId,
    required this.originalPsbt,
    required this.originalTxId,
    required this.amountSat,
    required this.createdAt,
    required this.expireAfterSec,
    this.proposalPsbt,
    this.txId,
    required this.isExpired,
    required this.isCompleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uri'] = Variable<String>(uri);
    map['is_testnet'] = Variable<bool>(isTestnet);
    map['sender'] = Variable<String>(sender);
    map['wallet_id'] = Variable<String>(walletId);
    map['original_psbt'] = Variable<String>(originalPsbt);
    map['original_tx_id'] = Variable<String>(originalTxId);
    map['amount_sat'] = Variable<int>(amountSat);
    map['created_at'] = Variable<int>(createdAt);
    map['expire_after_sec'] = Variable<int>(expireAfterSec);
    if (!nullToAbsent || proposalPsbt != null) {
      map['proposal_psbt'] = Variable<String>(proposalPsbt);
    }
    if (!nullToAbsent || txId != null) {
      map['tx_id'] = Variable<String>(txId);
    }
    map['is_expired'] = Variable<bool>(isExpired);
    map['is_completed'] = Variable<bool>(isCompleted);
    return map;
  }

  PayjoinSendersCompanion toCompanion(bool nullToAbsent) {
    return PayjoinSendersCompanion(
      uri: Value(uri),
      isTestnet: Value(isTestnet),
      sender: Value(sender),
      walletId: Value(walletId),
      originalPsbt: Value(originalPsbt),
      originalTxId: Value(originalTxId),
      amountSat: Value(amountSat),
      createdAt: Value(createdAt),
      expireAfterSec: Value(expireAfterSec),
      proposalPsbt:
          proposalPsbt == null && nullToAbsent
              ? const Value.absent()
              : Value(proposalPsbt),
      txId: txId == null && nullToAbsent ? const Value.absent() : Value(txId),
      isExpired: Value(isExpired),
      isCompleted: Value(isCompleted),
    );
  }

  factory PayjoinSendersData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayjoinSendersData(
      uri: serializer.fromJson<String>(json['uri']),
      isTestnet: serializer.fromJson<bool>(json['isTestnet']),
      sender: serializer.fromJson<String>(json['sender']),
      walletId: serializer.fromJson<String>(json['walletId']),
      originalPsbt: serializer.fromJson<String>(json['originalPsbt']),
      originalTxId: serializer.fromJson<String>(json['originalTxId']),
      amountSat: serializer.fromJson<int>(json['amountSat']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      expireAfterSec: serializer.fromJson<int>(json['expireAfterSec']),
      proposalPsbt: serializer.fromJson<String?>(json['proposalPsbt']),
      txId: serializer.fromJson<String?>(json['txId']),
      isExpired: serializer.fromJson<bool>(json['isExpired']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uri': serializer.toJson<String>(uri),
      'isTestnet': serializer.toJson<bool>(isTestnet),
      'sender': serializer.toJson<String>(sender),
      'walletId': serializer.toJson<String>(walletId),
      'originalPsbt': serializer.toJson<String>(originalPsbt),
      'originalTxId': serializer.toJson<String>(originalTxId),
      'amountSat': serializer.toJson<int>(amountSat),
      'createdAt': serializer.toJson<int>(createdAt),
      'expireAfterSec': serializer.toJson<int>(expireAfterSec),
      'proposalPsbt': serializer.toJson<String?>(proposalPsbt),
      'txId': serializer.toJson<String?>(txId),
      'isExpired': serializer.toJson<bool>(isExpired),
      'isCompleted': serializer.toJson<bool>(isCompleted),
    };
  }

  PayjoinSendersData copyWith({
    String? uri,
    bool? isTestnet,
    String? sender,
    String? walletId,
    String? originalPsbt,
    String? originalTxId,
    int? amountSat,
    int? createdAt,
    int? expireAfterSec,
    Value<String?> proposalPsbt = const Value.absent(),
    Value<String?> txId = const Value.absent(),
    bool? isExpired,
    bool? isCompleted,
  }) => PayjoinSendersData(
    uri: uri ?? this.uri,
    isTestnet: isTestnet ?? this.isTestnet,
    sender: sender ?? this.sender,
    walletId: walletId ?? this.walletId,
    originalPsbt: originalPsbt ?? this.originalPsbt,
    originalTxId: originalTxId ?? this.originalTxId,
    amountSat: amountSat ?? this.amountSat,
    createdAt: createdAt ?? this.createdAt,
    expireAfterSec: expireAfterSec ?? this.expireAfterSec,
    proposalPsbt: proposalPsbt.present ? proposalPsbt.value : this.proposalPsbt,
    txId: txId.present ? txId.value : this.txId,
    isExpired: isExpired ?? this.isExpired,
    isCompleted: isCompleted ?? this.isCompleted,
  );
  PayjoinSendersData copyWithCompanion(PayjoinSendersCompanion data) {
    return PayjoinSendersData(
      uri: data.uri.present ? data.uri.value : this.uri,
      isTestnet: data.isTestnet.present ? data.isTestnet.value : this.isTestnet,
      sender: data.sender.present ? data.sender.value : this.sender,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      originalPsbt:
          data.originalPsbt.present
              ? data.originalPsbt.value
              : this.originalPsbt,
      originalTxId:
          data.originalTxId.present
              ? data.originalTxId.value
              : this.originalTxId,
      amountSat: data.amountSat.present ? data.amountSat.value : this.amountSat,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expireAfterSec:
          data.expireAfterSec.present
              ? data.expireAfterSec.value
              : this.expireAfterSec,
      proposalPsbt:
          data.proposalPsbt.present
              ? data.proposalPsbt.value
              : this.proposalPsbt,
      txId: data.txId.present ? data.txId.value : this.txId,
      isExpired: data.isExpired.present ? data.isExpired.value : this.isExpired,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayjoinSendersData(')
          ..write('uri: $uri, ')
          ..write('isTestnet: $isTestnet, ')
          ..write('sender: $sender, ')
          ..write('walletId: $walletId, ')
          ..write('originalPsbt: $originalPsbt, ')
          ..write('originalTxId: $originalTxId, ')
          ..write('amountSat: $amountSat, ')
          ..write('createdAt: $createdAt, ')
          ..write('expireAfterSec: $expireAfterSec, ')
          ..write('proposalPsbt: $proposalPsbt, ')
          ..write('txId: $txId, ')
          ..write('isExpired: $isExpired, ')
          ..write('isCompleted: $isCompleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uri,
    isTestnet,
    sender,
    walletId,
    originalPsbt,
    originalTxId,
    amountSat,
    createdAt,
    expireAfterSec,
    proposalPsbt,
    txId,
    isExpired,
    isCompleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayjoinSendersData &&
          other.uri == this.uri &&
          other.isTestnet == this.isTestnet &&
          other.sender == this.sender &&
          other.walletId == this.walletId &&
          other.originalPsbt == this.originalPsbt &&
          other.originalTxId == this.originalTxId &&
          other.amountSat == this.amountSat &&
          other.createdAt == this.createdAt &&
          other.expireAfterSec == this.expireAfterSec &&
          other.proposalPsbt == this.proposalPsbt &&
          other.txId == this.txId &&
          other.isExpired == this.isExpired &&
          other.isCompleted == this.isCompleted);
}

class PayjoinSendersCompanion extends UpdateCompanion<PayjoinSendersData> {
  final Value<String> uri;
  final Value<bool> isTestnet;
  final Value<String> sender;
  final Value<String> walletId;
  final Value<String> originalPsbt;
  final Value<String> originalTxId;
  final Value<int> amountSat;
  final Value<int> createdAt;
  final Value<int> expireAfterSec;
  final Value<String?> proposalPsbt;
  final Value<String?> txId;
  final Value<bool> isExpired;
  final Value<bool> isCompleted;
  final Value<int> rowid;
  const PayjoinSendersCompanion({
    this.uri = const Value.absent(),
    this.isTestnet = const Value.absent(),
    this.sender = const Value.absent(),
    this.walletId = const Value.absent(),
    this.originalPsbt = const Value.absent(),
    this.originalTxId = const Value.absent(),
    this.amountSat = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expireAfterSec = const Value.absent(),
    this.proposalPsbt = const Value.absent(),
    this.txId = const Value.absent(),
    this.isExpired = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayjoinSendersCompanion.insert({
    required String uri,
    required bool isTestnet,
    required String sender,
    required String walletId,
    required String originalPsbt,
    required String originalTxId,
    required int amountSat,
    required int createdAt,
    required int expireAfterSec,
    this.proposalPsbt = const Value.absent(),
    this.txId = const Value.absent(),
    required bool isExpired,
    required bool isCompleted,
    this.rowid = const Value.absent(),
  }) : uri = Value(uri),
       isTestnet = Value(isTestnet),
       sender = Value(sender),
       walletId = Value(walletId),
       originalPsbt = Value(originalPsbt),
       originalTxId = Value(originalTxId),
       amountSat = Value(amountSat),
       createdAt = Value(createdAt),
       expireAfterSec = Value(expireAfterSec),
       isExpired = Value(isExpired),
       isCompleted = Value(isCompleted);
  static Insertable<PayjoinSendersData> custom({
    Expression<String>? uri,
    Expression<bool>? isTestnet,
    Expression<String>? sender,
    Expression<String>? walletId,
    Expression<String>? originalPsbt,
    Expression<String>? originalTxId,
    Expression<int>? amountSat,
    Expression<int>? createdAt,
    Expression<int>? expireAfterSec,
    Expression<String>? proposalPsbt,
    Expression<String>? txId,
    Expression<bool>? isExpired,
    Expression<bool>? isCompleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uri != null) 'uri': uri,
      if (isTestnet != null) 'is_testnet': isTestnet,
      if (sender != null) 'sender': sender,
      if (walletId != null) 'wallet_id': walletId,
      if (originalPsbt != null) 'original_psbt': originalPsbt,
      if (originalTxId != null) 'original_tx_id': originalTxId,
      if (amountSat != null) 'amount_sat': amountSat,
      if (createdAt != null) 'created_at': createdAt,
      if (expireAfterSec != null) 'expire_after_sec': expireAfterSec,
      if (proposalPsbt != null) 'proposal_psbt': proposalPsbt,
      if (txId != null) 'tx_id': txId,
      if (isExpired != null) 'is_expired': isExpired,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayjoinSendersCompanion copyWith({
    Value<String>? uri,
    Value<bool>? isTestnet,
    Value<String>? sender,
    Value<String>? walletId,
    Value<String>? originalPsbt,
    Value<String>? originalTxId,
    Value<int>? amountSat,
    Value<int>? createdAt,
    Value<int>? expireAfterSec,
    Value<String?>? proposalPsbt,
    Value<String?>? txId,
    Value<bool>? isExpired,
    Value<bool>? isCompleted,
    Value<int>? rowid,
  }) {
    return PayjoinSendersCompanion(
      uri: uri ?? this.uri,
      isTestnet: isTestnet ?? this.isTestnet,
      sender: sender ?? this.sender,
      walletId: walletId ?? this.walletId,
      originalPsbt: originalPsbt ?? this.originalPsbt,
      originalTxId: originalTxId ?? this.originalTxId,
      amountSat: amountSat ?? this.amountSat,
      createdAt: createdAt ?? this.createdAt,
      expireAfterSec: expireAfterSec ?? this.expireAfterSec,
      proposalPsbt: proposalPsbt ?? this.proposalPsbt,
      txId: txId ?? this.txId,
      isExpired: isExpired ?? this.isExpired,
      isCompleted: isCompleted ?? this.isCompleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (isTestnet.present) {
      map['is_testnet'] = Variable<bool>(isTestnet.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (originalPsbt.present) {
      map['original_psbt'] = Variable<String>(originalPsbt.value);
    }
    if (originalTxId.present) {
      map['original_tx_id'] = Variable<String>(originalTxId.value);
    }
    if (amountSat.present) {
      map['amount_sat'] = Variable<int>(amountSat.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (expireAfterSec.present) {
      map['expire_after_sec'] = Variable<int>(expireAfterSec.value);
    }
    if (proposalPsbt.present) {
      map['proposal_psbt'] = Variable<String>(proposalPsbt.value);
    }
    if (txId.present) {
      map['tx_id'] = Variable<String>(txId.value);
    }
    if (isExpired.present) {
      map['is_expired'] = Variable<bool>(isExpired.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayjoinSendersCompanion(')
          ..write('uri: $uri, ')
          ..write('isTestnet: $isTestnet, ')
          ..write('sender: $sender, ')
          ..write('walletId: $walletId, ')
          ..write('originalPsbt: $originalPsbt, ')
          ..write('originalTxId: $originalTxId, ')
          ..write('amountSat: $amountSat, ')
          ..write('createdAt: $createdAt, ')
          ..write('expireAfterSec: $expireAfterSec, ')
          ..write('proposalPsbt: $proposalPsbt, ')
          ..write('txId: $txId, ')
          ..write('isExpired: $isExpired, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PayjoinReceivers extends Table
    with TableInfo<PayjoinReceivers, PayjoinReceiversData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PayjoinReceivers(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> isTestnet = GeneratedColumn<bool>(
    'is_testnet',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_testnet" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<String> receiver = GeneratedColumn<String>(
    'receiver',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
    'wallet_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> pjUri = GeneratedColumn<String>(
    'pj_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<BigInt> maxFeeRateSatPerVb =
      GeneratedColumn<BigInt>(
        'max_fee_rate_sat_per_vb',
        aliasedName,
        false,
        type: DriftSqlType.bigInt,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> expireAfterSec = GeneratedColumn<int>(
    'expire_after_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<i2.Uint8List> originalTxBytes =
      GeneratedColumn<i2.Uint8List>(
        'original_tx_bytes',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<String> originalTxId = GeneratedColumn<String>(
    'original_tx_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> amountSat = GeneratedColumn<int>(
    'amount_sat',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> proposalPsbt = GeneratedColumn<String>(
    'proposal_psbt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> txId = GeneratedColumn<String>(
    'tx_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<bool> isExpired = GeneratedColumn<bool>(
    'is_expired',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_expired" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    address,
    isTestnet,
    receiver,
    walletId,
    pjUri,
    maxFeeRateSatPerVb,
    createdAt,
    expireAfterSec,
    originalTxBytes,
    originalTxId,
    amountSat,
    proposalPsbt,
    txId,
    isExpired,
    isCompleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payjoin_receivers';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PayjoinReceiversData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayjoinReceiversData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      address:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}address'],
          )!,
      isTestnet:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_testnet'],
          )!,
      receiver:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}receiver'],
          )!,
      walletId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}wallet_id'],
          )!,
      pjUri:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}pj_uri'],
          )!,
      maxFeeRateSatPerVb:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bigInt,
            data['${effectivePrefix}max_fee_rate_sat_per_vb'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}created_at'],
          )!,
      expireAfterSec:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}expire_after_sec'],
          )!,
      originalTxBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}original_tx_bytes'],
      ),
      originalTxId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_tx_id'],
      ),
      amountSat: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_sat'],
      ),
      proposalPsbt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proposal_psbt'],
      ),
      txId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tx_id'],
      ),
      isExpired:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_expired'],
          )!,
      isCompleted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_completed'],
          )!,
    );
  }

  @override
  PayjoinReceivers createAlias(String alias) {
    return PayjoinReceivers(attachedDatabase, alias);
  }
}

class PayjoinReceiversData extends DataClass
    implements Insertable<PayjoinReceiversData> {
  final String id;
  final String address;
  final bool isTestnet;
  final String receiver;
  final String walletId;
  final String pjUri;
  final BigInt maxFeeRateSatPerVb;
  final int createdAt;
  final int expireAfterSec;
  final i2.Uint8List? originalTxBytes;
  final String? originalTxId;
  final int? amountSat;
  final String? proposalPsbt;
  final String? txId;
  final bool isExpired;
  final bool isCompleted;
  const PayjoinReceiversData({
    required this.id,
    required this.address,
    required this.isTestnet,
    required this.receiver,
    required this.walletId,
    required this.pjUri,
    required this.maxFeeRateSatPerVb,
    required this.createdAt,
    required this.expireAfterSec,
    this.originalTxBytes,
    this.originalTxId,
    this.amountSat,
    this.proposalPsbt,
    this.txId,
    required this.isExpired,
    required this.isCompleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['address'] = Variable<String>(address);
    map['is_testnet'] = Variable<bool>(isTestnet);
    map['receiver'] = Variable<String>(receiver);
    map['wallet_id'] = Variable<String>(walletId);
    map['pj_uri'] = Variable<String>(pjUri);
    map['max_fee_rate_sat_per_vb'] = Variable<BigInt>(maxFeeRateSatPerVb);
    map['created_at'] = Variable<int>(createdAt);
    map['expire_after_sec'] = Variable<int>(expireAfterSec);
    if (!nullToAbsent || originalTxBytes != null) {
      map['original_tx_bytes'] = Variable<i2.Uint8List>(originalTxBytes);
    }
    if (!nullToAbsent || originalTxId != null) {
      map['original_tx_id'] = Variable<String>(originalTxId);
    }
    if (!nullToAbsent || amountSat != null) {
      map['amount_sat'] = Variable<int>(amountSat);
    }
    if (!nullToAbsent || proposalPsbt != null) {
      map['proposal_psbt'] = Variable<String>(proposalPsbt);
    }
    if (!nullToAbsent || txId != null) {
      map['tx_id'] = Variable<String>(txId);
    }
    map['is_expired'] = Variable<bool>(isExpired);
    map['is_completed'] = Variable<bool>(isCompleted);
    return map;
  }

  PayjoinReceiversCompanion toCompanion(bool nullToAbsent) {
    return PayjoinReceiversCompanion(
      id: Value(id),
      address: Value(address),
      isTestnet: Value(isTestnet),
      receiver: Value(receiver),
      walletId: Value(walletId),
      pjUri: Value(pjUri),
      maxFeeRateSatPerVb: Value(maxFeeRateSatPerVb),
      createdAt: Value(createdAt),
      expireAfterSec: Value(expireAfterSec),
      originalTxBytes:
          originalTxBytes == null && nullToAbsent
              ? const Value.absent()
              : Value(originalTxBytes),
      originalTxId:
          originalTxId == null && nullToAbsent
              ? const Value.absent()
              : Value(originalTxId),
      amountSat:
          amountSat == null && nullToAbsent
              ? const Value.absent()
              : Value(amountSat),
      proposalPsbt:
          proposalPsbt == null && nullToAbsent
              ? const Value.absent()
              : Value(proposalPsbt),
      txId: txId == null && nullToAbsent ? const Value.absent() : Value(txId),
      isExpired: Value(isExpired),
      isCompleted: Value(isCompleted),
    );
  }

  factory PayjoinReceiversData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayjoinReceiversData(
      id: serializer.fromJson<String>(json['id']),
      address: serializer.fromJson<String>(json['address']),
      isTestnet: serializer.fromJson<bool>(json['isTestnet']),
      receiver: serializer.fromJson<String>(json['receiver']),
      walletId: serializer.fromJson<String>(json['walletId']),
      pjUri: serializer.fromJson<String>(json['pjUri']),
      maxFeeRateSatPerVb: serializer.fromJson<BigInt>(
        json['maxFeeRateSatPerVb'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      expireAfterSec: serializer.fromJson<int>(json['expireAfterSec']),
      originalTxBytes: serializer.fromJson<i2.Uint8List?>(
        json['originalTxBytes'],
      ),
      originalTxId: serializer.fromJson<String?>(json['originalTxId']),
      amountSat: serializer.fromJson<int?>(json['amountSat']),
      proposalPsbt: serializer.fromJson<String?>(json['proposalPsbt']),
      txId: serializer.fromJson<String?>(json['txId']),
      isExpired: serializer.fromJson<bool>(json['isExpired']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'address': serializer.toJson<String>(address),
      'isTestnet': serializer.toJson<bool>(isTestnet),
      'receiver': serializer.toJson<String>(receiver),
      'walletId': serializer.toJson<String>(walletId),
      'pjUri': serializer.toJson<String>(pjUri),
      'maxFeeRateSatPerVb': serializer.toJson<BigInt>(maxFeeRateSatPerVb),
      'createdAt': serializer.toJson<int>(createdAt),
      'expireAfterSec': serializer.toJson<int>(expireAfterSec),
      'originalTxBytes': serializer.toJson<i2.Uint8List?>(originalTxBytes),
      'originalTxId': serializer.toJson<String?>(originalTxId),
      'amountSat': serializer.toJson<int?>(amountSat),
      'proposalPsbt': serializer.toJson<String?>(proposalPsbt),
      'txId': serializer.toJson<String?>(txId),
      'isExpired': serializer.toJson<bool>(isExpired),
      'isCompleted': serializer.toJson<bool>(isCompleted),
    };
  }

  PayjoinReceiversData copyWith({
    String? id,
    String? address,
    bool? isTestnet,
    String? receiver,
    String? walletId,
    String? pjUri,
    BigInt? maxFeeRateSatPerVb,
    int? createdAt,
    int? expireAfterSec,
    Value<i2.Uint8List?> originalTxBytes = const Value.absent(),
    Value<String?> originalTxId = const Value.absent(),
    Value<int?> amountSat = const Value.absent(),
    Value<String?> proposalPsbt = const Value.absent(),
    Value<String?> txId = const Value.absent(),
    bool? isExpired,
    bool? isCompleted,
  }) => PayjoinReceiversData(
    id: id ?? this.id,
    address: address ?? this.address,
    isTestnet: isTestnet ?? this.isTestnet,
    receiver: receiver ?? this.receiver,
    walletId: walletId ?? this.walletId,
    pjUri: pjUri ?? this.pjUri,
    maxFeeRateSatPerVb: maxFeeRateSatPerVb ?? this.maxFeeRateSatPerVb,
    createdAt: createdAt ?? this.createdAt,
    expireAfterSec: expireAfterSec ?? this.expireAfterSec,
    originalTxBytes:
        originalTxBytes.present ? originalTxBytes.value : this.originalTxBytes,
    originalTxId: originalTxId.present ? originalTxId.value : this.originalTxId,
    amountSat: amountSat.present ? amountSat.value : this.amountSat,
    proposalPsbt: proposalPsbt.present ? proposalPsbt.value : this.proposalPsbt,
    txId: txId.present ? txId.value : this.txId,
    isExpired: isExpired ?? this.isExpired,
    isCompleted: isCompleted ?? this.isCompleted,
  );
  PayjoinReceiversData copyWithCompanion(PayjoinReceiversCompanion data) {
    return PayjoinReceiversData(
      id: data.id.present ? data.id.value : this.id,
      address: data.address.present ? data.address.value : this.address,
      isTestnet: data.isTestnet.present ? data.isTestnet.value : this.isTestnet,
      receiver: data.receiver.present ? data.receiver.value : this.receiver,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      pjUri: data.pjUri.present ? data.pjUri.value : this.pjUri,
      maxFeeRateSatPerVb:
          data.maxFeeRateSatPerVb.present
              ? data.maxFeeRateSatPerVb.value
              : this.maxFeeRateSatPerVb,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expireAfterSec:
          data.expireAfterSec.present
              ? data.expireAfterSec.value
              : this.expireAfterSec,
      originalTxBytes:
          data.originalTxBytes.present
              ? data.originalTxBytes.value
              : this.originalTxBytes,
      originalTxId:
          data.originalTxId.present
              ? data.originalTxId.value
              : this.originalTxId,
      amountSat: data.amountSat.present ? data.amountSat.value : this.amountSat,
      proposalPsbt:
          data.proposalPsbt.present
              ? data.proposalPsbt.value
              : this.proposalPsbt,
      txId: data.txId.present ? data.txId.value : this.txId,
      isExpired: data.isExpired.present ? data.isExpired.value : this.isExpired,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayjoinReceiversData(')
          ..write('id: $id, ')
          ..write('address: $address, ')
          ..write('isTestnet: $isTestnet, ')
          ..write('receiver: $receiver, ')
          ..write('walletId: $walletId, ')
          ..write('pjUri: $pjUri, ')
          ..write('maxFeeRateSatPerVb: $maxFeeRateSatPerVb, ')
          ..write('createdAt: $createdAt, ')
          ..write('expireAfterSec: $expireAfterSec, ')
          ..write('originalTxBytes: $originalTxBytes, ')
          ..write('originalTxId: $originalTxId, ')
          ..write('amountSat: $amountSat, ')
          ..write('proposalPsbt: $proposalPsbt, ')
          ..write('txId: $txId, ')
          ..write('isExpired: $isExpired, ')
          ..write('isCompleted: $isCompleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    address,
    isTestnet,
    receiver,
    walletId,
    pjUri,
    maxFeeRateSatPerVb,
    createdAt,
    expireAfterSec,
    $driftBlobEquality.hash(originalTxBytes),
    originalTxId,
    amountSat,
    proposalPsbt,
    txId,
    isExpired,
    isCompleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayjoinReceiversData &&
          other.id == this.id &&
          other.address == this.address &&
          other.isTestnet == this.isTestnet &&
          other.receiver == this.receiver &&
          other.walletId == this.walletId &&
          other.pjUri == this.pjUri &&
          other.maxFeeRateSatPerVb == this.maxFeeRateSatPerVb &&
          other.createdAt == this.createdAt &&
          other.expireAfterSec == this.expireAfterSec &&
          $driftBlobEquality.equals(
            other.originalTxBytes,
            this.originalTxBytes,
          ) &&
          other.originalTxId == this.originalTxId &&
          other.amountSat == this.amountSat &&
          other.proposalPsbt == this.proposalPsbt &&
          other.txId == this.txId &&
          other.isExpired == this.isExpired &&
          other.isCompleted == this.isCompleted);
}

class PayjoinReceiversCompanion extends UpdateCompanion<PayjoinReceiversData> {
  final Value<String> id;
  final Value<String> address;
  final Value<bool> isTestnet;
  final Value<String> receiver;
  final Value<String> walletId;
  final Value<String> pjUri;
  final Value<BigInt> maxFeeRateSatPerVb;
  final Value<int> createdAt;
  final Value<int> expireAfterSec;
  final Value<i2.Uint8List?> originalTxBytes;
  final Value<String?> originalTxId;
  final Value<int?> amountSat;
  final Value<String?> proposalPsbt;
  final Value<String?> txId;
  final Value<bool> isExpired;
  final Value<bool> isCompleted;
  final Value<int> rowid;
  const PayjoinReceiversCompanion({
    this.id = const Value.absent(),
    this.address = const Value.absent(),
    this.isTestnet = const Value.absent(),
    this.receiver = const Value.absent(),
    this.walletId = const Value.absent(),
    this.pjUri = const Value.absent(),
    this.maxFeeRateSatPerVb = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expireAfterSec = const Value.absent(),
    this.originalTxBytes = const Value.absent(),
    this.originalTxId = const Value.absent(),
    this.amountSat = const Value.absent(),
    this.proposalPsbt = const Value.absent(),
    this.txId = const Value.absent(),
    this.isExpired = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayjoinReceiversCompanion.insert({
    required String id,
    required String address,
    required bool isTestnet,
    required String receiver,
    required String walletId,
    required String pjUri,
    required BigInt maxFeeRateSatPerVb,
    required int createdAt,
    required int expireAfterSec,
    this.originalTxBytes = const Value.absent(),
    this.originalTxId = const Value.absent(),
    this.amountSat = const Value.absent(),
    this.proposalPsbt = const Value.absent(),
    this.txId = const Value.absent(),
    required bool isExpired,
    required bool isCompleted,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       address = Value(address),
       isTestnet = Value(isTestnet),
       receiver = Value(receiver),
       walletId = Value(walletId),
       pjUri = Value(pjUri),
       maxFeeRateSatPerVb = Value(maxFeeRateSatPerVb),
       createdAt = Value(createdAt),
       expireAfterSec = Value(expireAfterSec),
       isExpired = Value(isExpired),
       isCompleted = Value(isCompleted);
  static Insertable<PayjoinReceiversData> custom({
    Expression<String>? id,
    Expression<String>? address,
    Expression<bool>? isTestnet,
    Expression<String>? receiver,
    Expression<String>? walletId,
    Expression<String>? pjUri,
    Expression<BigInt>? maxFeeRateSatPerVb,
    Expression<int>? createdAt,
    Expression<int>? expireAfterSec,
    Expression<i2.Uint8List>? originalTxBytes,
    Expression<String>? originalTxId,
    Expression<int>? amountSat,
    Expression<String>? proposalPsbt,
    Expression<String>? txId,
    Expression<bool>? isExpired,
    Expression<bool>? isCompleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (address != null) 'address': address,
      if (isTestnet != null) 'is_testnet': isTestnet,
      if (receiver != null) 'receiver': receiver,
      if (walletId != null) 'wallet_id': walletId,
      if (pjUri != null) 'pj_uri': pjUri,
      if (maxFeeRateSatPerVb != null)
        'max_fee_rate_sat_per_vb': maxFeeRateSatPerVb,
      if (createdAt != null) 'created_at': createdAt,
      if (expireAfterSec != null) 'expire_after_sec': expireAfterSec,
      if (originalTxBytes != null) 'original_tx_bytes': originalTxBytes,
      if (originalTxId != null) 'original_tx_id': originalTxId,
      if (amountSat != null) 'amount_sat': amountSat,
      if (proposalPsbt != null) 'proposal_psbt': proposalPsbt,
      if (txId != null) 'tx_id': txId,
      if (isExpired != null) 'is_expired': isExpired,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayjoinReceiversCompanion copyWith({
    Value<String>? id,
    Value<String>? address,
    Value<bool>? isTestnet,
    Value<String>? receiver,
    Value<String>? walletId,
    Value<String>? pjUri,
    Value<BigInt>? maxFeeRateSatPerVb,
    Value<int>? createdAt,
    Value<int>? expireAfterSec,
    Value<i2.Uint8List?>? originalTxBytes,
    Value<String?>? originalTxId,
    Value<int?>? amountSat,
    Value<String?>? proposalPsbt,
    Value<String?>? txId,
    Value<bool>? isExpired,
    Value<bool>? isCompleted,
    Value<int>? rowid,
  }) {
    return PayjoinReceiversCompanion(
      id: id ?? this.id,
      address: address ?? this.address,
      isTestnet: isTestnet ?? this.isTestnet,
      receiver: receiver ?? this.receiver,
      walletId: walletId ?? this.walletId,
      pjUri: pjUri ?? this.pjUri,
      maxFeeRateSatPerVb: maxFeeRateSatPerVb ?? this.maxFeeRateSatPerVb,
      createdAt: createdAt ?? this.createdAt,
      expireAfterSec: expireAfterSec ?? this.expireAfterSec,
      originalTxBytes: originalTxBytes ?? this.originalTxBytes,
      originalTxId: originalTxId ?? this.originalTxId,
      amountSat: amountSat ?? this.amountSat,
      proposalPsbt: proposalPsbt ?? this.proposalPsbt,
      txId: txId ?? this.txId,
      isExpired: isExpired ?? this.isExpired,
      isCompleted: isCompleted ?? this.isCompleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (isTestnet.present) {
      map['is_testnet'] = Variable<bool>(isTestnet.value);
    }
    if (receiver.present) {
      map['receiver'] = Variable<String>(receiver.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (pjUri.present) {
      map['pj_uri'] = Variable<String>(pjUri.value);
    }
    if (maxFeeRateSatPerVb.present) {
      map['max_fee_rate_sat_per_vb'] = Variable<BigInt>(
        maxFeeRateSatPerVb.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (expireAfterSec.present) {
      map['expire_after_sec'] = Variable<int>(expireAfterSec.value);
    }
    if (originalTxBytes.present) {
      map['original_tx_bytes'] = Variable<i2.Uint8List>(originalTxBytes.value);
    }
    if (originalTxId.present) {
      map['original_tx_id'] = Variable<String>(originalTxId.value);
    }
    if (amountSat.present) {
      map['amount_sat'] = Variable<int>(amountSat.value);
    }
    if (proposalPsbt.present) {
      map['proposal_psbt'] = Variable<String>(proposalPsbt.value);
    }
    if (txId.present) {
      map['tx_id'] = Variable<String>(txId.value);
    }
    if (isExpired.present) {
      map['is_expired'] = Variable<bool>(isExpired.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayjoinReceiversCompanion(')
          ..write('id: $id, ')
          ..write('address: $address, ')
          ..write('isTestnet: $isTestnet, ')
          ..write('receiver: $receiver, ')
          ..write('walletId: $walletId, ')
          ..write('pjUri: $pjUri, ')
          ..write('maxFeeRateSatPerVb: $maxFeeRateSatPerVb, ')
          ..write('createdAt: $createdAt, ')
          ..write('expireAfterSec: $expireAfterSec, ')
          ..write('originalTxBytes: $originalTxBytes, ')
          ..write('originalTxId: $originalTxId, ')
          ..write('amountSat: $amountSat, ')
          ..write('proposalPsbt: $proposalPsbt, ')
          ..write('txId: $txId, ')
          ..write('isExpired: $isExpired, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ElectrumServers extends Table
    with TableInfo<ElectrumServers, ElectrumServersData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ElectrumServers(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> socks5 = GeneratedColumn<String>(
    'socks5',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> stopGap = GeneratedColumn<int>(
    'stop_gap',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> timeout = GeneratedColumn<int>(
    'timeout',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> retry = GeneratedColumn<int>(
    'retry',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> validateDomain = GeneratedColumn<bool>(
    'validate_domain',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("validate_domain" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<bool> isTestnet = GeneratedColumn<bool>(
    'is_testnet',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_testnet" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<bool> isLiquid = GeneratedColumn<bool>(
    'is_liquid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_liquid" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    url,
    socks5,
    stopGap,
    timeout,
    retry,
    validateDomain,
    isTestnet,
    isLiquid,
    isActive,
    priority,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'electrum_servers';
  @override
  Set<GeneratedColumn> get $primaryKey => {url};
  @override
  ElectrumServersData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ElectrumServersData(
      url:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}url'],
          )!,
      socks5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}socks5'],
      ),
      stopGap:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}stop_gap'],
          )!,
      timeout:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}timeout'],
          )!,
      retry:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}retry'],
          )!,
      validateDomain:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}validate_domain'],
          )!,
      isTestnet:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_testnet'],
          )!,
      isLiquid:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_liquid'],
          )!,
      isActive:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_active'],
          )!,
      priority:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}priority'],
          )!,
    );
  }

  @override
  ElectrumServers createAlias(String alias) {
    return ElectrumServers(attachedDatabase, alias);
  }
}

class ElectrumServersData extends DataClass
    implements Insertable<ElectrumServersData> {
  final String url;
  final String? socks5;
  final int stopGap;
  final int timeout;
  final int retry;
  final bool validateDomain;
  final bool isTestnet;
  final bool isLiquid;
  final bool isActive;
  final int priority;
  const ElectrumServersData({
    required this.url,
    this.socks5,
    required this.stopGap,
    required this.timeout,
    required this.retry,
    required this.validateDomain,
    required this.isTestnet,
    required this.isLiquid,
    required this.isActive,
    required this.priority,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || socks5 != null) {
      map['socks5'] = Variable<String>(socks5);
    }
    map['stop_gap'] = Variable<int>(stopGap);
    map['timeout'] = Variable<int>(timeout);
    map['retry'] = Variable<int>(retry);
    map['validate_domain'] = Variable<bool>(validateDomain);
    map['is_testnet'] = Variable<bool>(isTestnet);
    map['is_liquid'] = Variable<bool>(isLiquid);
    map['is_active'] = Variable<bool>(isActive);
    map['priority'] = Variable<int>(priority);
    return map;
  }

  ElectrumServersCompanion toCompanion(bool nullToAbsent) {
    return ElectrumServersCompanion(
      url: Value(url),
      socks5:
          socks5 == null && nullToAbsent ? const Value.absent() : Value(socks5),
      stopGap: Value(stopGap),
      timeout: Value(timeout),
      retry: Value(retry),
      validateDomain: Value(validateDomain),
      isTestnet: Value(isTestnet),
      isLiquid: Value(isLiquid),
      isActive: Value(isActive),
      priority: Value(priority),
    );
  }

  factory ElectrumServersData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ElectrumServersData(
      url: serializer.fromJson<String>(json['url']),
      socks5: serializer.fromJson<String?>(json['socks5']),
      stopGap: serializer.fromJson<int>(json['stopGap']),
      timeout: serializer.fromJson<int>(json['timeout']),
      retry: serializer.fromJson<int>(json['retry']),
      validateDomain: serializer.fromJson<bool>(json['validateDomain']),
      isTestnet: serializer.fromJson<bool>(json['isTestnet']),
      isLiquid: serializer.fromJson<bool>(json['isLiquid']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      priority: serializer.fromJson<int>(json['priority']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'url': serializer.toJson<String>(url),
      'socks5': serializer.toJson<String?>(socks5),
      'stopGap': serializer.toJson<int>(stopGap),
      'timeout': serializer.toJson<int>(timeout),
      'retry': serializer.toJson<int>(retry),
      'validateDomain': serializer.toJson<bool>(validateDomain),
      'isTestnet': serializer.toJson<bool>(isTestnet),
      'isLiquid': serializer.toJson<bool>(isLiquid),
      'isActive': serializer.toJson<bool>(isActive),
      'priority': serializer.toJson<int>(priority),
    };
  }

  ElectrumServersData copyWith({
    String? url,
    Value<String?> socks5 = const Value.absent(),
    int? stopGap,
    int? timeout,
    int? retry,
    bool? validateDomain,
    bool? isTestnet,
    bool? isLiquid,
    bool? isActive,
    int? priority,
  }) => ElectrumServersData(
    url: url ?? this.url,
    socks5: socks5.present ? socks5.value : this.socks5,
    stopGap: stopGap ?? this.stopGap,
    timeout: timeout ?? this.timeout,
    retry: retry ?? this.retry,
    validateDomain: validateDomain ?? this.validateDomain,
    isTestnet: isTestnet ?? this.isTestnet,
    isLiquid: isLiquid ?? this.isLiquid,
    isActive: isActive ?? this.isActive,
    priority: priority ?? this.priority,
  );
  ElectrumServersData copyWithCompanion(ElectrumServersCompanion data) {
    return ElectrumServersData(
      url: data.url.present ? data.url.value : this.url,
      socks5: data.socks5.present ? data.socks5.value : this.socks5,
      stopGap: data.stopGap.present ? data.stopGap.value : this.stopGap,
      timeout: data.timeout.present ? data.timeout.value : this.timeout,
      retry: data.retry.present ? data.retry.value : this.retry,
      validateDomain:
          data.validateDomain.present
              ? data.validateDomain.value
              : this.validateDomain,
      isTestnet: data.isTestnet.present ? data.isTestnet.value : this.isTestnet,
      isLiquid: data.isLiquid.present ? data.isLiquid.value : this.isLiquid,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      priority: data.priority.present ? data.priority.value : this.priority,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ElectrumServersData(')
          ..write('url: $url, ')
          ..write('socks5: $socks5, ')
          ..write('stopGap: $stopGap, ')
          ..write('timeout: $timeout, ')
          ..write('retry: $retry, ')
          ..write('validateDomain: $validateDomain, ')
          ..write('isTestnet: $isTestnet, ')
          ..write('isLiquid: $isLiquid, ')
          ..write('isActive: $isActive, ')
          ..write('priority: $priority')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    url,
    socks5,
    stopGap,
    timeout,
    retry,
    validateDomain,
    isTestnet,
    isLiquid,
    isActive,
    priority,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ElectrumServersData &&
          other.url == this.url &&
          other.socks5 == this.socks5 &&
          other.stopGap == this.stopGap &&
          other.timeout == this.timeout &&
          other.retry == this.retry &&
          other.validateDomain == this.validateDomain &&
          other.isTestnet == this.isTestnet &&
          other.isLiquid == this.isLiquid &&
          other.isActive == this.isActive &&
          other.priority == this.priority);
}

class ElectrumServersCompanion extends UpdateCompanion<ElectrumServersData> {
  final Value<String> url;
  final Value<String?> socks5;
  final Value<int> stopGap;
  final Value<int> timeout;
  final Value<int> retry;
  final Value<bool> validateDomain;
  final Value<bool> isTestnet;
  final Value<bool> isLiquid;
  final Value<bool> isActive;
  final Value<int> priority;
  final Value<int> rowid;
  const ElectrumServersCompanion({
    this.url = const Value.absent(),
    this.socks5 = const Value.absent(),
    this.stopGap = const Value.absent(),
    this.timeout = const Value.absent(),
    this.retry = const Value.absent(),
    this.validateDomain = const Value.absent(),
    this.isTestnet = const Value.absent(),
    this.isLiquid = const Value.absent(),
    this.isActive = const Value.absent(),
    this.priority = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ElectrumServersCompanion.insert({
    required String url,
    this.socks5 = const Value.absent(),
    required int stopGap,
    required int timeout,
    required int retry,
    required bool validateDomain,
    required bool isTestnet,
    required bool isLiquid,
    required bool isActive,
    required int priority,
    this.rowid = const Value.absent(),
  }) : url = Value(url),
       stopGap = Value(stopGap),
       timeout = Value(timeout),
       retry = Value(retry),
       validateDomain = Value(validateDomain),
       isTestnet = Value(isTestnet),
       isLiquid = Value(isLiquid),
       isActive = Value(isActive),
       priority = Value(priority);
  static Insertable<ElectrumServersData> custom({
    Expression<String>? url,
    Expression<String>? socks5,
    Expression<int>? stopGap,
    Expression<int>? timeout,
    Expression<int>? retry,
    Expression<bool>? validateDomain,
    Expression<bool>? isTestnet,
    Expression<bool>? isLiquid,
    Expression<bool>? isActive,
    Expression<int>? priority,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (url != null) 'url': url,
      if (socks5 != null) 'socks5': socks5,
      if (stopGap != null) 'stop_gap': stopGap,
      if (timeout != null) 'timeout': timeout,
      if (retry != null) 'retry': retry,
      if (validateDomain != null) 'validate_domain': validateDomain,
      if (isTestnet != null) 'is_testnet': isTestnet,
      if (isLiquid != null) 'is_liquid': isLiquid,
      if (isActive != null) 'is_active': isActive,
      if (priority != null) 'priority': priority,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ElectrumServersCompanion copyWith({
    Value<String>? url,
    Value<String?>? socks5,
    Value<int>? stopGap,
    Value<int>? timeout,
    Value<int>? retry,
    Value<bool>? validateDomain,
    Value<bool>? isTestnet,
    Value<bool>? isLiquid,
    Value<bool>? isActive,
    Value<int>? priority,
    Value<int>? rowid,
  }) {
    return ElectrumServersCompanion(
      url: url ?? this.url,
      socks5: socks5 ?? this.socks5,
      stopGap: stopGap ?? this.stopGap,
      timeout: timeout ?? this.timeout,
      retry: retry ?? this.retry,
      validateDomain: validateDomain ?? this.validateDomain,
      isTestnet: isTestnet ?? this.isTestnet,
      isLiquid: isLiquid ?? this.isLiquid,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (socks5.present) {
      map['socks5'] = Variable<String>(socks5.value);
    }
    if (stopGap.present) {
      map['stop_gap'] = Variable<int>(stopGap.value);
    }
    if (timeout.present) {
      map['timeout'] = Variable<int>(timeout.value);
    }
    if (retry.present) {
      map['retry'] = Variable<int>(retry.value);
    }
    if (validateDomain.present) {
      map['validate_domain'] = Variable<bool>(validateDomain.value);
    }
    if (isTestnet.present) {
      map['is_testnet'] = Variable<bool>(isTestnet.value);
    }
    if (isLiquid.present) {
      map['is_liquid'] = Variable<bool>(isLiquid.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ElectrumServersCompanion(')
          ..write('url: $url, ')
          ..write('socks5: $socks5, ')
          ..write('stopGap: $stopGap, ')
          ..write('timeout: $timeout, ')
          ..write('retry: $retry, ')
          ..write('validateDomain: $validateDomain, ')
          ..write('isTestnet: $isTestnet, ')
          ..write('isLiquid: $isLiquid, ')
          ..write('isActive: $isActive, ')
          ..write('priority: $priority, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Swaps extends Table with TableInfo<Swaps, SwapsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Swaps(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 12,
      maxTextLength: 12,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> isTestnet = GeneratedColumn<bool>(
    'is_testnet',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_testnet" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<int> keyIndex = GeneratedColumn<int>(
    'key_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> creationTime = GeneratedColumn<int>(
    'creation_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> completionTime = GeneratedColumn<int>(
    'completion_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> receiveWalletId = GeneratedColumn<String>(
    'receive_wallet_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> sendWalletId = GeneratedColumn<String>(
    'send_wallet_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> invoice = GeneratedColumn<String>(
    'invoice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> paymentAddress = GeneratedColumn<String>(
    'payment_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> paymentAmount = GeneratedColumn<int>(
    'payment_amount',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> receiveAddress = GeneratedColumn<String>(
    'receive_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> receiveTxid = GeneratedColumn<String>(
    'receive_txid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> sendTxid = GeneratedColumn<String>(
    'send_txid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> preimage = GeneratedColumn<String>(
    'preimage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> refundAddress = GeneratedColumn<String>(
    'refund_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> refundTxid = GeneratedColumn<String>(
    'refund_txid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> boltzFees = GeneratedColumn<int>(
    'boltz_fees',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> lockupFees = GeneratedColumn<int>(
    'lockup_fees',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> claimFees = GeneratedColumn<int>(
    'claim_fees',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    direction,
    status,
    isTestnet,
    keyIndex,
    creationTime,
    completionTime,
    receiveWalletId,
    sendWalletId,
    invoice,
    paymentAddress,
    paymentAmount,
    receiveAddress,
    receiveTxid,
    sendTxid,
    preimage,
    refundAddress,
    refundTxid,
    boltzFees,
    lockupFees,
    claimFees,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'swaps';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SwapsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SwapsData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      type:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}type'],
          )!,
      direction:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}direction'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      isTestnet:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_testnet'],
          )!,
      keyIndex:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}key_index'],
          )!,
      creationTime:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}creation_time'],
          )!,
      completionTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completion_time'],
      ),
      receiveWalletId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receive_wallet_id'],
      ),
      sendWalletId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}send_wallet_id'],
      ),
      invoice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice'],
      ),
      paymentAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_address'],
      ),
      paymentAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payment_amount'],
      ),
      receiveAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receive_address'],
      ),
      receiveTxid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receive_txid'],
      ),
      sendTxid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}send_txid'],
      ),
      preimage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preimage'],
      ),
      refundAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refund_address'],
      ),
      refundTxid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refund_txid'],
      ),
      boltzFees: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}boltz_fees'],
      ),
      lockupFees: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lockup_fees'],
      ),
      claimFees: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}claim_fees'],
      ),
    );
  }

  @override
  Swaps createAlias(String alias) {
    return Swaps(attachedDatabase, alias);
  }
}

class SwapsData extends DataClass implements Insertable<SwapsData> {
  final String id;
  final String type;
  final String direction;
  final String status;
  final bool isTestnet;
  final int keyIndex;
  final int creationTime;
  final int? completionTime;
  final String? receiveWalletId;
  final String? sendWalletId;
  final String? invoice;
  final String? paymentAddress;
  final int? paymentAmount;
  final String? receiveAddress;
  final String? receiveTxid;
  final String? sendTxid;
  final String? preimage;
  final String? refundAddress;
  final String? refundTxid;
  final int? boltzFees;
  final int? lockupFees;
  final int? claimFees;
  const SwapsData({
    required this.id,
    required this.type,
    required this.direction,
    required this.status,
    required this.isTestnet,
    required this.keyIndex,
    required this.creationTime,
    this.completionTime,
    this.receiveWalletId,
    this.sendWalletId,
    this.invoice,
    this.paymentAddress,
    this.paymentAmount,
    this.receiveAddress,
    this.receiveTxid,
    this.sendTxid,
    this.preimage,
    this.refundAddress,
    this.refundTxid,
    this.boltzFees,
    this.lockupFees,
    this.claimFees,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['direction'] = Variable<String>(direction);
    map['status'] = Variable<String>(status);
    map['is_testnet'] = Variable<bool>(isTestnet);
    map['key_index'] = Variable<int>(keyIndex);
    map['creation_time'] = Variable<int>(creationTime);
    if (!nullToAbsent || completionTime != null) {
      map['completion_time'] = Variable<int>(completionTime);
    }
    if (!nullToAbsent || receiveWalletId != null) {
      map['receive_wallet_id'] = Variable<String>(receiveWalletId);
    }
    if (!nullToAbsent || sendWalletId != null) {
      map['send_wallet_id'] = Variable<String>(sendWalletId);
    }
    if (!nullToAbsent || invoice != null) {
      map['invoice'] = Variable<String>(invoice);
    }
    if (!nullToAbsent || paymentAddress != null) {
      map['payment_address'] = Variable<String>(paymentAddress);
    }
    if (!nullToAbsent || paymentAmount != null) {
      map['payment_amount'] = Variable<int>(paymentAmount);
    }
    if (!nullToAbsent || receiveAddress != null) {
      map['receive_address'] = Variable<String>(receiveAddress);
    }
    if (!nullToAbsent || receiveTxid != null) {
      map['receive_txid'] = Variable<String>(receiveTxid);
    }
    if (!nullToAbsent || sendTxid != null) {
      map['send_txid'] = Variable<String>(sendTxid);
    }
    if (!nullToAbsent || preimage != null) {
      map['preimage'] = Variable<String>(preimage);
    }
    if (!nullToAbsent || refundAddress != null) {
      map['refund_address'] = Variable<String>(refundAddress);
    }
    if (!nullToAbsent || refundTxid != null) {
      map['refund_txid'] = Variable<String>(refundTxid);
    }
    if (!nullToAbsent || boltzFees != null) {
      map['boltz_fees'] = Variable<int>(boltzFees);
    }
    if (!nullToAbsent || lockupFees != null) {
      map['lockup_fees'] = Variable<int>(lockupFees);
    }
    if (!nullToAbsent || claimFees != null) {
      map['claim_fees'] = Variable<int>(claimFees);
    }
    return map;
  }

  SwapsCompanion toCompanion(bool nullToAbsent) {
    return SwapsCompanion(
      id: Value(id),
      type: Value(type),
      direction: Value(direction),
      status: Value(status),
      isTestnet: Value(isTestnet),
      keyIndex: Value(keyIndex),
      creationTime: Value(creationTime),
      completionTime:
          completionTime == null && nullToAbsent
              ? const Value.absent()
              : Value(completionTime),
      receiveWalletId:
          receiveWalletId == null && nullToAbsent
              ? const Value.absent()
              : Value(receiveWalletId),
      sendWalletId:
          sendWalletId == null && nullToAbsent
              ? const Value.absent()
              : Value(sendWalletId),
      invoice:
          invoice == null && nullToAbsent
              ? const Value.absent()
              : Value(invoice),
      paymentAddress:
          paymentAddress == null && nullToAbsent
              ? const Value.absent()
              : Value(paymentAddress),
      paymentAmount:
          paymentAmount == null && nullToAbsent
              ? const Value.absent()
              : Value(paymentAmount),
      receiveAddress:
          receiveAddress == null && nullToAbsent
              ? const Value.absent()
              : Value(receiveAddress),
      receiveTxid:
          receiveTxid == null && nullToAbsent
              ? const Value.absent()
              : Value(receiveTxid),
      sendTxid:
          sendTxid == null && nullToAbsent
              ? const Value.absent()
              : Value(sendTxid),
      preimage:
          preimage == null && nullToAbsent
              ? const Value.absent()
              : Value(preimage),
      refundAddress:
          refundAddress == null && nullToAbsent
              ? const Value.absent()
              : Value(refundAddress),
      refundTxid:
          refundTxid == null && nullToAbsent
              ? const Value.absent()
              : Value(refundTxid),
      boltzFees:
          boltzFees == null && nullToAbsent
              ? const Value.absent()
              : Value(boltzFees),
      lockupFees:
          lockupFees == null && nullToAbsent
              ? const Value.absent()
              : Value(lockupFees),
      claimFees:
          claimFees == null && nullToAbsent
              ? const Value.absent()
              : Value(claimFees),
    );
  }

  factory SwapsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SwapsData(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      direction: serializer.fromJson<String>(json['direction']),
      status: serializer.fromJson<String>(json['status']),
      isTestnet: serializer.fromJson<bool>(json['isTestnet']),
      keyIndex: serializer.fromJson<int>(json['keyIndex']),
      creationTime: serializer.fromJson<int>(json['creationTime']),
      completionTime: serializer.fromJson<int?>(json['completionTime']),
      receiveWalletId: serializer.fromJson<String?>(json['receiveWalletId']),
      sendWalletId: serializer.fromJson<String?>(json['sendWalletId']),
      invoice: serializer.fromJson<String?>(json['invoice']),
      paymentAddress: serializer.fromJson<String?>(json['paymentAddress']),
      paymentAmount: serializer.fromJson<int?>(json['paymentAmount']),
      receiveAddress: serializer.fromJson<String?>(json['receiveAddress']),
      receiveTxid: serializer.fromJson<String?>(json['receiveTxid']),
      sendTxid: serializer.fromJson<String?>(json['sendTxid']),
      preimage: serializer.fromJson<String?>(json['preimage']),
      refundAddress: serializer.fromJson<String?>(json['refundAddress']),
      refundTxid: serializer.fromJson<String?>(json['refundTxid']),
      boltzFees: serializer.fromJson<int?>(json['boltzFees']),
      lockupFees: serializer.fromJson<int?>(json['lockupFees']),
      claimFees: serializer.fromJson<int?>(json['claimFees']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'direction': serializer.toJson<String>(direction),
      'status': serializer.toJson<String>(status),
      'isTestnet': serializer.toJson<bool>(isTestnet),
      'keyIndex': serializer.toJson<int>(keyIndex),
      'creationTime': serializer.toJson<int>(creationTime),
      'completionTime': serializer.toJson<int?>(completionTime),
      'receiveWalletId': serializer.toJson<String?>(receiveWalletId),
      'sendWalletId': serializer.toJson<String?>(sendWalletId),
      'invoice': serializer.toJson<String?>(invoice),
      'paymentAddress': serializer.toJson<String?>(paymentAddress),
      'paymentAmount': serializer.toJson<int?>(paymentAmount),
      'receiveAddress': serializer.toJson<String?>(receiveAddress),
      'receiveTxid': serializer.toJson<String?>(receiveTxid),
      'sendTxid': serializer.toJson<String?>(sendTxid),
      'preimage': serializer.toJson<String?>(preimage),
      'refundAddress': serializer.toJson<String?>(refundAddress),
      'refundTxid': serializer.toJson<String?>(refundTxid),
      'boltzFees': serializer.toJson<int?>(boltzFees),
      'lockupFees': serializer.toJson<int?>(lockupFees),
      'claimFees': serializer.toJson<int?>(claimFees),
    };
  }

  SwapsData copyWith({
    String? id,
    String? type,
    String? direction,
    String? status,
    bool? isTestnet,
    int? keyIndex,
    int? creationTime,
    Value<int?> completionTime = const Value.absent(),
    Value<String?> receiveWalletId = const Value.absent(),
    Value<String?> sendWalletId = const Value.absent(),
    Value<String?> invoice = const Value.absent(),
    Value<String?> paymentAddress = const Value.absent(),
    Value<int?> paymentAmount = const Value.absent(),
    Value<String?> receiveAddress = const Value.absent(),
    Value<String?> receiveTxid = const Value.absent(),
    Value<String?> sendTxid = const Value.absent(),
    Value<String?> preimage = const Value.absent(),
    Value<String?> refundAddress = const Value.absent(),
    Value<String?> refundTxid = const Value.absent(),
    Value<int?> boltzFees = const Value.absent(),
    Value<int?> lockupFees = const Value.absent(),
    Value<int?> claimFees = const Value.absent(),
  }) => SwapsData(
    id: id ?? this.id,
    type: type ?? this.type,
    direction: direction ?? this.direction,
    status: status ?? this.status,
    isTestnet: isTestnet ?? this.isTestnet,
    keyIndex: keyIndex ?? this.keyIndex,
    creationTime: creationTime ?? this.creationTime,
    completionTime:
        completionTime.present ? completionTime.value : this.completionTime,
    receiveWalletId:
        receiveWalletId.present ? receiveWalletId.value : this.receiveWalletId,
    sendWalletId: sendWalletId.present ? sendWalletId.value : this.sendWalletId,
    invoice: invoice.present ? invoice.value : this.invoice,
    paymentAddress:
        paymentAddress.present ? paymentAddress.value : this.paymentAddress,
    paymentAmount:
        paymentAmount.present ? paymentAmount.value : this.paymentAmount,
    receiveAddress:
        receiveAddress.present ? receiveAddress.value : this.receiveAddress,
    receiveTxid: receiveTxid.present ? receiveTxid.value : this.receiveTxid,
    sendTxid: sendTxid.present ? sendTxid.value : this.sendTxid,
    preimage: preimage.present ? preimage.value : this.preimage,
    refundAddress:
        refundAddress.present ? refundAddress.value : this.refundAddress,
    refundTxid: refundTxid.present ? refundTxid.value : this.refundTxid,
    boltzFees: boltzFees.present ? boltzFees.value : this.boltzFees,
    lockupFees: lockupFees.present ? lockupFees.value : this.lockupFees,
    claimFees: claimFees.present ? claimFees.value : this.claimFees,
  );
  SwapsData copyWithCompanion(SwapsCompanion data) {
    return SwapsData(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      direction: data.direction.present ? data.direction.value : this.direction,
      status: data.status.present ? data.status.value : this.status,
      isTestnet: data.isTestnet.present ? data.isTestnet.value : this.isTestnet,
      keyIndex: data.keyIndex.present ? data.keyIndex.value : this.keyIndex,
      creationTime:
          data.creationTime.present
              ? data.creationTime.value
              : this.creationTime,
      completionTime:
          data.completionTime.present
              ? data.completionTime.value
              : this.completionTime,
      receiveWalletId:
          data.receiveWalletId.present
              ? data.receiveWalletId.value
              : this.receiveWalletId,
      sendWalletId:
          data.sendWalletId.present
              ? data.sendWalletId.value
              : this.sendWalletId,
      invoice: data.invoice.present ? data.invoice.value : this.invoice,
      paymentAddress:
          data.paymentAddress.present
              ? data.paymentAddress.value
              : this.paymentAddress,
      paymentAmount:
          data.paymentAmount.present
              ? data.paymentAmount.value
              : this.paymentAmount,
      receiveAddress:
          data.receiveAddress.present
              ? data.receiveAddress.value
              : this.receiveAddress,
      receiveTxid:
          data.receiveTxid.present ? data.receiveTxid.value : this.receiveTxid,
      sendTxid: data.sendTxid.present ? data.sendTxid.value : this.sendTxid,
      preimage: data.preimage.present ? data.preimage.value : this.preimage,
      refundAddress:
          data.refundAddress.present
              ? data.refundAddress.value
              : this.refundAddress,
      refundTxid:
          data.refundTxid.present ? data.refundTxid.value : this.refundTxid,
      boltzFees: data.boltzFees.present ? data.boltzFees.value : this.boltzFees,
      lockupFees:
          data.lockupFees.present ? data.lockupFees.value : this.lockupFees,
      claimFees: data.claimFees.present ? data.claimFees.value : this.claimFees,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SwapsData(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('direction: $direction, ')
          ..write('status: $status, ')
          ..write('isTestnet: $isTestnet, ')
          ..write('keyIndex: $keyIndex, ')
          ..write('creationTime: $creationTime, ')
          ..write('completionTime: $completionTime, ')
          ..write('receiveWalletId: $receiveWalletId, ')
          ..write('sendWalletId: $sendWalletId, ')
          ..write('invoice: $invoice, ')
          ..write('paymentAddress: $paymentAddress, ')
          ..write('paymentAmount: $paymentAmount, ')
          ..write('receiveAddress: $receiveAddress, ')
          ..write('receiveTxid: $receiveTxid, ')
          ..write('sendTxid: $sendTxid, ')
          ..write('preimage: $preimage, ')
          ..write('refundAddress: $refundAddress, ')
          ..write('refundTxid: $refundTxid, ')
          ..write('boltzFees: $boltzFees, ')
          ..write('lockupFees: $lockupFees, ')
          ..write('claimFees: $claimFees')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    type,
    direction,
    status,
    isTestnet,
    keyIndex,
    creationTime,
    completionTime,
    receiveWalletId,
    sendWalletId,
    invoice,
    paymentAddress,
    paymentAmount,
    receiveAddress,
    receiveTxid,
    sendTxid,
    preimage,
    refundAddress,
    refundTxid,
    boltzFees,
    lockupFees,
    claimFees,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SwapsData &&
          other.id == this.id &&
          other.type == this.type &&
          other.direction == this.direction &&
          other.status == this.status &&
          other.isTestnet == this.isTestnet &&
          other.keyIndex == this.keyIndex &&
          other.creationTime == this.creationTime &&
          other.completionTime == this.completionTime &&
          other.receiveWalletId == this.receiveWalletId &&
          other.sendWalletId == this.sendWalletId &&
          other.invoice == this.invoice &&
          other.paymentAddress == this.paymentAddress &&
          other.paymentAmount == this.paymentAmount &&
          other.receiveAddress == this.receiveAddress &&
          other.receiveTxid == this.receiveTxid &&
          other.sendTxid == this.sendTxid &&
          other.preimage == this.preimage &&
          other.refundAddress == this.refundAddress &&
          other.refundTxid == this.refundTxid &&
          other.boltzFees == this.boltzFees &&
          other.lockupFees == this.lockupFees &&
          other.claimFees == this.claimFees);
}

class SwapsCompanion extends UpdateCompanion<SwapsData> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> direction;
  final Value<String> status;
  final Value<bool> isTestnet;
  final Value<int> keyIndex;
  final Value<int> creationTime;
  final Value<int?> completionTime;
  final Value<String?> receiveWalletId;
  final Value<String?> sendWalletId;
  final Value<String?> invoice;
  final Value<String?> paymentAddress;
  final Value<int?> paymentAmount;
  final Value<String?> receiveAddress;
  final Value<String?> receiveTxid;
  final Value<String?> sendTxid;
  final Value<String?> preimage;
  final Value<String?> refundAddress;
  final Value<String?> refundTxid;
  final Value<int?> boltzFees;
  final Value<int?> lockupFees;
  final Value<int?> claimFees;
  final Value<int> rowid;
  const SwapsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.direction = const Value.absent(),
    this.status = const Value.absent(),
    this.isTestnet = const Value.absent(),
    this.keyIndex = const Value.absent(),
    this.creationTime = const Value.absent(),
    this.completionTime = const Value.absent(),
    this.receiveWalletId = const Value.absent(),
    this.sendWalletId = const Value.absent(),
    this.invoice = const Value.absent(),
    this.paymentAddress = const Value.absent(),
    this.paymentAmount = const Value.absent(),
    this.receiveAddress = const Value.absent(),
    this.receiveTxid = const Value.absent(),
    this.sendTxid = const Value.absent(),
    this.preimage = const Value.absent(),
    this.refundAddress = const Value.absent(),
    this.refundTxid = const Value.absent(),
    this.boltzFees = const Value.absent(),
    this.lockupFees = const Value.absent(),
    this.claimFees = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SwapsCompanion.insert({
    required String id,
    required String type,
    required String direction,
    required String status,
    required bool isTestnet,
    required int keyIndex,
    required int creationTime,
    this.completionTime = const Value.absent(),
    this.receiveWalletId = const Value.absent(),
    this.sendWalletId = const Value.absent(),
    this.invoice = const Value.absent(),
    this.paymentAddress = const Value.absent(),
    this.paymentAmount = const Value.absent(),
    this.receiveAddress = const Value.absent(),
    this.receiveTxid = const Value.absent(),
    this.sendTxid = const Value.absent(),
    this.preimage = const Value.absent(),
    this.refundAddress = const Value.absent(),
    this.refundTxid = const Value.absent(),
    this.boltzFees = const Value.absent(),
    this.lockupFees = const Value.absent(),
    this.claimFees = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       direction = Value(direction),
       status = Value(status),
       isTestnet = Value(isTestnet),
       keyIndex = Value(keyIndex),
       creationTime = Value(creationTime);
  static Insertable<SwapsData> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? direction,
    Expression<String>? status,
    Expression<bool>? isTestnet,
    Expression<int>? keyIndex,
    Expression<int>? creationTime,
    Expression<int>? completionTime,
    Expression<String>? receiveWalletId,
    Expression<String>? sendWalletId,
    Expression<String>? invoice,
    Expression<String>? paymentAddress,
    Expression<int>? paymentAmount,
    Expression<String>? receiveAddress,
    Expression<String>? receiveTxid,
    Expression<String>? sendTxid,
    Expression<String>? preimage,
    Expression<String>? refundAddress,
    Expression<String>? refundTxid,
    Expression<int>? boltzFees,
    Expression<int>? lockupFees,
    Expression<int>? claimFees,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (direction != null) 'direction': direction,
      if (status != null) 'status': status,
      if (isTestnet != null) 'is_testnet': isTestnet,
      if (keyIndex != null) 'key_index': keyIndex,
      if (creationTime != null) 'creation_time': creationTime,
      if (completionTime != null) 'completion_time': completionTime,
      if (receiveWalletId != null) 'receive_wallet_id': receiveWalletId,
      if (sendWalletId != null) 'send_wallet_id': sendWalletId,
      if (invoice != null) 'invoice': invoice,
      if (paymentAddress != null) 'payment_address': paymentAddress,
      if (paymentAmount != null) 'payment_amount': paymentAmount,
      if (receiveAddress != null) 'receive_address': receiveAddress,
      if (receiveTxid != null) 'receive_txid': receiveTxid,
      if (sendTxid != null) 'send_txid': sendTxid,
      if (preimage != null) 'preimage': preimage,
      if (refundAddress != null) 'refund_address': refundAddress,
      if (refundTxid != null) 'refund_txid': refundTxid,
      if (boltzFees != null) 'boltz_fees': boltzFees,
      if (lockupFees != null) 'lockup_fees': lockupFees,
      if (claimFees != null) 'claim_fees': claimFees,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SwapsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? direction,
    Value<String>? status,
    Value<bool>? isTestnet,
    Value<int>? keyIndex,
    Value<int>? creationTime,
    Value<int?>? completionTime,
    Value<String?>? receiveWalletId,
    Value<String?>? sendWalletId,
    Value<String?>? invoice,
    Value<String?>? paymentAddress,
    Value<int?>? paymentAmount,
    Value<String?>? receiveAddress,
    Value<String?>? receiveTxid,
    Value<String?>? sendTxid,
    Value<String?>? preimage,
    Value<String?>? refundAddress,
    Value<String?>? refundTxid,
    Value<int?>? boltzFees,
    Value<int?>? lockupFees,
    Value<int?>? claimFees,
    Value<int>? rowid,
  }) {
    return SwapsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      isTestnet: isTestnet ?? this.isTestnet,
      keyIndex: keyIndex ?? this.keyIndex,
      creationTime: creationTime ?? this.creationTime,
      completionTime: completionTime ?? this.completionTime,
      receiveWalletId: receiveWalletId ?? this.receiveWalletId,
      sendWalletId: sendWalletId ?? this.sendWalletId,
      invoice: invoice ?? this.invoice,
      paymentAddress: paymentAddress ?? this.paymentAddress,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      receiveAddress: receiveAddress ?? this.receiveAddress,
      receiveTxid: receiveTxid ?? this.receiveTxid,
      sendTxid: sendTxid ?? this.sendTxid,
      preimage: preimage ?? this.preimage,
      refundAddress: refundAddress ?? this.refundAddress,
      refundTxid: refundTxid ?? this.refundTxid,
      boltzFees: boltzFees ?? this.boltzFees,
      lockupFees: lockupFees ?? this.lockupFees,
      claimFees: claimFees ?? this.claimFees,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isTestnet.present) {
      map['is_testnet'] = Variable<bool>(isTestnet.value);
    }
    if (keyIndex.present) {
      map['key_index'] = Variable<int>(keyIndex.value);
    }
    if (creationTime.present) {
      map['creation_time'] = Variable<int>(creationTime.value);
    }
    if (completionTime.present) {
      map['completion_time'] = Variable<int>(completionTime.value);
    }
    if (receiveWalletId.present) {
      map['receive_wallet_id'] = Variable<String>(receiveWalletId.value);
    }
    if (sendWalletId.present) {
      map['send_wallet_id'] = Variable<String>(sendWalletId.value);
    }
    if (invoice.present) {
      map['invoice'] = Variable<String>(invoice.value);
    }
    if (paymentAddress.present) {
      map['payment_address'] = Variable<String>(paymentAddress.value);
    }
    if (paymentAmount.present) {
      map['payment_amount'] = Variable<int>(paymentAmount.value);
    }
    if (receiveAddress.present) {
      map['receive_address'] = Variable<String>(receiveAddress.value);
    }
    if (receiveTxid.present) {
      map['receive_txid'] = Variable<String>(receiveTxid.value);
    }
    if (sendTxid.present) {
      map['send_txid'] = Variable<String>(sendTxid.value);
    }
    if (preimage.present) {
      map['preimage'] = Variable<String>(preimage.value);
    }
    if (refundAddress.present) {
      map['refund_address'] = Variable<String>(refundAddress.value);
    }
    if (refundTxid.present) {
      map['refund_txid'] = Variable<String>(refundTxid.value);
    }
    if (boltzFees.present) {
      map['boltz_fees'] = Variable<int>(boltzFees.value);
    }
    if (lockupFees.present) {
      map['lockup_fees'] = Variable<int>(lockupFees.value);
    }
    if (claimFees.present) {
      map['claim_fees'] = Variable<int>(claimFees.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SwapsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('direction: $direction, ')
          ..write('status: $status, ')
          ..write('isTestnet: $isTestnet, ')
          ..write('keyIndex: $keyIndex, ')
          ..write('creationTime: $creationTime, ')
          ..write('completionTime: $completionTime, ')
          ..write('receiveWalletId: $receiveWalletId, ')
          ..write('sendWalletId: $sendWalletId, ')
          ..write('invoice: $invoice, ')
          ..write('paymentAddress: $paymentAddress, ')
          ..write('paymentAmount: $paymentAmount, ')
          ..write('receiveAddress: $receiveAddress, ')
          ..write('receiveTxid: $receiveTxid, ')
          ..write('sendTxid: $sendTxid, ')
          ..write('preimage: $preimage, ')
          ..write('refundAddress: $refundAddress, ')
          ..write('refundTxid: $refundTxid, ')
          ..write('boltzFees: $boltzFees, ')
          ..write('lockupFees: $lockupFees, ')
          ..write('claimFees: $claimFees, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AutoSwap extends Table with TableInfo<AutoSwap, AutoSwapData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AutoSwap(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<int> balanceThresholdSats = GeneratedColumn<int>(
    'balance_threshold_sats',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<double> feeThresholdPercent =
      GeneratedColumn<double>(
        'fee_threshold_percent',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<bool> blockTillNextExecution =
      GeneratedColumn<bool>(
        'block_till_next_execution',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("block_till_next_execution" IN (0, 1))',
        ),
        defaultValue: const CustomExpression('0'),
      );
  late final GeneratedColumn<bool> alwaysBlock = GeneratedColumn<bool>(
    'always_block',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("always_block" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    enabled,
    balanceThresholdSats,
    feeThresholdPercent,
    blockTillNextExecution,
    alwaysBlock,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'auto_swap';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AutoSwapData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AutoSwapData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      enabled:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}enabled'],
          )!,
      balanceThresholdSats:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}balance_threshold_sats'],
          )!,
      feeThresholdPercent:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}fee_threshold_percent'],
          )!,
      blockTillNextExecution:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}block_till_next_execution'],
          )!,
      alwaysBlock:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}always_block'],
          )!,
    );
  }

  @override
  AutoSwap createAlias(String alias) {
    return AutoSwap(attachedDatabase, alias);
  }
}

class AutoSwapData extends DataClass implements Insertable<AutoSwapData> {
  final int id;
  final bool enabled;
  final int balanceThresholdSats;
  final double feeThresholdPercent;
  final bool blockTillNextExecution;
  final bool alwaysBlock;
  const AutoSwapData({
    required this.id,
    required this.enabled,
    required this.balanceThresholdSats,
    required this.feeThresholdPercent,
    required this.blockTillNextExecution,
    required this.alwaysBlock,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['enabled'] = Variable<bool>(enabled);
    map['balance_threshold_sats'] = Variable<int>(balanceThresholdSats);
    map['fee_threshold_percent'] = Variable<double>(feeThresholdPercent);
    map['block_till_next_execution'] = Variable<bool>(blockTillNextExecution);
    map['always_block'] = Variable<bool>(alwaysBlock);
    return map;
  }

  AutoSwapCompanion toCompanion(bool nullToAbsent) {
    return AutoSwapCompanion(
      id: Value(id),
      enabled: Value(enabled),
      balanceThresholdSats: Value(balanceThresholdSats),
      feeThresholdPercent: Value(feeThresholdPercent),
      blockTillNextExecution: Value(blockTillNextExecution),
      alwaysBlock: Value(alwaysBlock),
    );
  }

  factory AutoSwapData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AutoSwapData(
      id: serializer.fromJson<int>(json['id']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      balanceThresholdSats: serializer.fromJson<int>(
        json['balanceThresholdSats'],
      ),
      feeThresholdPercent: serializer.fromJson<double>(
        json['feeThresholdPercent'],
      ),
      blockTillNextExecution: serializer.fromJson<bool>(
        json['blockTillNextExecution'],
      ),
      alwaysBlock: serializer.fromJson<bool>(json['alwaysBlock']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'enabled': serializer.toJson<bool>(enabled),
      'balanceThresholdSats': serializer.toJson<int>(balanceThresholdSats),
      'feeThresholdPercent': serializer.toJson<double>(feeThresholdPercent),
      'blockTillNextExecution': serializer.toJson<bool>(blockTillNextExecution),
      'alwaysBlock': serializer.toJson<bool>(alwaysBlock),
    };
  }

  AutoSwapData copyWith({
    int? id,
    bool? enabled,
    int? balanceThresholdSats,
    double? feeThresholdPercent,
    bool? blockTillNextExecution,
    bool? alwaysBlock,
  }) => AutoSwapData(
    id: id ?? this.id,
    enabled: enabled ?? this.enabled,
    balanceThresholdSats: balanceThresholdSats ?? this.balanceThresholdSats,
    feeThresholdPercent: feeThresholdPercent ?? this.feeThresholdPercent,
    blockTillNextExecution:
        blockTillNextExecution ?? this.blockTillNextExecution,
    alwaysBlock: alwaysBlock ?? this.alwaysBlock,
  );
  AutoSwapData copyWithCompanion(AutoSwapCompanion data) {
    return AutoSwapData(
      id: data.id.present ? data.id.value : this.id,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      balanceThresholdSats:
          data.balanceThresholdSats.present
              ? data.balanceThresholdSats.value
              : this.balanceThresholdSats,
      feeThresholdPercent:
          data.feeThresholdPercent.present
              ? data.feeThresholdPercent.value
              : this.feeThresholdPercent,
      blockTillNextExecution:
          data.blockTillNextExecution.present
              ? data.blockTillNextExecution.value
              : this.blockTillNextExecution,
      alwaysBlock:
          data.alwaysBlock.present ? data.alwaysBlock.value : this.alwaysBlock,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AutoSwapData(')
          ..write('id: $id, ')
          ..write('enabled: $enabled, ')
          ..write('balanceThresholdSats: $balanceThresholdSats, ')
          ..write('feeThresholdPercent: $feeThresholdPercent, ')
          ..write('blockTillNextExecution: $blockTillNextExecution, ')
          ..write('alwaysBlock: $alwaysBlock')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    enabled,
    balanceThresholdSats,
    feeThresholdPercent,
    blockTillNextExecution,
    alwaysBlock,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AutoSwapData &&
          other.id == this.id &&
          other.enabled == this.enabled &&
          other.balanceThresholdSats == this.balanceThresholdSats &&
          other.feeThresholdPercent == this.feeThresholdPercent &&
          other.blockTillNextExecution == this.blockTillNextExecution &&
          other.alwaysBlock == this.alwaysBlock);
}

class AutoSwapCompanion extends UpdateCompanion<AutoSwapData> {
  final Value<int> id;
  final Value<bool> enabled;
  final Value<int> balanceThresholdSats;
  final Value<double> feeThresholdPercent;
  final Value<bool> blockTillNextExecution;
  final Value<bool> alwaysBlock;
  const AutoSwapCompanion({
    this.id = const Value.absent(),
    this.enabled = const Value.absent(),
    this.balanceThresholdSats = const Value.absent(),
    this.feeThresholdPercent = const Value.absent(),
    this.blockTillNextExecution = const Value.absent(),
    this.alwaysBlock = const Value.absent(),
  });
  AutoSwapCompanion.insert({
    this.id = const Value.absent(),
    this.enabled = const Value.absent(),
    required int balanceThresholdSats,
    required double feeThresholdPercent,
    this.blockTillNextExecution = const Value.absent(),
    this.alwaysBlock = const Value.absent(),
  }) : balanceThresholdSats = Value(balanceThresholdSats),
       feeThresholdPercent = Value(feeThresholdPercent);
  static Insertable<AutoSwapData> custom({
    Expression<int>? id,
    Expression<bool>? enabled,
    Expression<int>? balanceThresholdSats,
    Expression<double>? feeThresholdPercent,
    Expression<bool>? blockTillNextExecution,
    Expression<bool>? alwaysBlock,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (enabled != null) 'enabled': enabled,
      if (balanceThresholdSats != null)
        'balance_threshold_sats': balanceThresholdSats,
      if (feeThresholdPercent != null)
        'fee_threshold_percent': feeThresholdPercent,
      if (blockTillNextExecution != null)
        'block_till_next_execution': blockTillNextExecution,
      if (alwaysBlock != null) 'always_block': alwaysBlock,
    });
  }

  AutoSwapCompanion copyWith({
    Value<int>? id,
    Value<bool>? enabled,
    Value<int>? balanceThresholdSats,
    Value<double>? feeThresholdPercent,
    Value<bool>? blockTillNextExecution,
    Value<bool>? alwaysBlock,
  }) {
    return AutoSwapCompanion(
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      balanceThresholdSats: balanceThresholdSats ?? this.balanceThresholdSats,
      feeThresholdPercent: feeThresholdPercent ?? this.feeThresholdPercent,
      blockTillNextExecution:
          blockTillNextExecution ?? this.blockTillNextExecution,
      alwaysBlock: alwaysBlock ?? this.alwaysBlock,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (balanceThresholdSats.present) {
      map['balance_threshold_sats'] = Variable<int>(balanceThresholdSats.value);
    }
    if (feeThresholdPercent.present) {
      map['fee_threshold_percent'] = Variable<double>(
        feeThresholdPercent.value,
      );
    }
    if (blockTillNextExecution.present) {
      map['block_till_next_execution'] = Variable<bool>(
        blockTillNextExecution.value,
      );
    }
    if (alwaysBlock.present) {
      map['always_block'] = Variable<bool>(alwaysBlock.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AutoSwapCompanion(')
          ..write('id: $id, ')
          ..write('enabled: $enabled, ')
          ..write('balanceThresholdSats: $balanceThresholdSats, ')
          ..write('feeThresholdPercent: $feeThresholdPercent, ')
          ..write('blockTillNextExecution: $blockTillNextExecution, ')
          ..write('alwaysBlock: $alwaysBlock')
          ..write(')'))
        .toString();
  }
}

class WalletAddressHistory extends Table
    with TableInfo<WalletAddressHistory, WalletAddressHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  WalletAddressHistory(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> walletId = GeneratedColumn<String>(
    'wallet_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> index = GeneratedColumn<int>(
    'index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> isChange = GeneratedColumn<bool>(
    'is_change',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_change" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<int> balanceSat = GeneratedColumn<int>(
    'balance_sat',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> nrOfTransactions = GeneratedColumn<int>(
    'nr_of_transactions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    address,
    walletId,
    index,
    isChange,
    balanceSat,
    nrOfTransactions,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_address_history';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletAddressHistoryData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletAddressHistoryData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      address:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}address'],
          )!,
      walletId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}wallet_id'],
          )!,
      index:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}index'],
          )!,
      isChange:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_change'],
          )!,
      balanceSat:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}balance_sat'],
          )!,
      nrOfTransactions:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}nr_of_transactions'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  WalletAddressHistory createAlias(String alias) {
    return WalletAddressHistory(attachedDatabase, alias);
  }
}

class WalletAddressHistoryData extends DataClass
    implements Insertable<WalletAddressHistoryData> {
  final int id;
  final String address;
  final String walletId;
  final int index;
  final bool isChange;
  final int balanceSat;
  final int nrOfTransactions;
  final DateTime createdAt;
  final DateTime updatedAt;
  const WalletAddressHistoryData({
    required this.id,
    required this.address,
    required this.walletId,
    required this.index,
    required this.isChange,
    required this.balanceSat,
    required this.nrOfTransactions,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['address'] = Variable<String>(address);
    map['wallet_id'] = Variable<String>(walletId);
    map['index'] = Variable<int>(index);
    map['is_change'] = Variable<bool>(isChange);
    map['balance_sat'] = Variable<int>(balanceSat);
    map['nr_of_transactions'] = Variable<int>(nrOfTransactions);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WalletAddressHistoryCompanion toCompanion(bool nullToAbsent) {
    return WalletAddressHistoryCompanion(
      id: Value(id),
      address: Value(address),
      walletId: Value(walletId),
      index: Value(index),
      isChange: Value(isChange),
      balanceSat: Value(balanceSat),
      nrOfTransactions: Value(nrOfTransactions),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WalletAddressHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletAddressHistoryData(
      id: serializer.fromJson<int>(json['id']),
      address: serializer.fromJson<String>(json['address']),
      walletId: serializer.fromJson<String>(json['walletId']),
      index: serializer.fromJson<int>(json['index']),
      isChange: serializer.fromJson<bool>(json['isChange']),
      balanceSat: serializer.fromJson<int>(json['balanceSat']),
      nrOfTransactions: serializer.fromJson<int>(json['nrOfTransactions']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'address': serializer.toJson<String>(address),
      'walletId': serializer.toJson<String>(walletId),
      'index': serializer.toJson<int>(index),
      'isChange': serializer.toJson<bool>(isChange),
      'balanceSat': serializer.toJson<int>(balanceSat),
      'nrOfTransactions': serializer.toJson<int>(nrOfTransactions),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WalletAddressHistoryData copyWith({
    int? id,
    String? address,
    String? walletId,
    int? index,
    bool? isChange,
    int? balanceSat,
    int? nrOfTransactions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => WalletAddressHistoryData(
    id: id ?? this.id,
    address: address ?? this.address,
    walletId: walletId ?? this.walletId,
    index: index ?? this.index,
    isChange: isChange ?? this.isChange,
    balanceSat: balanceSat ?? this.balanceSat,
    nrOfTransactions: nrOfTransactions ?? this.nrOfTransactions,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WalletAddressHistoryData copyWithCompanion(
    WalletAddressHistoryCompanion data,
  ) {
    return WalletAddressHistoryData(
      id: data.id.present ? data.id.value : this.id,
      address: data.address.present ? data.address.value : this.address,
      walletId: data.walletId.present ? data.walletId.value : this.walletId,
      index: data.index.present ? data.index.value : this.index,
      isChange: data.isChange.present ? data.isChange.value : this.isChange,
      balanceSat:
          data.balanceSat.present ? data.balanceSat.value : this.balanceSat,
      nrOfTransactions:
          data.nrOfTransactions.present
              ? data.nrOfTransactions.value
              : this.nrOfTransactions,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletAddressHistoryData(')
          ..write('id: $id, ')
          ..write('address: $address, ')
          ..write('walletId: $walletId, ')
          ..write('index: $index, ')
          ..write('isChange: $isChange, ')
          ..write('balanceSat: $balanceSat, ')
          ..write('nrOfTransactions: $nrOfTransactions, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    address,
    walletId,
    index,
    isChange,
    balanceSat,
    nrOfTransactions,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletAddressHistoryData &&
          other.id == this.id &&
          other.address == this.address &&
          other.walletId == this.walletId &&
          other.index == this.index &&
          other.isChange == this.isChange &&
          other.balanceSat == this.balanceSat &&
          other.nrOfTransactions == this.nrOfTransactions &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WalletAddressHistoryCompanion
    extends UpdateCompanion<WalletAddressHistoryData> {
  final Value<int> id;
  final Value<String> address;
  final Value<String> walletId;
  final Value<int> index;
  final Value<bool> isChange;
  final Value<int> balanceSat;
  final Value<int> nrOfTransactions;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const WalletAddressHistoryCompanion({
    this.id = const Value.absent(),
    this.address = const Value.absent(),
    this.walletId = const Value.absent(),
    this.index = const Value.absent(),
    this.isChange = const Value.absent(),
    this.balanceSat = const Value.absent(),
    this.nrOfTransactions = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  WalletAddressHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String address,
    required String walletId,
    required int index,
    required bool isChange,
    required int balanceSat,
    required int nrOfTransactions,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : address = Value(address),
       walletId = Value(walletId),
       index = Value(index),
       isChange = Value(isChange),
       balanceSat = Value(balanceSat),
       nrOfTransactions = Value(nrOfTransactions),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WalletAddressHistoryData> custom({
    Expression<int>? id,
    Expression<String>? address,
    Expression<String>? walletId,
    Expression<int>? index,
    Expression<bool>? isChange,
    Expression<int>? balanceSat,
    Expression<int>? nrOfTransactions,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (address != null) 'address': address,
      if (walletId != null) 'wallet_id': walletId,
      if (index != null) 'index': index,
      if (isChange != null) 'is_change': isChange,
      if (balanceSat != null) 'balance_sat': balanceSat,
      if (nrOfTransactions != null) 'nr_of_transactions': nrOfTransactions,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  WalletAddressHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? address,
    Value<String>? walletId,
    Value<int>? index,
    Value<bool>? isChange,
    Value<int>? balanceSat,
    Value<int>? nrOfTransactions,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return WalletAddressHistoryCompanion(
      id: id ?? this.id,
      address: address ?? this.address,
      walletId: walletId ?? this.walletId,
      index: index ?? this.index,
      isChange: isChange ?? this.isChange,
      balanceSat: balanceSat ?? this.balanceSat,
      nrOfTransactions: nrOfTransactions ?? this.nrOfTransactions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (walletId.present) {
      map['wallet_id'] = Variable<String>(walletId.value);
    }
    if (index.present) {
      map['index'] = Variable<int>(index.value);
    }
    if (isChange.present) {
      map['is_change'] = Variable<bool>(isChange.value);
    }
    if (balanceSat.present) {
      map['balance_sat'] = Variable<int>(balanceSat.value);
    }
    if (nrOfTransactions.present) {
      map['nr_of_transactions'] = Variable<int>(nrOfTransactions.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletAddressHistoryCompanion(')
          ..write('id: $id, ')
          ..write('address: $address, ')
          ..write('walletId: $walletId, ')
          ..write('index: $index, ')
          ..write('isChange: $isChange, ')
          ..write('balanceSat: $balanceSat, ')
          ..write('nrOfTransactions: $nrOfTransactions, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class DatabaseAtV3 extends GeneratedDatabase {
  DatabaseAtV3(QueryExecutor e) : super(e);
  late final Transactions transactions = Transactions(this);
  late final WalletMetadatas walletMetadatas = WalletMetadatas(this);
  late final Labels labels = Labels(this);
  late final Settings settings = Settings(this);
  late final PayjoinSenders payjoinSenders = PayjoinSenders(this);
  late final PayjoinReceivers payjoinReceivers = PayjoinReceivers(this);
  late final ElectrumServers electrumServers = ElectrumServers(this);
  late final Swaps swaps = Swaps(this);
  late final AutoSwap autoSwap = AutoSwap(this);
  late final WalletAddressHistory walletAddressHistory = WalletAddressHistory(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    transactions,
    walletMetadatas,
    labels,
    settings,
    payjoinSenders,
    payjoinReceivers,
    electrumServers,
    swaps,
    autoSwap,
    walletAddressHistory,
  ];
  @override
  int get schemaVersion => 3;
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}
