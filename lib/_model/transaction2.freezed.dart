// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction2.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

Transaction2 _$Transaction2FromJson(Map<String, dynamic> json) {
  return _Transaction2.fromJson(json);
}

/// @nodoc
mixin _$Transaction2 {
  String get txid => throw _privateConstructorUsedError;
  int? get received => throw _privateConstructorUsedError;
  int? get sent => throw _privateConstructorUsedError;
  int? get fee => throw _privateConstructorUsedError;
  int? get height => throw _privateConstructorUsedError;
  int? get timestamp => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  String? get fromAddress => throw _privateConstructorUsedError;
  String? get toAddress => throw _privateConstructorUsedError;
  String? get psbt => throw _privateConstructorUsedError;
  bool? get rbfEnabled => throw _privateConstructorUsedError;
  bool get oldTx => throw _privateConstructorUsedError;
  int? get broadcastTime =>
      throw _privateConstructorUsedError; // String? serializedTx,
  List<String>? get vins => throw _privateConstructorUsedError; // address:vin[]
  List<String>? get vouts =>
      throw _privateConstructorUsedError; // address:vout[]
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.TransactionDetails? get bdkTx => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $Transaction2CopyWith<Transaction2> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Transaction2CopyWith<$Res> {
  factory $Transaction2CopyWith(
          Transaction2 value, $Res Function(Transaction2) then) =
      _$Transaction2CopyWithImpl<$Res, Transaction2>;
  @useResult
  $Res call(
      {String txid,
      int? received,
      int? sent,
      int? fee,
      int? height,
      int? timestamp,
      String? label,
      String? fromAddress,
      String? toAddress,
      String? psbt,
      bool? rbfEnabled,
      bool oldTx,
      int? broadcastTime,
      List<String>? vins,
      List<String>? vouts,
      @JsonKey(includeFromJson: false, includeToJson: false)
      bdk.TransactionDetails? bdkTx});
}

/// @nodoc
class _$Transaction2CopyWithImpl<$Res, $Val extends Transaction2>
    implements $Transaction2CopyWith<$Res> {
  _$Transaction2CopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? txid = null,
    Object? received = freezed,
    Object? sent = freezed,
    Object? fee = freezed,
    Object? height = freezed,
    Object? timestamp = freezed,
    Object? label = freezed,
    Object? fromAddress = freezed,
    Object? toAddress = freezed,
    Object? psbt = freezed,
    Object? rbfEnabled = freezed,
    Object? oldTx = null,
    Object? broadcastTime = freezed,
    Object? vins = freezed,
    Object? vouts = freezed,
    Object? bdkTx = freezed,
  }) {
    return _then(_value.copyWith(
      txid: null == txid
          ? _value.txid
          : txid // ignore: cast_nullable_to_non_nullable
              as String,
      received: freezed == received
          ? _value.received
          : received // ignore: cast_nullable_to_non_nullable
              as int?,
      sent: freezed == sent
          ? _value.sent
          : sent // ignore: cast_nullable_to_non_nullable
              as int?,
      fee: freezed == fee
          ? _value.fee
          : fee // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
      timestamp: freezed == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as int?,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      fromAddress: freezed == fromAddress
          ? _value.fromAddress
          : fromAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      toAddress: freezed == toAddress
          ? _value.toAddress
          : toAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      psbt: freezed == psbt
          ? _value.psbt
          : psbt // ignore: cast_nullable_to_non_nullable
              as String?,
      rbfEnabled: freezed == rbfEnabled
          ? _value.rbfEnabled
          : rbfEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
      oldTx: null == oldTx
          ? _value.oldTx
          : oldTx // ignore: cast_nullable_to_non_nullable
              as bool,
      broadcastTime: freezed == broadcastTime
          ? _value.broadcastTime
          : broadcastTime // ignore: cast_nullable_to_non_nullable
              as int?,
      vins: freezed == vins
          ? _value.vins
          : vins // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      vouts: freezed == vouts
          ? _value.vouts
          : vouts // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      bdkTx: freezed == bdkTx
          ? _value.bdkTx
          : bdkTx // ignore: cast_nullable_to_non_nullable
              as bdk.TransactionDetails?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_Transaction2CopyWith<$Res>
    implements $Transaction2CopyWith<$Res> {
  factory _$$_Transaction2CopyWith(
          _$_Transaction2 value, $Res Function(_$_Transaction2) then) =
      __$$_Transaction2CopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String txid,
      int? received,
      int? sent,
      int? fee,
      int? height,
      int? timestamp,
      String? label,
      String? fromAddress,
      String? toAddress,
      String? psbt,
      bool? rbfEnabled,
      bool oldTx,
      int? broadcastTime,
      List<String>? vins,
      List<String>? vouts,
      @JsonKey(includeFromJson: false, includeToJson: false)
      bdk.TransactionDetails? bdkTx});
}

/// @nodoc
class __$$_Transaction2CopyWithImpl<$Res>
    extends _$Transaction2CopyWithImpl<$Res, _$_Transaction2>
    implements _$$_Transaction2CopyWith<$Res> {
  __$$_Transaction2CopyWithImpl(
      _$_Transaction2 _value, $Res Function(_$_Transaction2) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? txid = null,
    Object? received = freezed,
    Object? sent = freezed,
    Object? fee = freezed,
    Object? height = freezed,
    Object? timestamp = freezed,
    Object? label = freezed,
    Object? fromAddress = freezed,
    Object? toAddress = freezed,
    Object? psbt = freezed,
    Object? rbfEnabled = freezed,
    Object? oldTx = null,
    Object? broadcastTime = freezed,
    Object? vins = freezed,
    Object? vouts = freezed,
    Object? bdkTx = freezed,
  }) {
    return _then(_$_Transaction2(
      txid: null == txid
          ? _value.txid
          : txid // ignore: cast_nullable_to_non_nullable
              as String,
      received: freezed == received
          ? _value.received
          : received // ignore: cast_nullable_to_non_nullable
              as int?,
      sent: freezed == sent
          ? _value.sent
          : sent // ignore: cast_nullable_to_non_nullable
              as int?,
      fee: freezed == fee
          ? _value.fee
          : fee // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
      timestamp: freezed == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as int?,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      fromAddress: freezed == fromAddress
          ? _value.fromAddress
          : fromAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      toAddress: freezed == toAddress
          ? _value.toAddress
          : toAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      psbt: freezed == psbt
          ? _value.psbt
          : psbt // ignore: cast_nullable_to_non_nullable
              as String?,
      rbfEnabled: freezed == rbfEnabled
          ? _value.rbfEnabled
          : rbfEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
      oldTx: null == oldTx
          ? _value.oldTx
          : oldTx // ignore: cast_nullable_to_non_nullable
              as bool,
      broadcastTime: freezed == broadcastTime
          ? _value.broadcastTime
          : broadcastTime // ignore: cast_nullable_to_non_nullable
              as int?,
      vins: freezed == vins
          ? _value._vins
          : vins // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      vouts: freezed == vouts
          ? _value._vouts
          : vouts // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      bdkTx: freezed == bdkTx
          ? _value.bdkTx
          : bdkTx // ignore: cast_nullable_to_non_nullable
              as bdk.TransactionDetails?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_Transaction2 extends _Transaction2 {
  const _$_Transaction2(
      {required this.txid,
      this.received,
      this.sent,
      this.fee,
      this.height,
      this.timestamp,
      this.label,
      this.fromAddress,
      this.toAddress,
      this.psbt,
      this.rbfEnabled,
      this.oldTx = false,
      this.broadcastTime,
      final List<String>? vins,
      final List<String>? vouts,
      @JsonKey(includeFromJson: false, includeToJson: false) this.bdkTx})
      : _vins = vins,
        _vouts = vouts,
        super._();

  factory _$_Transaction2.fromJson(Map<String, dynamic> json) =>
      _$$_Transaction2FromJson(json);

  @override
  final String txid;
  @override
  final int? received;
  @override
  final int? sent;
  @override
  final int? fee;
  @override
  final int? height;
  @override
  final int? timestamp;
  @override
  final String? label;
  @override
  final String? fromAddress;
  @override
  final String? toAddress;
  @override
  final String? psbt;
  @override
  final bool? rbfEnabled;
  @override
  @JsonKey()
  final bool oldTx;
  @override
  final int? broadcastTime;
// String? serializedTx,
  final List<String>? _vins;
// String? serializedTx,
  @override
  List<String>? get vins {
    final value = _vins;
    if (value == null) return null;
    if (_vins is EqualUnmodifiableListView) return _vins;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// address:vin[]
  final List<String>? _vouts;
// address:vin[]
  @override
  List<String>? get vouts {
    final value = _vouts;
    if (value == null) return null;
    if (_vouts is EqualUnmodifiableListView) return _vouts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// address:vout[]
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bdk.TransactionDetails? bdkTx;

  @override
  String toString() {
    return 'Transaction2(txid: $txid, received: $received, sent: $sent, fee: $fee, height: $height, timestamp: $timestamp, label: $label, fromAddress: $fromAddress, toAddress: $toAddress, psbt: $psbt, rbfEnabled: $rbfEnabled, oldTx: $oldTx, broadcastTime: $broadcastTime, vins: $vins, vouts: $vouts, bdkTx: $bdkTx)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_Transaction2 &&
            (identical(other.txid, txid) || other.txid == txid) &&
            (identical(other.received, received) ||
                other.received == received) &&
            (identical(other.sent, sent) || other.sent == sent) &&
            (identical(other.fee, fee) || other.fee == fee) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.fromAddress, fromAddress) ||
                other.fromAddress == fromAddress) &&
            (identical(other.toAddress, toAddress) ||
                other.toAddress == toAddress) &&
            (identical(other.psbt, psbt) || other.psbt == psbt) &&
            (identical(other.rbfEnabled, rbfEnabled) ||
                other.rbfEnabled == rbfEnabled) &&
            (identical(other.oldTx, oldTx) || other.oldTx == oldTx) &&
            (identical(other.broadcastTime, broadcastTime) ||
                other.broadcastTime == broadcastTime) &&
            const DeepCollectionEquality().equals(other._vins, _vins) &&
            const DeepCollectionEquality().equals(other._vouts, _vouts) &&
            (identical(other.bdkTx, bdkTx) || other.bdkTx == bdkTx));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      txid,
      received,
      sent,
      fee,
      height,
      timestamp,
      label,
      fromAddress,
      toAddress,
      psbt,
      rbfEnabled,
      oldTx,
      broadcastTime,
      const DeepCollectionEquality().hash(_vins),
      const DeepCollectionEquality().hash(_vouts),
      bdkTx);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_Transaction2CopyWith<_$_Transaction2> get copyWith =>
      __$$_Transaction2CopyWithImpl<_$_Transaction2>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_Transaction2ToJson(
      this,
    );
  }
}

abstract class _Transaction2 extends Transaction2 {
  const factory _Transaction2(
      {required final String txid,
      final int? received,
      final int? sent,
      final int? fee,
      final int? height,
      final int? timestamp,
      final String? label,
      final String? fromAddress,
      final String? toAddress,
      final String? psbt,
      final bool? rbfEnabled,
      final bool oldTx,
      final int? broadcastTime,
      final List<String>? vins,
      final List<String>? vouts,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final bdk.TransactionDetails? bdkTx}) = _$_Transaction2;
  const _Transaction2._() : super._();

  factory _Transaction2.fromJson(Map<String, dynamic> json) =
      _$_Transaction2.fromJson;

  @override
  String get txid;
  @override
  int? get received;
  @override
  int? get sent;
  @override
  int? get fee;
  @override
  int? get height;
  @override
  int? get timestamp;
  @override
  String? get label;
  @override
  String? get fromAddress;
  @override
  String? get toAddress;
  @override
  String? get psbt;
  @override
  bool? get rbfEnabled;
  @override
  bool get oldTx;
  @override
  int? get broadcastTime;
  @override // String? serializedTx,
  List<String>? get vins;
  @override // address:vin[]
  List<String>? get vouts;
  @override // address:vout[]
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.TransactionDetails? get bdkTx;
  @override
  @JsonKey(ignore: true)
  _$$_Transaction2CopyWith<_$_Transaction2> get copyWith =>
      throw _privateConstructorUsedError;
}
