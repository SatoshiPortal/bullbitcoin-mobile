import 'dart:collection';
import 'dart:convert';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_descriptor_service.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';

final class BullVaultRecoveryPackageCodec {
  static const schemaVersion = 1;
  static const _fields = {
    'birthHeight',
    'createdAt',
    'descriptor',
    'lineageId',
    'network',
    'policyVersion',
    'previousVaultId',
    'schedule',
    'schemaVersion',
  };

  final BullVaultDescriptorService _descriptorService;

  const BullVaultRecoveryPackageCodec(this._descriptorService);

  BullVaultRecoveryPackage decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic> ||
          decoded.keys.any((field) => !_fields.contains(field)) ||
          decoded['schemaVersion'] != schemaVersion ||
          decoded['policyVersion'] != BullVaultPolicy.schemaVersion) {
        throw const FormatException('Unsupported BullVault recovery version');
      }
      final network = Network.values.byName(decoded['network'] as String);
      final recognized = _descriptorService.recognizeStructure(
        decoded['descriptor'] as String,
        network,
      );
      if (recognized == null) {
        throw const FormatException('Unsupported BullVault descriptor');
      }
      final createdAt = switch (decoded['createdAt']) {
        final String value => DateTime.parse(value).toUtc(),
        null => null,
        _ => throw const FormatException('Invalid BullVault creation date'),
      };
      final birthHeight = decoded['birthHeight'] as int?;
      final lineageId = decoded['lineageId'] as String;
      final previousVaultId = decoded['previousVaultId'] as String?;
      if (lineageId.isEmpty ||
          (previousVaultId != null && previousVaultId.isEmpty)) {
        throw const FormatException('Invalid BullVault lineage');
      }
      final schedule = _decodeSchedule(
        decoded['schedule'],
        protection: recognized.protection,
        includesInheritance: recognized.inheritanceKey != null,
      );
      final policy = BullVaultPolicy.restoreRecoveryPackage(
        recognizedPolicy: recognized,
        lineageId: lineageId,
        schedule: schedule,
        birthHeight: birthHeight,
        createdAt: createdAt,
      );
      if ((policy.vaultGeneration == 0 && previousVaultId != null) ||
          (policy.vaultGeneration > 0 &&
              policy.hasKnownOriginalSchedule &&
              previousVaultId == null)) {
        throw const FormatException('Invalid BullVault predecessor');
      }
      return BullVaultRecoveryPackage(
        previousVaultId: previousVaultId,
        policy: policy,
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid BullVault recovery package', error);
    }
  }

  String encode(BullVaultRecoveryPackage package) {
    final policy = package.policy;
    final schedule = policy.schedule;
    return const JsonEncoder.withIndent('  ').convert(
      SplayTreeMap<String, Object?>.from({
        if (policy.birthHeight != null) 'birthHeight': policy.birthHeight,
        if (policy.createdAt != null)
          'createdAt': policy.createdAt!.toIso8601String(),
        'descriptor': policy.descriptor,
        'lineageId': policy.lineageId,
        'network': policy.network.name,
        'policyVersion': BullVaultPolicy.schemaVersion,
        if (package.previousVaultId != null)
          'previousVaultId': package.previousVaultId,
        if (schedule != null)
          'schedule': _encodeSchedule(
            schedule,
            protection: policy.protection,
            includesInheritance: policy.inheritanceKey != null,
          ),
        'schemaVersion': schemaVersion,
      }),
    );
  }

  static BullVaultSchedule? _decodeSchedule(
    Object? value, {
    required BullVaultProtection protection,
    required bool includesInheritance,
  }) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid BullVault schedule metadata');
    }
    final expectedFields = _scheduleFields(
      protection: protection,
      includesInheritance: includesInheritance,
    );
    if (value.keys.toSet().difference({...expectedFields, 'unit'}).isNotEmpty ||
        {...expectedFields, 'unit'}.difference(value.keys.toSet()).isNotEmpty ||
        expectedFields.any((field) => value[field] is! int) ||
        value['unit'] is! String) {
      throw const FormatException('Invalid BullVault schedule metadata');
    }
    final unit = BullVaultScheduleUnit.values.byName(value['unit'] as String);
    final defaults = BullVaultSchedule.defaultsFor(
      protection: protection,
      includesInheritance: includesInheritance,
      unit: unit,
    );
    return defaults.copyWith(
      coldDelay: value['cold'] as int?,
      recoveryDelay: value['recovery'] as int?,
      inheritanceDelay: value['inheritance'] as int?,
    );
  }

  static Map<String, Object> _encodeSchedule(
    BullVaultSchedule schedule, {
    required BullVaultProtection protection,
    required bool includesInheritance,
  }) => {
    'unit': schedule.unit.name,
    if (_scheduleFields(
      protection: protection,
      includesInheritance: includesInheritance,
    ).contains('cold'))
      'cold': schedule.coldDelay,
    'recovery': schedule.recoveryDelay,
    if (includesInheritance) 'inheritance': schedule.inheritanceDelay,
  };

  static Set<String> _scheduleFields({
    required BullVaultProtection protection,
    required bool includesInheritance,
  }) => {
    if (protection == BullVaultProtection.standard || !includesInheritance)
      'cold',
    'recovery',
    if (includesInheritance) 'inheritance',
  };
}
