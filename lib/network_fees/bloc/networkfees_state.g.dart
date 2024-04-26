// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'networkfees_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NetworkFeesStateImpl _$$NetworkFeesStateImplFromJson(
        Map<String, dynamic> json) =>
    _$NetworkFeesStateImpl(
      fees: json['fees'] as int?,
      feesList:
          (json['feesList'] as List<dynamic>?)?.map((e) => e as int).toList(),
      selectedFeesOption: json['selectedFeesOption'] as int? ?? 2,
      tempFees: json['tempFees'] as int?,
      tempSelectedFeesOption: json['tempSelectedFeesOption'] as int?,
      feesSaved: json['feesSaved'] as bool? ?? false,
      loadingFees: json['loadingFees'] as bool? ?? false,
      errLoadingFees: json['errLoadingFees'] as String? ?? '',
    );

Map<String, dynamic> _$$NetworkFeesStateImplToJson(
        _$NetworkFeesStateImpl instance) =>
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
