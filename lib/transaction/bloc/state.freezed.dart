// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TransactionState {
  Transaction get tx => throw _privateConstructorUsedError;
  bool get loadingAddresses => throw _privateConstructorUsedError;
  String get errLoadingAddresses => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  bool get savingLabel => throw _privateConstructorUsedError;
  String get errSavingLabel => throw _privateConstructorUsedError; //
  Transaction? get updatedTx =>
      throw _privateConstructorUsedError; // int? feeRate,
  bool get buildingTx => throw _privateConstructorUsedError;
  String get errBuildingTx => throw _privateConstructorUsedError;
  bool get sendingTx => throw _privateConstructorUsedError;
  String get errSendingTx => throw _privateConstructorUsedError;
  bool get sentTx => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $TransactionStateCopyWith<TransactionState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransactionStateCopyWith<$Res> {
  factory $TransactionStateCopyWith(
          TransactionState value, $Res Function(TransactionState) then) =
      _$TransactionStateCopyWithImpl<$Res, TransactionState>;
  @useResult
  $Res call(
      {Transaction tx,
      bool loadingAddresses,
      String errLoadingAddresses,
      String label,
      bool savingLabel,
      String errSavingLabel,
      Transaction? updatedTx,
      bool buildingTx,
      String errBuildingTx,
      bool sendingTx,
      String errSendingTx,
      bool sentTx});

  $TransactionCopyWith<$Res> get tx;
  $TransactionCopyWith<$Res>? get updatedTx;
}

