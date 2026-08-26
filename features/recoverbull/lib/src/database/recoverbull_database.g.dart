// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recoverbull_database.dart';

// ignore_for_file: type=lint
class $RecoverbullStateTable extends RecoverbullState
    with TableInfo<$RecoverbullStateTable, RecoverbullStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecoverbullStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _serverUrlOverrideMeta = const VerificationMeta(
    'serverUrlOverride',
  );
  @override
  late final GeneratedColumn<String> serverUrlOverride =
      GeneratedColumn<String>(
        'server_url_override',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _permissionGrantedMeta = const VerificationMeta(
    'permissionGranted',
  );
  @override
  late final GeneratedColumn<bool> permissionGranted = GeneratedColumn<bool>(
    'permission_granted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("permission_granted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _attemptMonitoringEnabledMeta =
      const VerificationMeta('attemptMonitoringEnabled');
  @override
  late final GeneratedColumn<bool> attemptMonitoringEnabled =
      GeneratedColumn<bool>(
        'attempt_monitoring_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("attempt_monitoring_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _lastEncryptedBackupAtMeta =
      const VerificationMeta('lastEncryptedBackupAt');
  @override
  late final GeneratedColumn<DateTime> lastEncryptedBackupAt =
      GeneratedColumn<DateTime>(
        'last_encrypted_backup_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastVerifiedEncryptedBackupAtMeta =
      const VerificationMeta('lastVerifiedEncryptedBackupAt');
  @override
  late final GeneratedColumn<DateTime> lastVerifiedEncryptedBackupAt =
      GeneratedColumn<DateTime>(
        'last_verified_encrypted_backup_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSuccessfulCheckAtMeta =
      const VerificationMeta('lastSuccessfulCheckAt');
  @override
  late final GeneratedColumn<DateTime> lastSuccessfulCheckAt =
      GeneratedColumn<DateTime>(
        'last_successful_check_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _collectionStartedAtMeta =
      const VerificationMeta('collectionStartedAt');
  @override
  late final GeneratedColumn<DateTime> collectionStartedAt =
      GeneratedColumn<DateTime>(
        'collection_started_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _consecutiveFailuresMeta =
      const VerificationMeta('consecutiveFailures');
  @override
  late final GeneratedColumn<int> consecutiveFailures = GeneratedColumn<int>(
    'consecutive_failures',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastUnavailabilityWarningAtMeta =
      const VerificationMeta('lastUnavailabilityWarningAt');
  @override
  late final GeneratedColumn<DateTime> lastUnavailabilityWarningAt =
      GeneratedColumn<DateTime>(
        'last_unavailability_warning_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<int> generation = GeneratedColumn<int>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverUrlOverride,
    permissionGranted,
    attemptMonitoringEnabled,
    lastEncryptedBackupAt,
    lastVerifiedEncryptedBackupAt,
    etag,
    lastSuccessfulCheckAt,
    collectionStartedAt,
    consecutiveFailures,
    lastUnavailabilityWarningAt,
    generation,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recoverbull_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecoverbullStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_url_override')) {
      context.handle(
        _serverUrlOverrideMeta,
        serverUrlOverride.isAcceptableOrUnknown(
          data['server_url_override']!,
          _serverUrlOverrideMeta,
        ),
      );
    }
    if (data.containsKey('permission_granted')) {
      context.handle(
        _permissionGrantedMeta,
        permissionGranted.isAcceptableOrUnknown(
          data['permission_granted']!,
          _permissionGrantedMeta,
        ),
      );
    }
    if (data.containsKey('attempt_monitoring_enabled')) {
      context.handle(
        _attemptMonitoringEnabledMeta,
        attemptMonitoringEnabled.isAcceptableOrUnknown(
          data['attempt_monitoring_enabled']!,
          _attemptMonitoringEnabledMeta,
        ),
      );
    }
    if (data.containsKey('last_encrypted_backup_at')) {
      context.handle(
        _lastEncryptedBackupAtMeta,
        lastEncryptedBackupAt.isAcceptableOrUnknown(
          data['last_encrypted_backup_at']!,
          _lastEncryptedBackupAtMeta,
        ),
      );
    }
    if (data.containsKey('last_verified_encrypted_backup_at')) {
      context.handle(
        _lastVerifiedEncryptedBackupAtMeta,
        lastVerifiedEncryptedBackupAt.isAcceptableOrUnknown(
          data['last_verified_encrypted_backup_at']!,
          _lastVerifiedEncryptedBackupAtMeta,
        ),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('last_successful_check_at')) {
      context.handle(
        _lastSuccessfulCheckAtMeta,
        lastSuccessfulCheckAt.isAcceptableOrUnknown(
          data['last_successful_check_at']!,
          _lastSuccessfulCheckAtMeta,
        ),
      );
    }
    if (data.containsKey('collection_started_at')) {
      context.handle(
        _collectionStartedAtMeta,
        collectionStartedAt.isAcceptableOrUnknown(
          data['collection_started_at']!,
          _collectionStartedAtMeta,
        ),
      );
    }
    if (data.containsKey('consecutive_failures')) {
      context.handle(
        _consecutiveFailuresMeta,
        consecutiveFailures.isAcceptableOrUnknown(
          data['consecutive_failures']!,
          _consecutiveFailuresMeta,
        ),
      );
    }
    if (data.containsKey('last_unavailability_warning_at')) {
      context.handle(
        _lastUnavailabilityWarningAtMeta,
        lastUnavailabilityWarningAt.isAcceptableOrUnknown(
          data['last_unavailability_warning_at']!,
          _lastUnavailabilityWarningAtMeta,
        ),
      );
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecoverbullStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecoverbullStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverUrlOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_url_override'],
      ),
      permissionGranted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}permission_granted'],
      )!,
      attemptMonitoringEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}attempt_monitoring_enabled'],
      )!,
      lastEncryptedBackupAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_encrypted_backup_at'],
      ),
      lastVerifiedEncryptedBackupAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_verified_encrypted_backup_at'],
      ),
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      lastSuccessfulCheckAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_successful_check_at'],
      ),
      collectionStartedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}collection_started_at'],
      ),
      consecutiveFailures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}consecutive_failures'],
      )!,
      lastUnavailabilityWarningAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_unavailability_warning_at'],
      ),
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $RecoverbullStateTable createAlias(String alias) {
    return $RecoverbullStateTable(attachedDatabase, alias);
  }
}

