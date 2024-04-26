// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'networkfees_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NetworkFeesStateImpl _$$NetworkFeesStateImplFromJson(
        Map<String, dynamic> json) =>
    _$NetworkFeesStateImpl(
      fees: (json['fees'] as num?)?.toInt(),
      feesList: (json['feesList'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      selectedFeesOption: (json['selectedFeesOption'] as num?)?.toInt() ?? 2,
      tempFees: (json['tempFees'] as num?)?.toInt(),
      tempSelectedFeesOption: (json['tempSelectedFeesOption'] as num?)?.toInt(),
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
