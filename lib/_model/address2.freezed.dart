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
  AddressType get type => throw _privateConstructorUsedError;
  List<String>? get txVIns => throw _privateConstructorUsedError; // txid:vin[]
// notMine: receive tx, myChange/myDeposit: spend tx
  List<String>? get txVOuts =>
      throw _privateConstructorUsedError; // txid:vout[]
// myDeposit: receive tx, notMine/myChange: spend tx
  int? get balance => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
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
      AddressType type,
      List<String>? txVIns,
      List<String>? txVOuts,
      int? balance,
      String? label,
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
    Object? type = null,
    Object? txVIns = freezed,
    Object? txVOuts = freezed,
    Object? balance = freezed,
    Object? label = freezed,
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
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as AddressType,
      txVIns: freezed == txVIns
          ? _value.txVIns
          : txVIns // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      txVOuts: freezed == txVOuts
          ? _value.txVOuts
          : txVOuts // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      balance: freezed == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as int?,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
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
      AddressType type,
      List<String>? txVIns,
      List<String>? txVOuts,
      int? balance,
      String? label,
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
    Object? type = null,
    Object? txVIns = freezed,
    Object? txVOuts = freezed,
    Object? balance = freezed,
    Object? label = freezed,
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
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as AddressType,
      txVIns: freezed == txVIns
          ? _value._txVIns
          : txVIns // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      txVOuts: freezed == txVOuts
          ? _value._txVOuts
          : txVOuts // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      balance: freezed == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as int?,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
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
      required this.type,
      final List<String>? txVIns,
      final List<String>? txVOuts,
      this.balance = 0,
      this.label = '',
      @JsonKey(includeFromJson: false, includeToJson: false)
      final List<LocalUtxo>? utxos})
      : _txVIns = txVIns,
        _txVOuts = txVOuts,
        _utxos = utxos,
        super._();

  factory _$_Address2.fromJson(Map<String, dynamic> json) =>
      _$$_Address2FromJson(json);

  @override
  final String address;
  @override
  final int index;
  @override
  final AddressType type;
  final List<String>? _txVIns;
  @override
  List<String>? get txVIns {
    final value = _txVIns;
    if (value == null) return null;
    if (_txVIns is EqualUnmodifiableListView) return _txVIns;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// txid:vin[]
// notMine: receive tx, myChange/myDeposit: spend tx
  final List<String>? _txVOuts;
// txid:vin[]
// notMine: receive tx, myChange/myDeposit: spend tx
  @override
  List<String>? get txVOuts {
    final value = _txVOuts;
    if (value == null) return null;
    if (_txVOuts is EqualUnmodifiableListView) return _txVOuts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// txid:vout[]
// myDeposit: receive tx, notMine/myChange: spend tx
  @override
  @JsonKey()
  final int? balance;
  @override
  @JsonKey()
  final String? label;
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
    return 'Address2(address: $address, index: $index, type: $type, txVIns: $txVIns, txVOuts: $txVOuts, balance: $balance, label: $label, utxos: $utxos)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_Address2 &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(other._txVIns, _txVIns) &&
            const DeepCollectionEquality().equals(other._txVOuts, _txVOuts) &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.label, label) || other.label == label) &&
            const DeepCollectionEquality().equals(other._utxos, _utxos));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      address,
      index,
      type,
      const DeepCollectionEquality().hash(_txVIns),
      const DeepCollectionEquality().hash(_txVOuts),
      balance,
      label,
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
      required final AddressType type,
      final List<String>? txVIns,
      final List<String>? txVOuts,
      final int? balance,
      final String? label,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final List<LocalUtxo>? utxos}) = _$_Address2;
  _Address2._() : super._();

  factory _Address2.fromJson(Map<String, dynamic> json) = _$_Address2.fromJson;

  @override
  String get address;
  @override
  int get index;
  @override
  AddressType get type;
  @override
  List<String>? get txVIns;
  @override // txid:vin[]
// notMine: receive tx, myChange/myDeposit: spend tx
  List<String>? get txVOuts;
  @override // txid:vout[]
// myDeposit: receive tx, notMine/myChange: spend tx
  int? get balance;
  @override
  String? get label;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<LocalUtxo>? get utxos;
  @override
  @JsonKey(ignore: true)
  _$$_Address2CopyWith<_$_Address2> get copyWith =>
      throw _privateConstructorUsedError;
}
