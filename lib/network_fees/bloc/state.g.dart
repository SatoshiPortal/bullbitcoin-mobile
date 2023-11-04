// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_NetworkFeesState _$$_NetworkFeesStateFromJson(Map<String, dynamic> json) =>
    _$_NetworkFeesState(
      fees: json['fees'] as int? ?? 0,
      feesList:
          (json['feesList'] as List<dynamic>?)?.map((e) => e as int).toList() ??
              const [],
      selectedFeesOption: json['selectedFeesOption'] as int? ?? 2,
      tempFees: json['tempFees'] as int? ?? 0,
      tempSelectedFeesOption: json['tempSelectedFeesOption'] as int? ?? 2,
      feesSaved: json['feesSaved'] as bool? ?? false,
      loadingFees: json['loadingFees'] as bool? ?? false,
      errLoadingFees: json['errLoadingFees'] as String? ?? '',
    );

Map<String, dynamic> _$$_NetworkFeesStateToJson(_$_NetworkFeesState instance) =>
    <String, dynamic>{
      'fees': instance.fees,
      'feesList': instance.feesList,
      'selectedFeesOption': instance.selectedFeesOption,
      'tempFees': instance.tempFees,
      'tempSelectedFeesOption': instance.tempSelectedFeesOption,
      'feesSaved': instance.feesSaved,
      'loadingFees': instance.loadingFees,
      'errLoadingFees': instance.errLoadingFees,
    };
