// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'address.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

Address _$AddressFromJson(Map<String, dynamic> json) {
  return _Address.fromJson(json);
}

/// @nodoc
mixin _$Address {
  String get address => throw _privateConstructorUsedError;
  int get index => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  String? get sentTxId => throw _privateConstructorUsedError;
  bool? get isReceive => throw _privateConstructorUsedError;
  bool get saving => throw _privateConstructorUsedError;
  String get errSaving => throw _privateConstructorUsedError;
  bool get unspendable => throw _privateConstructorUsedError;
  bool get isMine => throw _privateConstructorUsedError;
  int get highestPreviousBalance => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<LocalUtxo>? get utxos => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $AddressCopyWith<Address> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AddressCopyWith<$Res> {
  factory $AddressCopyWith(Address value, $Res Function(Address) then) =
      _$AddressCopyWithImpl<$Res, Address>;
  @useResult
  $Res call(
      {String address,
      int index,
      String? label,
      String? sentTxId,
      bool? isReceive,
      bool saving,
      String errSaving,
      bool unspendable,
      bool isMine,
      int highestPreviousBalance,
      @JsonKey(includeFromJson: false, includeToJson: false)
      List<LocalUtxo>? utxos});
}

/// @nodoc
class _$AddressCopyWithImpl<$Res, $Val extends Address>
    implements $AddressCopyWith<$Res> {
  _$AddressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? address = null,
    Object? index = null,
    Object? label = freezed,
    Object? sentTxId = freezed,
    Object? isReceive = freezed,
    Object? saving = null,
    Object? errSaving = null,
    Object? unspendable = null,
    Object? isMine = null,
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
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      sentTxId: freezed == sentTxId
          ? _value.sentTxId
          : sentTxId // ignore: cast_nullable_to_non_nullable
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
      unspendable: null == unspendable
          ? _value.unspendable
          : unspendable // ignore: cast_nullable_to_non_nullable
              as bool,
      isMine: null == isMine
          ? _value.isMine
          : isMine // ignore: cast_nullable_to_non_nullable
              as bool,
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
abstract class _$$_AddressCopyWith<$Res> implements $AddressCopyWith<$Res> {
  factory _$$_AddressCopyWith(
          _$_Address value, $Res Function(_$_Address) then) =
      __$$_AddressCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String address,
      int index,
      String? label,
      String? sentTxId,
      bool? isReceive,
      bool saving,
      String errSaving,
      bool unspendable,
      bool isMine,
      int highestPreviousBalance,
      @JsonKey(includeFromJson: false, includeToJson: false)
      List<LocalUtxo>? utxos});
}

/// @nodoc
class __$$_AddressCopyWithImpl<$Res>
    extends _$AddressCopyWithImpl<$Res, _$_Address>
    implements _$$_AddressCopyWith<$Res> {
  __$$_AddressCopyWithImpl(_$_Address _value, $Res Function(_$_Address) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? address = null,
    Object? index = null,
    Object? label = freezed,
    Object? sentTxId = freezed,
    Object? isReceive = freezed,
    Object? saving = null,
    Object? errSaving = null,
    Object? unspendable = null,
    Object? isMine = null,
    Object? highestPreviousBalance = null,
    Object? utxos = freezed,
  }) {
    return _then(_$_Address(
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      sentTxId: freezed == sentTxId
          ? _value.sentTxId
          : sentTxId // ignore: cast_nullable_to_non_nullable
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
      unspendable: null == unspendable
          ? _value.unspendable
          : unspendable // ignore: cast_nullable_to_non_nullable
              as bool,
      isMine: null == isMine
          ? _value.isMine
          : isMine // ignore: cast_nullable_to_non_nullable
              as bool,
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
class _$_Address extends _Address {
  _$_Address(
      {required this.address,
      required this.index,
      this.label,
      this.sentTxId,
      this.isReceive,
      this.saving = false,
      this.errSaving = '',
      this.unspendable = false,
      this.isMine = true,
      this.highestPreviousBalance = 0,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final List<LocalUtxo>? utxos})
      : _utxos = utxos,
        super._();

  factory _$_Address.fromJson(Map<String, dynamic> json) =>
      _$$_AddressFromJson(json);

  @override
  final String address;
  @override
  final int index;
  @override
  final String? label;
  @override
  final String? sentTxId;
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
  final bool unspendable;
  @override
  @JsonKey()
  final bool isMine;
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
    return 'Address(address: $address, index: $index, label: $label, sentTxId: $sentTxId, isReceive: $isReceive, saving: $saving, errSaving: $errSaving, unspendable: $unspendable, isMine: $isMine, highestPreviousBalance: $highestPreviousBalance, utxos: $utxos)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_Address &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.sentTxId, sentTxId) ||
                other.sentTxId == sentTxId) &&
            (identical(other.isReceive, isReceive) ||
                other.isReceive == isReceive) &&
            (identical(other.saving, saving) || other.saving == saving) &&
            (identical(other.errSaving, errSaving) ||
                other.errSaving == errSaving) &&
            (identical(other.unspendable, unspendable) ||
                other.unspendable == unspendable) &&
            (identical(other.isMine, isMine) || other.isMine == isMine) &&
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
      label,
      sentTxId,
      isReceive,
      saving,
      errSaving,
      unspendable,
      isMine,
      highestPreviousBalance,
      const DeepCollectionEquality().hash(_utxos));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_AddressCopyWith<_$_Address> get copyWith =>
      __$$_AddressCopyWithImpl<_$_Address>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_AddressToJson(
      this,
    );
  }
}

abstract class _Address extends Address {
  factory _Address(
      {required final String address,
      required final int index,
      final String? label,
      final String? sentTxId,
      final bool? isReceive,
      final bool saving,
      final String errSaving,
      final bool unspendable,
      final bool isMine,
      final int highestPreviousBalance,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final List<LocalUtxo>? utxos}) = _$_Address;
  _Address._() : super._();

  factory _Address.fromJson(Map<String, dynamic> json) = _$_Address.fromJson;

  @override
  String get address;
  @override
  int get index;
  @override
  String? get label;
  @override
  String? get sentTxId;
  @override
  bool? get isReceive;
  @override
  bool get saving;
  @override
  String get errSaving;
  @override
  bool get unspendable;
  @override
  bool get isMine;
  @override
  int get highestPreviousBalance;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<LocalUtxo>? get utxos;
  @override
  @JsonKey(ignore: true)
  _$$_AddressCopyWith<_$_Address> get copyWith =>
      throw _privateConstructorUsedError;
}
