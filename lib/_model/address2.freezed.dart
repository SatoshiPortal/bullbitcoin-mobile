// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'address2.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

Address2 _$Address2FromJson(Map<String, dynamic> json) {
  return _Address2.fromJson(json);
}

/// @nodoc
mixin _$Address2 {
  String get address => throw _privateConstructorUsedError;
  int get index => throw _privateConstructorUsedError;
  AddressKind get kind => throw _privateConstructorUsedError;
  AddressState get state => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  String? get spentTxId => throw _privateConstructorUsedError;
  bool? get isReceive => throw _privateConstructorUsedError;
  bool get saving => throw _privateConstructorUsedError;
  String get errSaving => throw _privateConstructorUsedError;
  int get highestPreviousBalance => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<LocalUtxo>? get utxos => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $Address2CopyWith<Address2> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Address2CopyWith<$Res> {
  factory $Address2CopyWith(Address2 value, $Res Function(Address2) then) =
      _$Address2CopyWithImpl<$Res, Address2>;
  @useResult
  $Res call(
      {String address,
      int index,
      AddressKind kind,
      AddressState state,
      String? label,
      String? spentTxId,
      bool? isReceive,
      bool saving,
      String errSaving,
      int highestPreviousBalance,
      @JsonKey(includeFromJson: false, includeToJson: false)
      List<LocalUtxo>? utxos});
}

/// @nodoc
class _$Address2CopyWithImpl<$Res, $Val extends Address2>
    implements $Address2CopyWith<$Res> {
  _$Address2CopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? address = null,
    Object? index = null,
    Object? kind = null,
    Object? state = null,
    Object? label = freezed,
    Object? spentTxId = freezed,
    Object? isReceive = freezed,
    Object? saving = null,
    Object? errSaving = null,
    Object? highestPreviousBalance = null,
    Object? utxos = freezed,
  }) {
    return _then(_value.copyWith(
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
      kind: null == kind
          ? _value.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as AddressKind,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as AddressState,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      spentTxId: freezed == spentTxId
          ? _value.spentTxId
          : spentTxId // ignore: cast_nullable_to_non_nullable
              as String?,
      isReceive: freezed == isReceive
          ? _value.isReceive
          : isReceive // ignore: cast_nullable_to_non_nullable
              as bool?,
      saving: null == saving
          ? _value.saving
          : saving // ignore: cast_nullable_to_non_nullable
              as bool,
      errSaving: null == errSaving
          ? _value.errSaving
          : errSaving // ignore: cast_nullable_to_non_nullable
              as String,
      highestPreviousBalance: null == highestPreviousBalance
          ? _value.highestPreviousBalance
          : highestPreviousBalance // ignore: cast_nullable_to_non_nullable
              as int,
      utxos: freezed == utxos
          ? _value.utxos
          : utxos // ignore: cast_nullable_to_non_nullable
              as List<LocalUtxo>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_Address2CopyWith<$Res> implements $Address2CopyWith<$Res> {
  factory _$$_Address2CopyWith(
          _$_Address2 value, $Res Function(_$_Address2) then) =
      __$$_Address2CopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String address,
      int index,
      AddressKind kind,
      AddressState state,
      String? label,
      String? spentTxId,
      bool? isReceive,
      bool saving,
      String errSaving,
      int highestPreviousBalance,
      @JsonKey(includeFromJson: false, includeToJson: false)
      List<LocalUtxo>? utxos});
}

/// @nodoc
class __$$_Address2CopyWithImpl<$Res>
    extends _$Address2CopyWithImpl<$Res, _$_Address2>
    implements _$$_Address2CopyWith<$Res> {
  __$$_Address2CopyWithImpl(
      _$_Address2 _value, $Res Function(_$_Address2) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? address = null,
    Object? index = null,
    Object? kind = null,
    Object? state = null,
    Object? label = freezed,
    Object? spentTxId = freezed,
    Object? isReceive = freezed,
    Object? saving = null,
    Object? errSaving = null,
    Object? highestPreviousBalance = null,
    Object? utxos = freezed,
  }) {
    return _then(_$_Address2(
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
      kind: null == kind
          ? _value.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as AddressKind,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as AddressState,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      spentTxId: freezed == spentTxId
          ? _value.spentTxId
          : spentTxId // ignore: cast_nullable_to_non_nullable
              as String?,
      isReceive: freezed == isReceive
          ? _value.isReceive
          : isReceive // ignore: cast_nullable_to_non_nullable
              as bool?,
      saving: null == saving
          ? _value.saving
          : saving // ignore: cast_nullable_to_non_nullable
              as bool,
      errSaving: null == errSaving
          ? _value.errSaving
          : errSaving // ignore: cast_nullable_to_non_nullable
              as String,
      highestPreviousBalance: null == highestPreviousBalance
          ? _value.highestPreviousBalance
          : highestPreviousBalance // ignore: cast_nullable_to_non_nullable
              as int,
      utxos: freezed == utxos
          ? _value._utxos
          : utxos // ignore: cast_nullable_to_non_nullable
              as List<LocalUtxo>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_Address2 extends _Address2 {
  _$_Address2(
      {required this.address,
      required this.index,
      required this.kind,
      required this.state,
      this.label,
      this.spentTxId,
      this.isReceive,
      this.saving = false,
      this.errSaving = '',
      this.highestPreviousBalance = 0,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final List<LocalUtxo>? utxos})
      : _utxos = utxos,
        super._();

  factory _$_Address2.fromJson(Map<String, dynamic> json) =>
      _$$_Address2FromJson(json);

  @override
  final String address;
  @override
  final int index;
  @override
  final AddressKind kind;
  @override
  final AddressState state;
  @override
  final String? label;
  @override
  final String? spentTxId;
  @override
  final bool? isReceive;
  @override
  @JsonKey()
  final bool saving;
  @override
  @JsonKey()
  final String errSaving;
  @override
  @JsonKey()
  final int highestPreviousBalance;
  final List<LocalUtxo>? _utxos;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<LocalUtxo>? get utxos {
    final value = _utxos;
    if (value == null) return null;
    if (_utxos is EqualUnmodifiableListView) return _utxos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'Address2(address: $address, index: $index, kind: $kind, state: $state, label: $label, spentTxId: $spentTxId, isReceive: $isReceive, saving: $saving, errSaving: $errSaving, highestPreviousBalance: $highestPreviousBalance, utxos: $utxos)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_Address2 &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.spentTxId, spentTxId) ||
                other.spentTxId == spentTxId) &&
            (identical(other.isReceive, isReceive) ||
                other.isReceive == isReceive) &&
            (identical(other.saving, saving) || other.saving == saving) &&
            (identical(other.errSaving, errSaving) ||
                other.errSaving == errSaving) &&
            (identical(other.highestPreviousBalance, highestPreviousBalance) ||
                other.highestPreviousBalance == highestPreviousBalance) &&
            const DeepCollectionEquality().equals(other._utxos, _utxos));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      address,
      index,
      kind,
      state,
      label,
      spentTxId,
      isReceive,
      saving,
      errSaving,
      highestPreviousBalance,
      const DeepCollectionEquality().hash(_utxos));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_Address2CopyWith<_$_Address2> get copyWith =>
      __$$_Address2CopyWithImpl<_$_Address2>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_Address2ToJson(
      this,
    );
  }
}

abstract class _Address2 extends Address2 {
  factory _Address2(
      {required final String address,
      required final int index,
      required final AddressKind kind,
      required final AddressState state,
      final String? label,
      final String? spentTxId,
      final bool? isReceive,
      final bool saving,
      final String errSaving,
      final int highestPreviousBalance,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final List<LocalUtxo>? utxos}) = _$_Address2;
  _Address2._() : super._();

  factory _Address2.fromJson(Map<String, dynamic> json) = _$_Address2.fromJson;

  @override
  String get address;
  @override
  int get index;
  @override
  AddressKind get kind;
  @override
  AddressState get state;
  @override
  String? get label;
  @override
  String? get spentTxId;
  @override
  bool? get isReceive;
  @override
  bool get saving;
  @override
  String get errSaving;
  @override
  int get highestPreviousBalance;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<LocalUtxo>? get utxos;
  @override
  @JsonKey(ignore: true)
  _$$_Address2CopyWith<_$_Address2> get copyWith =>
      throw _privateConstructorUsedError;
}