/// @nodoc
class _$TransactionStateCopyWithImpl<$Res, $Val extends TransactionState>
    implements $TransactionStateCopyWith<$Res> {
  _$TransactionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tx = null,
    Object? loadingAddresses = null,
    Object? errLoadingAddresses = null,
    Object? label = null,
    Object? savingLabel = null,
    Object? errSavingLabel = null,
    Object? updatedTx = freezed,
    Object? buildingTx = null,
    Object? errBuildingTx = null,
    Object? sendingTx = null,
    Object? errSendingTx = null,
    Object? sentTx = null,
  }) {
    return _then(_value.copyWith(
      tx: null == tx
          ? _value.tx
          : tx // ignore: cast_nullable_to_non_nullable
              as Transaction,
      loadingAddresses: null == loadingAddresses
          ? _value.loadingAddresses
          : loadingAddresses // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingAddresses: null == errLoadingAddresses
          ? _value.errLoadingAddresses
          : errLoadingAddresses // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      savingLabel: null == savingLabel
          ? _value.savingLabel
          : savingLabel // ignore: cast_nullable_to_non_nullable
              as bool,
      errSavingLabel: null == errSavingLabel
          ? _value.errSavingLabel
          : errSavingLabel // ignore: cast_nullable_to_non_nullable
              as String,
      updatedTx: freezed == updatedTx
          ? _value.updatedTx
          : updatedTx // ignore: cast_nullable_to_non_nullable
              as Transaction?,
      buildingTx: null == buildingTx
          ? _value.buildingTx
          : buildingTx // ignore: cast_nullable_to_non_nullable
              as bool,
      errBuildingTx: null == errBuildingTx
          ? _value.errBuildingTx
          : errBuildingTx // ignore: cast_nullable_to_non_nullable
              as String,
      sendingTx: null == sendingTx
          ? _value.sendingTx
          : sendingTx // ignore: cast_nullable_to_non_nullable
              as bool,
      errSendingTx: null == errSendingTx
          ? _value.errSendingTx
          : errSendingTx // ignore: cast_nullable_to_non_nullable
              as String,
      sentTx: null == sentTx
          ? _value.sentTx
          : sentTx // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $TransactionCopyWith<$Res> get tx {
    return $TransactionCopyWith<$Res>(_value.tx, (value) {
      return _then(_value.copyWith(tx: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $TransactionCopyWith<$Res>? get updatedTx {
    if (_value.updatedTx == null) {
      return null;
    }

    return $TransactionCopyWith<$Res>(_value.updatedTx!, (value) {
      return _then(_value.copyWith(updatedTx: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TransactionStateImplCopyWith<$Res>
    implements $TransactionStateCopyWith<$Res> {
  factory _$$TransactionStateImplCopyWith(_$TransactionStateImpl value,
          $Res Function(_$TransactionStateImpl) then) =
      __$$TransactionStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Transaction tx,
      bool loadingAddresses,
      String errLoadingAddresses,
      String label,
      bool savingLabel,
      String errSavingLabel,
      Transaction? updatedTx,
      bool buildingTx,
      String errBuildingTx,
      bool sendingTx,
      String errSendingTx,
      bool sentTx});

  @override
  $TransactionCopyWith<$Res> get tx;
  @override
  $TransactionCopyWith<$Res>? get updatedTx;
}

/// @nodoc
class __$$TransactionStateImplCopyWithImpl<$Res>
    extends _$TransactionStateCopyWithImpl<$Res, _$TransactionStateImpl>
    implements _$$TransactionStateImplCopyWith<$Res> {
  __$$TransactionStateImplCopyWithImpl(_$TransactionStateImpl _value,
      $Res Function(_$TransactionStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tx = null,
    Object? loadingAddresses = null,
    Object? errLoadingAddresses = null,
    Object? label = null,
    Object? savingLabel = null,
    Object? errSavingLabel = null,
    Object? updatedTx = freezed,
    Object? buildingTx = null,
    Object? errBuildingTx = null,
    Object? sendingTx = null,
    Object? errSendingTx = null,
    Object? sentTx = null,
  }) {
    return _then(_$TransactionStateImpl(
      tx: null == tx
          ? _value.tx
          : tx // ignore: cast_nullable_to_non_nullable
              as Transaction,
      loadingAddresses: null == loadingAddresses
          ? _value.loadingAddresses
          : loadingAddresses // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingAddresses: null == errLoadingAddresses
          ? _value.errLoadingAddresses
          : errLoadingAddresses // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      savingLabel: null == savingLabel
          ? _value.savingLabel
          : savingLabel // ignore: cast_nullable_to_non_nullable
              as bool,
      errSavingLabel: null == errSavingLabel
          ? _value.errSavingLabel
          : errSavingLabel // ignore: cast_nullable_to_non_nullable
              as String,
      updatedTx: freezed == updatedTx
          ? _value.updatedTx
          : updatedTx // ignore: cast_nullable_to_non_nullable
              as Transaction?,
      buildingTx: null == buildingTx
          ? _value.buildingTx
          : buildingTx // ignore: cast_nullable_to_non_nullable
              as bool,
      errBuildingTx: null == errBuildingTx
          ? _value.errBuildingTx
          : errBuildingTx // ignore: cast_nullable_to_non_nullable
              as String,
      sendingTx: null == sendingTx
          ? _value.sendingTx
          : sendingTx // ignore: cast_nullable_to_non_nullable
              as bool,
      errSendingTx: null == errSendingTx
          ? _value.errSendingTx
          : errSendingTx // ignore: cast_nullable_to_non_nullable
              as String,
      sentTx: null == sentTx
          ? _value.sentTx
          : sentTx // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$TransactionStateImpl extends _TransactionState {
  const _$TransactionStateImpl(
      {required this.tx,
      this.loadingAddresses = false,
      this.errLoadingAddresses = '',
      this.label = '',
      this.savingLabel = false,
      this.errSavingLabel = '',
      this.updatedTx,
      this.buildingTx = false,
      this.errBuildingTx = '',
      this.sendingTx = false,
      this.errSendingTx = '',
      this.sentTx = false})
      : super._();

  @override
  final Transaction tx;
  @override
  @JsonKey()
  final bool loadingAddresses;
  @override
  @JsonKey()
  final String errLoadingAddresses;
  @override
  @JsonKey()
  final String label;
  @override
  @JsonKey()
  final bool savingLabel;
  @override
  @JsonKey()
  final String errSavingLabel;
//
  @override
  final Transaction? updatedTx;
// int? feeRate,
  @override
  @JsonKey()
  final bool buildingTx;
  @override
  @JsonKey()
  final String errBuildingTx;
  @override
  @JsonKey()
  final bool sendingTx;
  @override
  @JsonKey()
  final String errSendingTx;
  @override
  @JsonKey()
  final bool sentTx;

  @override
  String toString() {
    return 'TransactionState(tx: $tx, loadingAddresses: $loadingAddresses, errLoadingAddresses: $errLoadingAddresses, label: $label, savingLabel: $savingLabel, errSavingLabel: $errSavingLabel, updatedTx: $updatedTx, buildingTx: $buildingTx, errBuildingTx: $errBuildingTx, sendingTx: $sendingTx, errSendingTx: $errSendingTx, sentTx: $sentTx)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransactionStateImpl &&
            (identical(other.tx, tx) || other.tx == tx) &&
            (identical(other.loadingAddresses, loadingAddresses) ||
                other.loadingAddresses == loadingAddresses) &&
            (identical(other.errLoadingAddresses, errLoadingAddresses) ||
                other.errLoadingAddresses == errLoadingAddresses) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.savingLabel, savingLabel) ||
                other.savingLabel == savingLabel) &&
            (identical(other.errSavingLabel, errSavingLabel) ||
                other.errSavingLabel == errSavingLabel) &&
            (identical(other.updatedTx, updatedTx) ||
                other.updatedTx == updatedTx) &&
            (identical(other.buildingTx, buildingTx) ||
                other.buildingTx == buildingTx) &&
            (identical(other.errBuildingTx, errBuildingTx) ||
                other.errBuildingTx == errBuildingTx) &&
            (identical(other.sendingTx, sendingTx) ||
                other.sendingTx == sendingTx) &&
            (identical(other.errSendingTx, errSendingTx) ||
                other.errSendingTx == errSendingTx) &&
            (identical(other.sentTx, sentTx) || other.sentTx == sentTx));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      tx,
      loadingAddresses,
      errLoadingAddresses,
      label,
      savingLabel,
      errSavingLabel,
      updatedTx,
      buildingTx,
      errBuildingTx,
      sendingTx,
      errSendingTx,
      sentTx);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TransactionStateImplCopyWith<_$TransactionStateImpl> get copyWith =>
      __$$TransactionStateImplCopyWithImpl<_$TransactionStateImpl>(
          this, _$identity);
}

abstract class _TransactionState extends TransactionState {
  const factory _TransactionState(
      {required final Transaction tx,
      final bool loadingAddresses,
      final String errLoadingAddresses,
      final String label,
      final bool savingLabel,
      final String errSavingLabel,
      final Transaction? updatedTx,
      final bool buildingTx,
      final String errBuildingTx,
      final bool sendingTx,
      final String errSendingTx,
      final bool sentTx}) = _$TransactionStateImpl;
  const _TransactionState._() : super._();

  @override
  Transaction get tx;
  @override
  bool get loadingAddresses;
  @override
  String get errLoadingAddresses;
  @override
  String get label;
  @override
  bool get savingLabel;
  @override
  String get errSavingLabel;
  @override //
  Transaction? get updatedTx;
  @override // int? feeRate,
  bool get buildingTx;
  @override
  String get errBuildingTx;
  @override
  bool get sendingTx;
  @override
  String get errSendingTx;
  @override
  bool get sentTx;
  @override
  @JsonKey(ignore: true)
  _$$TransactionStateImplCopyWith<_$TransactionStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