class RecoverbullStateData extends DataClass
    implements Insertable<RecoverbullStateData> {
  final int id;
  final String? serverUrlOverride;
  final bool permissionGranted;
  final bool attemptMonitoringEnabled;
  final DateTime? lastEncryptedBackupAt;
  final DateTime? lastVerifiedEncryptedBackupAt;
  final String? etag;
  final DateTime? lastSuccessfulCheckAt;
  final DateTime? collectionStartedAt;
  final int consecutiveFailures;
  final DateTime? lastUnavailabilityWarningAt;
  final int generation;
  final int revision;
  const RecoverbullStateData({
    required this.id,
    this.serverUrlOverride,
    required this.permissionGranted,
    required this.attemptMonitoringEnabled,
    this.lastEncryptedBackupAt,
    this.lastVerifiedEncryptedBackupAt,
    this.etag,
    this.lastSuccessfulCheckAt,
    this.collectionStartedAt,
    required this.consecutiveFailures,
    this.lastUnavailabilityWarningAt,
    required this.generation,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverUrlOverride != null) {
      map['server_url_override'] = Variable<String>(serverUrlOverride);
    }
    map['permission_granted'] = Variable<bool>(permissionGranted);
    map['attempt_monitoring_enabled'] = Variable<bool>(
      attemptMonitoringEnabled,
    );
    if (!nullToAbsent || lastEncryptedBackupAt != null) {
      map['last_encrypted_backup_at'] = Variable<DateTime>(
        lastEncryptedBackupAt,
      );
    }
    if (!nullToAbsent || lastVerifiedEncryptedBackupAt != null) {
      map['last_verified_encrypted_backup_at'] = Variable<DateTime>(
        lastVerifiedEncryptedBackupAt,
      );
    }
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || lastSuccessfulCheckAt != null) {
      map['last_successful_check_at'] = Variable<DateTime>(
        lastSuccessfulCheckAt,
      );
    }
    if (!nullToAbsent || collectionStartedAt != null) {
      map['collection_started_at'] = Variable<DateTime>(collectionStartedAt);
    }
    map['consecutive_failures'] = Variable<int>(consecutiveFailures);
    if (!nullToAbsent || lastUnavailabilityWarningAt != null) {
      map['last_unavailability_warning_at'] = Variable<DateTime>(
        lastUnavailabilityWarningAt,
      );
    }
    map['generation'] = Variable<int>(generation);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  RecoverbullStateCompanion toCompanion(bool nullToAbsent) {
    return RecoverbullStateCompanion(
      id: Value(id),
      serverUrlOverride: serverUrlOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUrlOverride),
      permissionGranted: Value(permissionGranted),
      attemptMonitoringEnabled: Value(attemptMonitoringEnabled),
      lastEncryptedBackupAt: lastEncryptedBackupAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEncryptedBackupAt),
      lastVerifiedEncryptedBackupAt:
          lastVerifiedEncryptedBackupAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastVerifiedEncryptedBackupAt),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      lastSuccessfulCheckAt: lastSuccessfulCheckAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessfulCheckAt),
      collectionStartedAt: collectionStartedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(collectionStartedAt),
      consecutiveFailures: Value(consecutiveFailures),
      lastUnavailabilityWarningAt:
          lastUnavailabilityWarningAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUnavailabilityWarningAt),
      generation: Value(generation),
      revision: Value(revision),
    );
  }

  factory RecoverbullStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecoverbullStateData(
      id: serializer.fromJson<int>(json['id']),
      serverUrlOverride: serializer.fromJson<String?>(
        json['serverUrlOverride'],
      ),
      permissionGranted: serializer.fromJson<bool>(json['permissionGranted']),
      attemptMonitoringEnabled: serializer.fromJson<bool>(
        json['attemptMonitoringEnabled'],
      ),
      lastEncryptedBackupAt: serializer.fromJson<DateTime?>(
        json['lastEncryptedBackupAt'],
      ),
      lastVerifiedEncryptedBackupAt: serializer.fromJson<DateTime?>(
        json['lastVerifiedEncryptedBackupAt'],
      ),
      etag: serializer.fromJson<String?>(json['etag']),
      lastSuccessfulCheckAt: serializer.fromJson<DateTime?>(
        json['lastSuccessfulCheckAt'],
      ),
      collectionStartedAt: serializer.fromJson<DateTime?>(
        json['collectionStartedAt'],
      ),
      consecutiveFailures: serializer.fromJson<int>(
        json['consecutiveFailures'],
      ),
      lastUnavailabilityWarningAt: serializer.fromJson<DateTime?>(
        json['lastUnavailabilityWarningAt'],
      ),
      generation: serializer.fromJson<int>(json['generation']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverUrlOverride': serializer.toJson<String?>(serverUrlOverride),
      'permissionGranted': serializer.toJson<bool>(permissionGranted),
      'attemptMonitoringEnabled': serializer.toJson<bool>(
        attemptMonitoringEnabled,
      ),
      'lastEncryptedBackupAt': serializer.toJson<DateTime?>(
        lastEncryptedBackupAt,
      ),
      'lastVerifiedEncryptedBackupAt': serializer.toJson<DateTime?>(
        lastVerifiedEncryptedBackupAt,
      ),
      'etag': serializer.toJson<String?>(etag),
      'lastSuccessfulCheckAt': serializer.toJson<DateTime?>(
        lastSuccessfulCheckAt,
      ),
      'collectionStartedAt': serializer.toJson<DateTime?>(collectionStartedAt),
      'consecutiveFailures': serializer.toJson<int>(consecutiveFailures),
      'lastUnavailabilityWarningAt': serializer.toJson<DateTime?>(
        lastUnavailabilityWarningAt,
      ),
      'generation': serializer.toJson<int>(generation),
      'revision': serializer.toJson<int>(revision),
    };
  }

  RecoverbullStateData copyWith({
    int? id,
    Value<String?> serverUrlOverride = const Value.absent(),
    bool? permissionGranted,
    bool? attemptMonitoringEnabled,
    Value<DateTime?> lastEncryptedBackupAt = const Value.absent(),
    Value<DateTime?> lastVerifiedEncryptedBackupAt = const Value.absent(),
    Value<String?> etag = const Value.absent(),
    Value<DateTime?> lastSuccessfulCheckAt = const Value.absent(),
    Value<DateTime?> collectionStartedAt = const Value.absent(),
    int? consecutiveFailures,
    Value<DateTime?> lastUnavailabilityWarningAt = const Value.absent(),
    int? generation,
    int? revision,
  }) => RecoverbullStateData(
    id: id ?? this.id,
    serverUrlOverride: serverUrlOverride.present
        ? serverUrlOverride.value
        : this.serverUrlOverride,
    permissionGranted: permissionGranted ?? this.permissionGranted,
    attemptMonitoringEnabled:
        attemptMonitoringEnabled ?? this.attemptMonitoringEnabled,
    lastEncryptedBackupAt: lastEncryptedBackupAt.present
        ? lastEncryptedBackupAt.value
        : this.lastEncryptedBackupAt,
    lastVerifiedEncryptedBackupAt: lastVerifiedEncryptedBackupAt.present
        ? lastVerifiedEncryptedBackupAt.value
        : this.lastVerifiedEncryptedBackupAt,
    etag: etag.present ? etag.value : this.etag,
    lastSuccessfulCheckAt: lastSuccessfulCheckAt.present
        ? lastSuccessfulCheckAt.value
        : this.lastSuccessfulCheckAt,
    collectionStartedAt: collectionStartedAt.present
        ? collectionStartedAt.value
        : this.collectionStartedAt,
    consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    lastUnavailabilityWarningAt: lastUnavailabilityWarningAt.present
        ? lastUnavailabilityWarningAt.value
        : this.lastUnavailabilityWarningAt,
    generation: generation ?? this.generation,
    revision: revision ?? this.revision,
  );
  RecoverbullStateData copyWithCompanion(RecoverbullStateCompanion data) {
    return RecoverbullStateData(
      id: data.id.present ? data.id.value : this.id,
      serverUrlOverride: data.serverUrlOverride.present
          ? data.serverUrlOverride.value
          : this.serverUrlOverride,
      permissionGranted: data.permissionGranted.present
          ? data.permissionGranted.value
          : this.permissionGranted,
      attemptMonitoringEnabled: data.attemptMonitoringEnabled.present
          ? data.attemptMonitoringEnabled.value
          : this.attemptMonitoringEnabled,
      lastEncryptedBackupAt: data.lastEncryptedBackupAt.present
          ? data.lastEncryptedBackupAt.value
          : this.lastEncryptedBackupAt,
      lastVerifiedEncryptedBackupAt: data.lastVerifiedEncryptedBackupAt.present
          ? data.lastVerifiedEncryptedBackupAt.value
          : this.lastVerifiedEncryptedBackupAt,
      etag: data.etag.present ? data.etag.value : this.etag,
      lastSuccessfulCheckAt: data.lastSuccessfulCheckAt.present
          ? data.lastSuccessfulCheckAt.value
          : this.lastSuccessfulCheckAt,
      collectionStartedAt: data.collectionStartedAt.present
          ? data.collectionStartedAt.value
          : this.collectionStartedAt,
      consecutiveFailures: data.consecutiveFailures.present
          ? data.consecutiveFailures.value
          : this.consecutiveFailures,
      lastUnavailabilityWarningAt: data.lastUnavailabilityWarningAt.present
          ? data.lastUnavailabilityWarningAt.value
          : this.lastUnavailabilityWarningAt,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecoverbullStateData(')
          ..write('id: $id, ')
          ..write('serverUrlOverride: $serverUrlOverride, ')
          ..write('permissionGranted: $permissionGranted, ')
          ..write('attemptMonitoringEnabled: $attemptMonitoringEnabled, ')
          ..write('lastEncryptedBackupAt: $lastEncryptedBackupAt, ')
          ..write(
            'lastVerifiedEncryptedBackupAt: $lastVerifiedEncryptedBackupAt, ',
          )
          ..write('etag: $etag, ')
          ..write('lastSuccessfulCheckAt: $lastSuccessfulCheckAt, ')
          ..write('collectionStartedAt: $collectionStartedAt, ')
          ..write('consecutiveFailures: $consecutiveFailures, ')
          ..write('lastUnavailabilityWarningAt: $lastUnavailabilityWarningAt, ')
          ..write('generation: $generation, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverUrlOverride,
    permissionGranted,
    attemptMonitoringEnabled,
    lastEncryptedBackupAt,
    lastVerifiedEncryptedBackupAt,
    etag,
    lastSuccessfulCheckAt,
    collectionStartedAt,
    consecutiveFailures,
    lastUnavailabilityWarningAt,
    generation,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecoverbullStateData &&
          other.id == this.id &&
          other.serverUrlOverride == this.serverUrlOverride &&
          other.permissionGranted == this.permissionGranted &&
          other.attemptMonitoringEnabled == this.attemptMonitoringEnabled &&
          other.lastEncryptedBackupAt == this.lastEncryptedBackupAt &&
          other.lastVerifiedEncryptedBackupAt ==
              this.lastVerifiedEncryptedBackupAt &&
          other.etag == this.etag &&
          other.lastSuccessfulCheckAt == this.lastSuccessfulCheckAt &&
          other.collectionStartedAt == this.collectionStartedAt &&
          other.consecutiveFailures == this.consecutiveFailures &&
          other.lastUnavailabilityWarningAt ==
              this.lastUnavailabilityWarningAt &&
          other.generation == this.generation &&
          other.revision == this.revision);
}

class RecoverbullStateCompanion extends UpdateCompanion<RecoverbullStateData> {
  final Value<int> id;
  final Value<String?> serverUrlOverride;
  final Value<bool> permissionGranted;
  final Value<bool> attemptMonitoringEnabled;
  final Value<DateTime?> lastEncryptedBackupAt;
  final Value<DateTime?> lastVerifiedEncryptedBackupAt;
  final Value<String?> etag;
  final Value<DateTime?> lastSuccessfulCheckAt;
  final Value<DateTime?> collectionStartedAt;
  final Value<int> consecutiveFailures;
  final Value<DateTime?> lastUnavailabilityWarningAt;
  final Value<int> generation;
  final Value<int> revision;
  const RecoverbullStateCompanion({
    this.id = const Value.absent(),
    this.serverUrlOverride = const Value.absent(),
    this.permissionGranted = const Value.absent(),
    this.attemptMonitoringEnabled = const Value.absent(),
    this.lastEncryptedBackupAt = const Value.absent(),
    this.lastVerifiedEncryptedBackupAt = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastSuccessfulCheckAt = const Value.absent(),
    this.collectionStartedAt = const Value.absent(),
    this.consecutiveFailures = const Value.absent(),
    this.lastUnavailabilityWarningAt = const Value.absent(),
    this.generation = const Value.absent(),
    this.revision = const Value.absent(),
  });
  RecoverbullStateCompanion.insert({
    this.id = const Value.absent(),
    this.serverUrlOverride = const Value.absent(),
    this.permissionGranted = const Value.absent(),
    this.attemptMonitoringEnabled = const Value.absent(),
    this.lastEncryptedBackupAt = const Value.absent(),
    this.lastVerifiedEncryptedBackupAt = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastSuccessfulCheckAt = const Value.absent(),
    this.collectionStartedAt = const Value.absent(),
    this.consecutiveFailures = const Value.absent(),
    this.lastUnavailabilityWarningAt = const Value.absent(),
    this.generation = const Value.absent(),
    this.revision = const Value.absent(),
  });
  static Insertable<RecoverbullStateData> custom({
    Expression<int>? id,
    Expression<String>? serverUrlOverride,
    Expression<bool>? permissionGranted,
    Expression<bool>? attemptMonitoringEnabled,
    Expression<DateTime>? lastEncryptedBackupAt,
    Expression<DateTime>? lastVerifiedEncryptedBackupAt,
    Expression<String>? etag,
    Expression<DateTime>? lastSuccessfulCheckAt,
    Expression<DateTime>? collectionStartedAt,
    Expression<int>? consecutiveFailures,
    Expression<DateTime>? lastUnavailabilityWarningAt,
    Expression<int>? generation,
    Expression<int>? revision,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverUrlOverride != null) 'server_url_override': serverUrlOverride,
      if (permissionGranted != null) 'permission_granted': permissionGranted,
      if (attemptMonitoringEnabled != null)
        'attempt_monitoring_enabled': attemptMonitoringEnabled,
      if (lastEncryptedBackupAt != null)
        'last_encrypted_backup_at': lastEncryptedBackupAt,
      if (lastVerifiedEncryptedBackupAt != null)
        'last_verified_encrypted_backup_at': lastVerifiedEncryptedBackupAt,
      if (etag != null) 'etag': etag,
      if (lastSuccessfulCheckAt != null)
        'last_successful_check_at': lastSuccessfulCheckAt,
      if (collectionStartedAt != null)
        'collection_started_at': collectionStartedAt,
      if (consecutiveFailures != null)
        'consecutive_failures': consecutiveFailures,
      if (lastUnavailabilityWarningAt != null)
        'last_unavailability_warning_at': lastUnavailabilityWarningAt,
      if (generation != null) 'generation': generation,
      if (revision != null) 'revision': revision,
    });
  }

  RecoverbullStateCompanion copyWith({
    Value<int>? id,
    Value<String?>? serverUrlOverride,
    Value<bool>? permissionGranted,
    Value<bool>? attemptMonitoringEnabled,
    Value<DateTime?>? lastEncryptedBackupAt,
    Value<DateTime?>? lastVerifiedEncryptedBackupAt,
    Value<String?>? etag,
    Value<DateTime?>? lastSuccessfulCheckAt,
    Value<DateTime?>? collectionStartedAt,
    Value<int>? consecutiveFailures,
    Value<DateTime?>? lastUnavailabilityWarningAt,
    Value<int>? generation,
    Value<int>? revision,
  }) {
    return RecoverbullStateCompanion(
      id: id ?? this.id,
      serverUrlOverride: serverUrlOverride ?? this.serverUrlOverride,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      attemptMonitoringEnabled:
          attemptMonitoringEnabled ?? this.attemptMonitoringEnabled,
      lastEncryptedBackupAt:
          lastEncryptedBackupAt ?? this.lastEncryptedBackupAt,
      lastVerifiedEncryptedBackupAt:
          lastVerifiedEncryptedBackupAt ?? this.lastVerifiedEncryptedBackupAt,
      etag: etag ?? this.etag,
      lastSuccessfulCheckAt:
          lastSuccessfulCheckAt ?? this.lastSuccessfulCheckAt,
      collectionStartedAt: collectionStartedAt ?? this.collectionStartedAt,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastUnavailabilityWarningAt:
          lastUnavailabilityWarningAt ?? this.lastUnavailabilityWarningAt,
      generation: generation ?? this.generation,
      revision: revision ?? this.revision,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverUrlOverride.present) {
      map['server_url_override'] = Variable<String>(serverUrlOverride.value);
    }
    if (permissionGranted.present) {
      map['permission_granted'] = Variable<bool>(permissionGranted.value);
    }
    if (attemptMonitoringEnabled.present) {
      map['attempt_monitoring_enabled'] = Variable<bool>(
        attemptMonitoringEnabled.value,
      );
    }
    if (lastEncryptedBackupAt.present) {
      map['last_encrypted_backup_at'] = Variable<DateTime>(
        lastEncryptedBackupAt.value,
      );
    }
    if (lastVerifiedEncryptedBackupAt.present) {
      map['last_verified_encrypted_backup_at'] = Variable<DateTime>(
        lastVerifiedEncryptedBackupAt.value,
      );
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (lastSuccessfulCheckAt.present) {
      map['last_successful_check_at'] = Variable<DateTime>(
        lastSuccessfulCheckAt.value,
      );
    }
    if (collectionStartedAt.present) {
      map['collection_started_at'] = Variable<DateTime>(
        collectionStartedAt.value,
      );
    }
    if (consecutiveFailures.present) {
      map['consecutive_failures'] = Variable<int>(consecutiveFailures.value);
    }
    if (lastUnavailabilityWarningAt.present) {
      map['last_unavailability_warning_at'] = Variable<DateTime>(
        lastUnavailabilityWarningAt.value,
      );
    }
    if (generation.present) {
      map['generation'] = Variable<int>(generation.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecoverbullStateCompanion(')
          ..write('id: $id, ')
          ..write('serverUrlOverride: $serverUrlOverride, ')
          ..write('permissionGranted: $permissionGranted, ')
          ..write('attemptMonitoringEnabled: $attemptMonitoringEnabled, ')
          ..write('lastEncryptedBackupAt: $lastEncryptedBackupAt, ')
          ..write(
            'lastVerifiedEncryptedBackupAt: $lastVerifiedEncryptedBackupAt, ',
          )
          ..write('etag: $etag, ')
          ..write('lastSuccessfulCheckAt: $lastSuccessfulCheckAt, ')
          ..write('collectionStartedAt: $collectionStartedAt, ')
          ..write('consecutiveFailures: $consecutiveFailures, ')
          ..write('lastUnavailabilityWarningAt: $lastUnavailabilityWarningAt, ')
          ..write('generation: $generation, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }
}

class $RecoverbullMonitoredBackupTable extends RecoverbullMonitoredBackup
    with
        TableInfo<
          $RecoverbullMonitoredBackupTable,
          RecoverbullMonitoredBackupData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecoverbullMonitoredBackupTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _digestMeta = const VerificationMeta('digest');
  @override
  late final GeneratedColumn<Uint8List> digest = GeneratedColumn<Uint8List>(
    'digest',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(digest) = 32)',
  );
  static const VerificationMeta _expectedServerDistinctCandidateTotalMeta =
      const VerificationMeta('expectedServerDistinctCandidateTotal');
  @override
  late final GeneratedColumn<int> expectedServerDistinctCandidateTotal =
      GeneratedColumn<int>(
        'expected_server_distinct_candidate_total',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _currentWindowMeta = const VerificationMeta(
    'currentWindow',
  );
  @override
  late final GeneratedColumn<int> currentWindow = GeneratedColumn<int>(
    'current_window',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastWarningWindowMeta = const VerificationMeta(
    'lastWarningWindow',
  );
  @override
  late final GeneratedColumn<int> lastWarningWindow = GeneratedColumn<int>(
    'last_warning_window',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rowRevisionMeta = const VerificationMeta(
    'rowRevision',
  );
  @override
  late final GeneratedColumn<int> rowRevision = GeneratedColumn<int>(
    'row_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    digest,
    expectedServerDistinctCandidateTotal,
    currentWindow,
    lastWarningWindow,
    rowRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recoverbull_monitored_backup';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecoverbullMonitoredBackupData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('digest')) {
      context.handle(
        _digestMeta,
        digest.isAcceptableOrUnknown(data['digest']!, _digestMeta),
      );
    } else if (isInserting) {
      context.missing(_digestMeta);
    }
    if (data.containsKey('expected_server_distinct_candidate_total')) {
      context.handle(
        _expectedServerDistinctCandidateTotalMeta,
        expectedServerDistinctCandidateTotal.isAcceptableOrUnknown(
          data['expected_server_distinct_candidate_total']!,
          _expectedServerDistinctCandidateTotalMeta,
        ),
      );
    }
    if (data.containsKey('current_window')) {
      context.handle(
        _currentWindowMeta,
        currentWindow.isAcceptableOrUnknown(
          data['current_window']!,
          _currentWindowMeta,
        ),
      );
    }
    if (data.containsKey('last_warning_window')) {
      context.handle(
        _lastWarningWindowMeta,
        lastWarningWindow.isAcceptableOrUnknown(
          data['last_warning_window']!,
          _lastWarningWindowMeta,
        ),
      );
    }
    if (data.containsKey('row_revision')) {
      context.handle(
        _rowRevisionMeta,
        rowRevision.isAcceptableOrUnknown(
          data['row_revision']!,
          _rowRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {digest};
  @override
  RecoverbullMonitoredBackupData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecoverbullMonitoredBackupData(
      digest: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}digest'],
      )!,
      expectedServerDistinctCandidateTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_server_distinct_candidate_total'],
      )!,
      currentWindow: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_window'],
      )!,
      lastWarningWindow: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_warning_window'],
      ),
      rowRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_revision'],
      )!,
    );
  }

  @override
  $RecoverbullMonitoredBackupTable createAlias(String alias) {
    return $RecoverbullMonitoredBackupTable(attachedDatabase, alias);
  }
}

class RecoverbullMonitoredBackupData extends DataClass
    implements Insertable<RecoverbullMonitoredBackupData> {
  final Uint8List digest;
  final int expectedServerDistinctCandidateTotal;
  final int currentWindow;
  final int? lastWarningWindow;
  final int rowRevision;
  const RecoverbullMonitoredBackupData({
    required this.digest,
    required this.expectedServerDistinctCandidateTotal,
    required this.currentWindow,
    this.lastWarningWindow,
    required this.rowRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['digest'] = Variable<Uint8List>(digest);
    map['expected_server_distinct_candidate_total'] = Variable<int>(
      expectedServerDistinctCandidateTotal,
    );
    map['current_window'] = Variable<int>(currentWindow);
    if (!nullToAbsent || lastWarningWindow != null) {
      map['last_warning_window'] = Variable<int>(lastWarningWindow);
    }
    map['row_revision'] = Variable<int>(rowRevision);
    return map;
  }

  RecoverbullMonitoredBackupCompanion toCompanion(bool nullToAbsent) {
    return RecoverbullMonitoredBackupCompanion(
      digest: Value(digest),
      expectedServerDistinctCandidateTotal: Value(
        expectedServerDistinctCandidateTotal,
      ),
      currentWindow: Value(currentWindow),
      lastWarningWindow: lastWarningWindow == null && nullToAbsent
          ? const Value.absent()
          : Value(lastWarningWindow),
      rowRevision: Value(rowRevision),
    );
  }

  factory RecoverbullMonitoredBackupData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecoverbullMonitoredBackupData(
      digest: serializer.fromJson<Uint8List>(json['digest']),
      expectedServerDistinctCandidateTotal: serializer.fromJson<int>(
        json['expectedServerDistinctCandidateTotal'],
      ),
      currentWindow: serializer.fromJson<int>(json['currentWindow']),
      lastWarningWindow: serializer.fromJson<int?>(json['lastWarningWindow']),
      rowRevision: serializer.fromJson<int>(json['rowRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'digest': serializer.toJson<Uint8List>(digest),
      'expectedServerDistinctCandidateTotal': serializer.toJson<int>(
        expectedServerDistinctCandidateTotal,
      ),
      'currentWindow': serializer.toJson<int>(currentWindow),
      'lastWarningWindow': serializer.toJson<int?>(lastWarningWindow),
      'rowRevision': serializer.toJson<int>(rowRevision),
    };
  }

  RecoverbullMonitoredBackupData copyWith({
    Uint8List? digest,
    int? expectedServerDistinctCandidateTotal,
    int? currentWindow,
    Value<int?> lastWarningWindow = const Value.absent(),
    int? rowRevision,
  }) => RecoverbullMonitoredBackupData(
    digest: digest ?? this.digest,
    expectedServerDistinctCandidateTotal:
        expectedServerDistinctCandidateTotal ??
        this.expectedServerDistinctCandidateTotal,
    currentWindow: currentWindow ?? this.currentWindow,
    lastWarningWindow: lastWarningWindow.present
        ? lastWarningWindow.value
        : this.lastWarningWindow,
    rowRevision: rowRevision ?? this.rowRevision,
  );
  RecoverbullMonitoredBackupData copyWithCompanion(
    RecoverbullMonitoredBackupCompanion data,
  ) {
    return RecoverbullMonitoredBackupData(
      digest: data.digest.present ? data.digest.value : this.digest,
      expectedServerDistinctCandidateTotal:
          data.expectedServerDistinctCandidateTotal.present
          ? data.expectedServerDistinctCandidateTotal.value
          : this.expectedServerDistinctCandidateTotal,
      currentWindow: data.currentWindow.present
          ? data.currentWindow.value
          : this.currentWindow,
      lastWarningWindow: data.lastWarningWindow.present
          ? data.lastWarningWindow.value
          : this.lastWarningWindow,
      rowRevision: data.rowRevision.present
          ? data.rowRevision.value
          : this.rowRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecoverbullMonitoredBackupData(')
          ..write('digest: $digest, ')
          ..write(
            'expectedServerDistinctCandidateTotal: $expectedServerDistinctCandidateTotal, ',
          )
          ..write('currentWindow: $currentWindow, ')
          ..write('lastWarningWindow: $lastWarningWindow, ')
          ..write('rowRevision: $rowRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(digest),
    expectedServerDistinctCandidateTotal,
    currentWindow,
    lastWarningWindow,
    rowRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecoverbullMonitoredBackupData &&
          $driftBlobEquality.equals(other.digest, this.digest) &&
          other.expectedServerDistinctCandidateTotal ==
              this.expectedServerDistinctCandidateTotal &&
          other.currentWindow == this.currentWindow &&
          other.lastWarningWindow == this.lastWarningWindow &&
          other.rowRevision == this.rowRevision);
}

class RecoverbullMonitoredBackupCompanion
    extends UpdateCompanion<RecoverbullMonitoredBackupData> {
  final Value<Uint8List> digest;
  final Value<int> expectedServerDistinctCandidateTotal;
  final Value<int> currentWindow;
  final Value<int?> lastWarningWindow;
  final Value<int> rowRevision;
  final Value<int> rowid;
  const RecoverbullMonitoredBackupCompanion({
    this.digest = const Value.absent(),
    this.expectedServerDistinctCandidateTotal = const Value.absent(),
    this.currentWindow = const Value.absent(),
    this.lastWarningWindow = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecoverbullMonitoredBackupCompanion.insert({
    required Uint8List digest,
    this.expectedServerDistinctCandidateTotal = const Value.absent(),
    this.currentWindow = const Value.absent(),
    this.lastWarningWindow = const Value.absent(),
    this.rowRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : digest = Value(digest);
  static Insertable<RecoverbullMonitoredBackupData> custom({
    Expression<Uint8List>? digest,
    Expression<int>? expectedServerDistinctCandidateTotal,
    Expression<int>? currentWindow,
    Expression<int>? lastWarningWindow,
    Expression<int>? rowRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (digest != null) 'digest': digest,
      if (expectedServerDistinctCandidateTotal != null)
        'expected_server_distinct_candidate_total':
            expectedServerDistinctCandidateTotal,
      if (currentWindow != null) 'current_window': currentWindow,
      if (lastWarningWindow != null) 'last_warning_window': lastWarningWindow,
      if (rowRevision != null) 'row_revision': rowRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecoverbullMonitoredBackupCompanion copyWith({
    Value<Uint8List>? digest,
    Value<int>? expectedServerDistinctCandidateTotal,
    Value<int>? currentWindow,
    Value<int?>? lastWarningWindow,
    Value<int>? rowRevision,
    Value<int>? rowid,
  }) {
    return RecoverbullMonitoredBackupCompanion(
      digest: digest ?? this.digest,
      expectedServerDistinctCandidateTotal:
          expectedServerDistinctCandidateTotal ??
          this.expectedServerDistinctCandidateTotal,
      currentWindow: currentWindow ?? this.currentWindow,
      lastWarningWindow: lastWarningWindow ?? this.lastWarningWindow,
      rowRevision: rowRevision ?? this.rowRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (digest.present) {
      map['digest'] = Variable<Uint8List>(digest.value);
    }
    if (expectedServerDistinctCandidateTotal.present) {
      map['expected_server_distinct_candidate_total'] = Variable<int>(
        expectedServerDistinctCandidateTotal.value,
      );
    }
    if (currentWindow.present) {
      map['current_window'] = Variable<int>(currentWindow.value);
    }
    if (lastWarningWindow.present) {
      map['last_warning_window'] = Variable<int>(lastWarningWindow.value);
    }
    if (rowRevision.present) {
      map['row_revision'] = Variable<int>(rowRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecoverbullMonitoredBackupCompanion(')
          ..write('digest: $digest, ')
          ..write(
            'expectedServerDistinctCandidateTotal: $expectedServerDistinctCandidateTotal, ',
          )
          ..write('currentWindow: $currentWindow, ')
          ..write('lastWarningWindow: $lastWarningWindow, ')
          ..write('rowRevision: $rowRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$RecoverBullDatabase extends GeneratedDatabase {
  _$RecoverBullDatabase(QueryExecutor e) : super(e);
  $RecoverBullDatabaseManager get managers => $RecoverBullDatabaseManager(this);
  late final $RecoverbullStateTable recoverbullState = $RecoverbullStateTable(
    this,
  );
  late final $RecoverbullMonitoredBackupTable recoverbullMonitoredBackup =
      $RecoverbullMonitoredBackupTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    recoverbullState,
    recoverbullMonitoredBackup,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$RecoverbullStateTableCreateCompanionBuilder =
    RecoverbullStateCompanion Function({
      Value<int> id,
      Value<String?> serverUrlOverride,
      Value<bool> permissionGranted,
      Value<bool> attemptMonitoringEnabled,
      Value<DateTime?> lastEncryptedBackupAt,
      Value<DateTime?> lastVerifiedEncryptedBackupAt,
      Value<String?> etag,
      Value<DateTime?> lastSuccessfulCheckAt,
      Value<DateTime?> collectionStartedAt,
      Value<int> consecutiveFailures,
      Value<DateTime?> lastUnavailabilityWarningAt,
      Value<int> generation,
      Value<int> revision,
    });
typedef $$RecoverbullStateTableUpdateCompanionBuilder =
    RecoverbullStateCompanion Function({
      Value<int> id,
      Value<String?> serverUrlOverride,
      Value<bool> permissionGranted,
      Value<bool> attemptMonitoringEnabled,
      Value<DateTime?> lastEncryptedBackupAt,
      Value<DateTime?> lastVerifiedEncryptedBackupAt,
      Value<String?> etag,
      Value<DateTime?> lastSuccessfulCheckAt,
      Value<DateTime?> collectionStartedAt,
      Value<int> consecutiveFailures,
      Value<DateTime?> lastUnavailabilityWarningAt,
      Value<int> generation,
      Value<int> revision,
    });

class $$RecoverbullStateTableFilterComposer
    extends Composer<_$RecoverBullDatabase, $RecoverbullStateTable> {
  $$RecoverbullStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverUrlOverride => $composableBuilder(
    column: $table.serverUrlOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get permissionGranted => $composableBuilder(
    column: $table.permissionGranted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get attemptMonitoringEnabled => $composableBuilder(
    column: $table.attemptMonitoringEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastEncryptedBackupAt => $composableBuilder(
    column: $table.lastEncryptedBackupAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastVerifiedEncryptedBackupAt =>
      $composableBuilder(
        column: $table.lastVerifiedEncryptedBackupAt,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSuccessfulCheckAt => $composableBuilder(
    column: $table.lastSuccessfulCheckAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get collectionStartedAt => $composableBuilder(
    column: $table.collectionStartedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUnavailabilityWarningAt => $composableBuilder(
    column: $table.lastUnavailabilityWarningAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecoverbullStateTableOrderingComposer
    extends Composer<_$RecoverBullDatabase, $RecoverbullStateTable> {
  $$RecoverbullStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverUrlOverride => $composableBuilder(
    column: $table.serverUrlOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get permissionGranted => $composableBuilder(
    column: $table.permissionGranted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get attemptMonitoringEnabled => $composableBuilder(
    column: $table.attemptMonitoringEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastEncryptedBackupAt => $composableBuilder(
    column: $table.lastEncryptedBackupAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastVerifiedEncryptedBackupAt =>
      $composableBuilder(
        column: $table.lastVerifiedEncryptedBackupAt,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSuccessfulCheckAt => $composableBuilder(
    column: $table.lastSuccessfulCheckAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get collectionStartedAt => $composableBuilder(
    column: $table.collectionStartedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUnavailabilityWarningAt =>
      $composableBuilder(
        column: $table.lastUnavailabilityWarningAt,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecoverbullStateTableAnnotationComposer
    extends Composer<_$RecoverBullDatabase, $RecoverbullStateTable> {
  $$RecoverbullStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverUrlOverride => $composableBuilder(
    column: $table.serverUrlOverride,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get permissionGranted => $composableBuilder(
    column: $table.permissionGranted,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get attemptMonitoringEnabled => $composableBuilder(
    column: $table.attemptMonitoringEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastEncryptedBackupAt => $composableBuilder(
    column: $table.lastEncryptedBackupAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastVerifiedEncryptedBackupAt =>
      $composableBuilder(
        column: $table.lastVerifiedEncryptedBackupAt,
        builder: (column) => column,
      );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSuccessfulCheckAt => $composableBuilder(
    column: $table.lastSuccessfulCheckAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get collectionStartedAt => $composableBuilder(
    column: $table.collectionStartedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUnavailabilityWarningAt =>
      $composableBuilder(
        column: $table.lastUnavailabilityWarningAt,
        builder: (column) => column,
      );

  GeneratedColumn<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$RecoverbullStateTableTableManager
    extends
        RootTableManager<
          _$RecoverBullDatabase,
          $RecoverbullStateTable,
          RecoverbullStateData,
          $$RecoverbullStateTableFilterComposer,
          $$RecoverbullStateTableOrderingComposer,
          $$RecoverbullStateTableAnnotationComposer,
          $$RecoverbullStateTableCreateCompanionBuilder,
          $$RecoverbullStateTableUpdateCompanionBuilder,
          (
            RecoverbullStateData,
            BaseReferences<
              _$RecoverBullDatabase,
              $RecoverbullStateTable,
              RecoverbullStateData
            >,
          ),
          RecoverbullStateData,
          PrefetchHooks Function()
        > {
  $$RecoverbullStateTableTableManager(
    _$RecoverBullDatabase db,
    $RecoverbullStateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecoverbullStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecoverbullStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecoverbullStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serverUrlOverride = const Value.absent(),
                Value<bool> permissionGranted = const Value.absent(),
                Value<bool> attemptMonitoringEnabled = const Value.absent(),
                Value<DateTime?> lastEncryptedBackupAt = const Value.absent(),
                Value<DateTime?> lastVerifiedEncryptedBackupAt =
                    const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime?> lastSuccessfulCheckAt = const Value.absent(),
                Value<DateTime?> collectionStartedAt = const Value.absent(),
                Value<int> consecutiveFailures = const Value.absent(),
                Value<DateTime?> lastUnavailabilityWarningAt =
                    const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<int> revision = const Value.absent(),
              }) => RecoverbullStateCompanion(
                id: id,
                serverUrlOverride: serverUrlOverride,
                permissionGranted: permissionGranted,
                attemptMonitoringEnabled: attemptMonitoringEnabled,
                lastEncryptedBackupAt: lastEncryptedBackupAt,
                lastVerifiedEncryptedBackupAt: lastVerifiedEncryptedBackupAt,
                etag: etag,
                lastSuccessfulCheckAt: lastSuccessfulCheckAt,
                collectionStartedAt: collectionStartedAt,
                consecutiveFailures: consecutiveFailures,
                lastUnavailabilityWarningAt: lastUnavailabilityWarningAt,
                generation: generation,
                revision: revision,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> serverUrlOverride = const Value.absent(),
                Value<bool> permissionGranted = const Value.absent(),
                Value<bool> attemptMonitoringEnabled = const Value.absent(),
                Value<DateTime?> lastEncryptedBackupAt = const Value.absent(),
                Value<DateTime?> lastVerifiedEncryptedBackupAt =
                    const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime?> lastSuccessfulCheckAt = const Value.absent(),
                Value<DateTime?> collectionStartedAt = const Value.absent(),
                Value<int> consecutiveFailures = const Value.absent(),
                Value<DateTime?> lastUnavailabilityWarningAt =
                    const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<int> revision = const Value.absent(),
              }) => RecoverbullStateCompanion.insert(
                id: id,
                serverUrlOverride: serverUrlOverride,
                permissionGranted: permissionGranted,
                attemptMonitoringEnabled: attemptMonitoringEnabled,
                lastEncryptedBackupAt: lastEncryptedBackupAt,
                lastVerifiedEncryptedBackupAt: lastVerifiedEncryptedBackupAt,
                etag: etag,
                lastSuccessfulCheckAt: lastSuccessfulCheckAt,
                collectionStartedAt: collectionStartedAt,
                consecutiveFailures: consecutiveFailures,
                lastUnavailabilityWarningAt: lastUnavailabilityWarningAt,
                generation: generation,
                revision: revision,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecoverbullStateTableProcessedTableManager =
    ProcessedTableManager<
      _$RecoverBullDatabase,
      $RecoverbullStateTable,
      RecoverbullStateData,
      $$RecoverbullStateTableFilterComposer,
      $$RecoverbullStateTableOrderingComposer,
      $$RecoverbullStateTableAnnotationComposer,
      $$RecoverbullStateTableCreateCompanionBuilder,
      $$RecoverbullStateTableUpdateCompanionBuilder,
      (
        RecoverbullStateData,
        BaseReferences<
          _$RecoverBullDatabase,
          $RecoverbullStateTable,
          RecoverbullStateData
        >,
      ),
      RecoverbullStateData,
      PrefetchHooks Function()
    >;
typedef $$RecoverbullMonitoredBackupTableCreateCompanionBuilder =
    RecoverbullMonitoredBackupCompanion Function({
      required Uint8List digest,
      Value<int> expectedServerDistinctCandidateTotal,
      Value<int> currentWindow,
      Value<int?> lastWarningWindow,
      Value<int> rowRevision,
      Value<int> rowid,
    });
typedef $$RecoverbullMonitoredBackupTableUpdateCompanionBuilder =
    RecoverbullMonitoredBackupCompanion Function({
      Value<Uint8List> digest,
      Value<int> expectedServerDistinctCandidateTotal,
      Value<int> currentWindow,
      Value<int?> lastWarningWindow,
      Value<int> rowRevision,
      Value<int> rowid,
    });

class $$RecoverbullMonitoredBackupTableFilterComposer
    extends Composer<_$RecoverBullDatabase, $RecoverbullMonitoredBackupTable> {
  $$RecoverbullMonitoredBackupTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get digest => $composableBuilder(
    column: $table.digest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedServerDistinctCandidateTotal =>
      $composableBuilder(
        column: $table.expectedServerDistinctCandidateTotal,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<int> get currentWindow => $composableBuilder(
    column: $table.currentWindow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastWarningWindow => $composableBuilder(
    column: $table.lastWarningWindow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecoverbullMonitoredBackupTableOrderingComposer
    extends Composer<_$RecoverBullDatabase, $RecoverbullMonitoredBackupTable> {
  $$RecoverbullMonitoredBackupTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get digest => $composableBuilder(
    column: $table.digest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedServerDistinctCandidateTotal =>
      $composableBuilder(
        column: $table.expectedServerDistinctCandidateTotal,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<int> get currentWindow => $composableBuilder(
    column: $table.currentWindow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastWarningWindow => $composableBuilder(
    column: $table.lastWarningWindow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecoverbullMonitoredBackupTableAnnotationComposer
    extends Composer<_$RecoverBullDatabase, $RecoverbullMonitoredBackupTable> {
  $$RecoverbullMonitoredBackupTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get digest =>
      $composableBuilder(column: $table.digest, builder: (column) => column);

  GeneratedColumn<int> get expectedServerDistinctCandidateTotal =>
      $composableBuilder(
        column: $table.expectedServerDistinctCandidateTotal,
        builder: (column) => column,
      );

  GeneratedColumn<int> get currentWindow => $composableBuilder(
    column: $table.currentWindow,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastWarningWindow => $composableBuilder(
    column: $table.lastWarningWindow,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rowRevision => $composableBuilder(
    column: $table.rowRevision,
    builder: (column) => column,
  );
}

class $$RecoverbullMonitoredBackupTableTableManager
    extends
        RootTableManager<
          _$RecoverBullDatabase,
          $RecoverbullMonitoredBackupTable,
          RecoverbullMonitoredBackupData,
          $$RecoverbullMonitoredBackupTableFilterComposer,
          $$RecoverbullMonitoredBackupTableOrderingComposer,
          $$RecoverbullMonitoredBackupTableAnnotationComposer,
          $$RecoverbullMonitoredBackupTableCreateCompanionBuilder,
          $$RecoverbullMonitoredBackupTableUpdateCompanionBuilder,
          (
            RecoverbullMonitoredBackupData,
            BaseReferences<
              _$RecoverBullDatabase,
              $RecoverbullMonitoredBackupTable,
              RecoverbullMonitoredBackupData
            >,
          ),
          RecoverbullMonitoredBackupData,
          PrefetchHooks Function()
        > {
  $$RecoverbullMonitoredBackupTableTableManager(
    _$RecoverBullDatabase db,
    $RecoverbullMonitoredBackupTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecoverbullMonitoredBackupTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RecoverbullMonitoredBackupTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RecoverbullMonitoredBackupTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<Uint8List> digest = const Value.absent(),
                Value<int> expectedServerDistinctCandidateTotal =
                    const Value.absent(),
                Value<int> currentWindow = const Value.absent(),
                Value<int?> lastWarningWindow = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecoverbullMonitoredBackupCompanion(
                digest: digest,
                expectedServerDistinctCandidateTotal:
                    expectedServerDistinctCandidateTotal,
                currentWindow: currentWindow,
                lastWarningWindow: lastWarningWindow,
                rowRevision: rowRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required Uint8List digest,
                Value<int> expectedServerDistinctCandidateTotal =
                    const Value.absent(),
                Value<int> currentWindow = const Value.absent(),
                Value<int?> lastWarningWindow = const Value.absent(),
                Value<int> rowRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecoverbullMonitoredBackupCompanion.insert(
                digest: digest,
                expectedServerDistinctCandidateTotal:
                    expectedServerDistinctCandidateTotal,
                currentWindow: currentWindow,
                lastWarningWindow: lastWarningWindow,
                rowRevision: rowRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecoverbullMonitoredBackupTableProcessedTableManager =
    ProcessedTableManager<
      _$RecoverBullDatabase,
      $RecoverbullMonitoredBackupTable,
      RecoverbullMonitoredBackupData,
      $$RecoverbullMonitoredBackupTableFilterComposer,
      $$RecoverbullMonitoredBackupTableOrderingComposer,
      $$RecoverbullMonitoredBackupTableAnnotationComposer,
      $$RecoverbullMonitoredBackupTableCreateCompanionBuilder,
      $$RecoverbullMonitoredBackupTableUpdateCompanionBuilder,
      (
        RecoverbullMonitoredBackupData,
        BaseReferences<
          _$RecoverBullDatabase,
          $RecoverbullMonitoredBackupTable,
          RecoverbullMonitoredBackupData
        >,
      ),
      RecoverbullMonitoredBackupData,
      PrefetchHooks Function()
    >;

class $RecoverBullDatabaseManager {
  final _$RecoverBullDatabase _db;
  $RecoverBullDatabaseManager(this._db);
  $$RecoverbullStateTableTableManager get recoverbullState =>
      $$RecoverbullStateTableTableManager(_db, _db.recoverbullState);
  $$RecoverbullMonitoredBackupTableTableManager
  get recoverbullMonitoredBackup =>
      $$RecoverbullMonitoredBackupTableTableManager(
        _db,
        _db.recoverbullMonitoredBackup,
      );
}
