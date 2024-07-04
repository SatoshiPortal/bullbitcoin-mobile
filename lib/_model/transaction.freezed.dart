// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Transaction _$TransactionFromJson(Map<String, dynamic> json) {
  return _Transaction.fromJson(json);
}

/// @nodoc
mixin _$Transaction {
  int get timestamp => throw _privateConstructorUsedError;
  String get txid => throw _privateConstructorUsedError;
  int? get received => throw _privateConstructorUsedError;
  int? get sent => throw _privateConstructorUsedError;
  int? get fee => throw _privateConstructorUsedError;
  double? get feeRate => throw _privateConstructorUsedError;
  int? get height => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  String? get toAddress => throw _privateConstructorUsedError;
  String? get psbt => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  Uint8List? get pset => throw _privateConstructorUsedError;
  bool get rbfEnabled =>
      throw _privateConstructorUsedError; // @Default(false) bool oldTx,
  int? get broadcastTime =>
      throw _privateConstructorUsedError; // String? serializedTx,
  List<Address> get outAddrs => throw _privateConstructorUsedError;
  List<TxIn> get inputs => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.TransactionDetails? get bdkTx =>
      throw _privateConstructorUsedError; // Wallet? wallet,
  bool get isSwap => throw _privateConstructorUsedError;
  SwapTx? get swapTx => throw _privateConstructorUsedError;
  bool get isLiquid => throw _privateConstructorUsedError;
  String get unblindedUrl => throw _privateConstructorUsedError;
  List<String> get rbfTxIds => throw _privateConstructorUsedError;
  String? get walletId => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TransactionCopyWith<Transaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransactionCopyWith<$Res> {
  factory $TransactionCopyWith(
          Transaction value, $Res Function(Transaction) then) =
      _$TransactionCopyWithImpl<$Res, Transaction>;
  @useResult
  $Res call(
      {int timestamp,
      String txid,
      int? received,
      int? sent,
      int? fee,
      double? feeRate,
      int? height,
      String? label,
      String? toAddress,
      String? psbt,
      @JsonKey(includeFromJson: false, includeToJson: false) Uint8List? pset,
      bool rbfEnabled,
      int? broadcastTime,
      List<Address> outAddrs,
      List<TxIn> inputs,
      @JsonKey(includeFromJson: false, includeToJson: false)
      bdk.TransactionDetails? bdkTx,
      bool isSwap,
      SwapTx? swapTx,
      bool isLiquid,
      String unblindedUrl,
      List<String> rbfTxIds,
      String? walletId});

  $SwapTxCopyWith<$Res>? get swapTx;
}

/// @nodoc
class _$TransactionCopyWithImpl<$Res, $Val extends Transaction>
    implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
    Object? txid = null,
    Object? received = freezed,
    Object? sent = freezed,
    Object? fee = freezed,
    Object? feeRate = freezed,
    Object? height = freezed,
    Object? label = freezed,
    Object? toAddress = freezed,
    Object? psbt = freezed,
    Object? pset = freezed,
    Object? rbfEnabled = null,
    Object? broadcastTime = freezed,
    Object? outAddrs = null,
    Object? inputs = null,
    Object? bdkTx = freezed,
    Object? isSwap = null,
    Object? swapTx = freezed,
    Object? isLiquid = null,
    Object? unblindedUrl = null,
    Object? rbfTxIds = null,
    Object? walletId = freezed,
  }) {
    return _then(_value.copyWith(
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as int,
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
      feeRate: freezed == feeRate
          ? _value.feeRate
          : feeRate // ignore: cast_nullable_to_non_nullable
              as double?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      toAddress: freezed == toAddress
          ? _value.toAddress
          : toAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      psbt: freezed == psbt
          ? _value.psbt
          : psbt // ignore: cast_nullable_to_non_nullable
              as String?,
      pset: freezed == pset
          ? _value.pset
          : pset // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      rbfEnabled: null == rbfEnabled
          ? _value.rbfEnabled
          : rbfEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      broadcastTime: freezed == broadcastTime
          ? _value.broadcastTime
          : broadcastTime // ignore: cast_nullable_to_non_nullable
              as int?,
      outAddrs: null == outAddrs
          ? _value.outAddrs
          : outAddrs // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      inputs: null == inputs
          ? _value.inputs
          : inputs // ignore: cast_nullable_to_non_nullable
              as List<TxIn>,
      bdkTx: freezed == bdkTx
          ? _value.bdkTx
          : bdkTx // ignore: cast_nullable_to_non_nullable
              as bdk.TransactionDetails?,
      isSwap: null == isSwap
          ? _value.isSwap
          : isSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      swapTx: freezed == swapTx
          ? _value.swapTx
          : swapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
      isLiquid: null == isLiquid
          ? _value.isLiquid
          : isLiquid // ignore: cast_nullable_to_non_nullable
              as bool,
      unblindedUrl: null == unblindedUrl
          ? _value.unblindedUrl
          : unblindedUrl // ignore: cast_nullable_to_non_nullable
              as String,
      rbfTxIds: null == rbfTxIds
          ? _value.rbfTxIds
          : rbfTxIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      walletId: freezed == walletId
          ? _value.walletId
          : walletId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $SwapTxCopyWith<$Res>? get swapTx {
    if (_value.swapTx == null) {
      return null;
    }

    return $SwapTxCopyWith<$Res>(_value.swapTx!, (value) {
      return _then(_value.copyWith(swapTx: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TransactionImplCopyWith<$Res>
    implements $TransactionCopyWith<$Res> {
  factory _$$TransactionImplCopyWith(
          _$TransactionImpl value, $Res Function(_$TransactionImpl) then) =
      __$$TransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int timestamp,
      String txid,
      int? received,
      int? sent,
      int? fee,
      double? feeRate,
      int? height,
      String? label,
      String? toAddress,
      String? psbt,
      @JsonKey(includeFromJson: false, includeToJson: false) Uint8List? pset,
      bool rbfEnabled,
      int? broadcastTime,
      List<Address> outAddrs,
      List<TxIn> inputs,
      @JsonKey(includeFromJson: false, includeToJson: false)
      bdk.TransactionDetails? bdkTx,
      bool isSwap,
      SwapTx? swapTx,
      bool isLiquid,
      String unblindedUrl,
      List<String> rbfTxIds,
      String? walletId});

  @override
  $SwapTxCopyWith<$Res>? get swapTx;
}

/// @nodoc
class __$$TransactionImplCopyWithImpl<$Res>
    extends _$TransactionCopyWithImpl<$Res, _$TransactionImpl>
    implements _$$TransactionImplCopyWith<$Res> {
  __$$TransactionImplCopyWithImpl(
      _$TransactionImpl _value, $Res Function(_$TransactionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timestamp = null,
    Object? txid = null,
    Object? received = freezed,
    Object? sent = freezed,
    Object? fee = freezed,
    Object? feeRate = freezed,
    Object? height = freezed,
    Object? label = freezed,
    Object? toAddress = freezed,
    Object? psbt = freezed,
    Object? pset = freezed,
    Object? rbfEnabled = null,
    Object? broadcastTime = freezed,
    Object? outAddrs = null,
    Object? inputs = null,
    Object? bdkTx = freezed,
    Object? isSwap = null,
    Object? swapTx = freezed,
    Object? isLiquid = null,
    Object? unblindedUrl = null,
    Object? rbfTxIds = null,
    Object? walletId = freezed,
  }) {
    return _then(_$TransactionImpl(
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as int,
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
      feeRate: freezed == feeRate
          ? _value.feeRate
          : feeRate // ignore: cast_nullable_to_non_nullable
              as double?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      toAddress: freezed == toAddress
          ? _value.toAddress
          : toAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      psbt: freezed == psbt
          ? _value.psbt
          : psbt // ignore: cast_nullable_to_non_nullable
              as String?,
      pset: freezed == pset
          ? _value.pset
          : pset // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      rbfEnabled: null == rbfEnabled
          ? _value.rbfEnabled
          : rbfEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      broadcastTime: freezed == broadcastTime
          ? _value.broadcastTime
          : broadcastTime // ignore: cast_nullable_to_non_nullable
              as int?,
      outAddrs: null == outAddrs
          ? _value._outAddrs
          : outAddrs // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      inputs: null == inputs
          ? _value._inputs
          : inputs // ignore: cast_nullable_to_non_nullable
              as List<TxIn>,
      bdkTx: freezed == bdkTx
          ? _value.bdkTx
          : bdkTx // ignore: cast_nullable_to_non_nullable
              as bdk.TransactionDetails?,
      isSwap: null == isSwap
          ? _value.isSwap
          : isSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      swapTx: freezed == swapTx
          ? _value.swapTx
          : swapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
      isLiquid: null == isLiquid
          ? _value.isLiquid
          : isLiquid // ignore: cast_nullable_to_non_nullable
              as bool,
      unblindedUrl: null == unblindedUrl
          ? _value.unblindedUrl
          : unblindedUrl // ignore: cast_nullable_to_non_nullable
              as String,
      rbfTxIds: null == rbfTxIds
          ? _value._rbfTxIds
          : rbfTxIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      walletId: freezed == walletId
          ? _value.walletId
          : walletId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TransactionImpl extends _Transaction with DiagnosticableTreeMixin {
  const _$TransactionImpl(
      {required this.timestamp,
      required this.txid,
      this.received,
      this.sent,
      this.fee,
      this.feeRate,
      this.height,
      this.label,
      this.toAddress,
      this.psbt,
      @JsonKey(includeFromJson: false, includeToJson: false) this.pset,
      this.rbfEnabled = true,
      this.broadcastTime,
      final List<Address> outAddrs = const [],
      final List<TxIn> inputs = const [],
      @JsonKey(includeFromJson: false, includeToJson: false) this.bdkTx,
      this.isSwap = false,
      this.swapTx,
      this.isLiquid = false,
      this.unblindedUrl = '',
      final List<String> rbfTxIds = const [],
      this.walletId})
      : _outAddrs = outAddrs,
        _inputs = inputs,
        _rbfTxIds = rbfTxIds,
        super._();

  factory _$TransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransactionImplFromJson(json);

  @override
  final int timestamp;
  @override
  final String txid;
  @override
  final int? received;
  @override
  final int? sent;
  @override
  final int? fee;
  @override
  final double? feeRate;
  @override
  final int? height;
  @override
  final String? label;
  @override
  final String? toAddress;
  @override
  final String? psbt;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final Uint8List? pset;
  @override
  @JsonKey()
  final bool rbfEnabled;
// @Default(false) bool oldTx,
  @override
  final int? broadcastTime;
// String? serializedTx,
  final List<Address> _outAddrs;
// String? serializedTx,
  @override
  @JsonKey()
  List<Address> get outAddrs {
    if (_outAddrs is EqualUnmodifiableListView) return _outAddrs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_outAddrs);
  }

  final List<TxIn> _inputs;
  @override
  @JsonKey()
  List<TxIn> get inputs {
    if (_inputs is EqualUnmodifiableListView) return _inputs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_inputs);
  }

  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bdk.TransactionDetails? bdkTx;
// Wallet? wallet,
  @override
  @JsonKey()
  final bool isSwap;
  @override
  final SwapTx? swapTx;
  @override
  @JsonKey()
  final bool isLiquid;
  @override
  @JsonKey()
  final String unblindedUrl;
  final List<String> _rbfTxIds;
  @override
  @JsonKey()
  List<String> get rbfTxIds {
    if (_rbfTxIds is EqualUnmodifiableListView) return _rbfTxIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rbfTxIds);
  }

  @override
  final String? walletId;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'Transaction(timestamp: $timestamp, txid: $txid, received: $received, sent: $sent, fee: $fee, feeRate: $feeRate, height: $height, label: $label, toAddress: $toAddress, psbt: $psbt, pset: $pset, rbfEnabled: $rbfEnabled, broadcastTime: $broadcastTime, outAddrs: $outAddrs, inputs: $inputs, bdkTx: $bdkTx, isSwap: $isSwap, swapTx: $swapTx, isLiquid: $isLiquid, unblindedUrl: $unblindedUrl, rbfTxIds: $rbfTxIds, walletId: $walletId)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'Transaction'))
      ..add(DiagnosticsProperty('timestamp', timestamp))
      ..add(DiagnosticsProperty('txid', txid))
      ..add(DiagnosticsProperty('received', received))
      ..add(DiagnosticsProperty('sent', sent))
      ..add(DiagnosticsProperty('fee', fee))
      ..add(DiagnosticsProperty('feeRate', feeRate))
      ..add(DiagnosticsProperty('height', height))
      ..add(DiagnosticsProperty('label', label))
      ..add(DiagnosticsProperty('toAddress', toAddress))
      ..add(DiagnosticsProperty('psbt', psbt))
      ..add(DiagnosticsProperty('pset', pset))
      ..add(DiagnosticsProperty('rbfEnabled', rbfEnabled))
      ..add(DiagnosticsProperty('broadcastTime', broadcastTime))
      ..add(DiagnosticsProperty('outAddrs', outAddrs))
      ..add(DiagnosticsProperty('inputs', inputs))
      ..add(DiagnosticsProperty('bdkTx', bdkTx))
      ..add(DiagnosticsProperty('isSwap', isSwap))
      ..add(DiagnosticsProperty('swapTx', swapTx))
      ..add(DiagnosticsProperty('isLiquid', isLiquid))
      ..add(DiagnosticsProperty('unblindedUrl', unblindedUrl))
      ..add(DiagnosticsProperty('rbfTxIds', rbfTxIds))
      ..add(DiagnosticsProperty('walletId', walletId));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransactionImpl &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.txid, txid) || other.txid == txid) &&
            (identical(other.received, received) ||
                other.received == received) &&
            (identical(other.sent, sent) || other.sent == sent) &&
            (identical(other.fee, fee) || other.fee == fee) &&
            (identical(other.feeRate, feeRate) || other.feeRate == feeRate) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.toAddress, toAddress) ||
                other.toAddress == toAddress) &&
            (identical(other.psbt, psbt) || other.psbt == psbt) &&
            const DeepCollectionEquality().equals(other.pset, pset) &&
            (identical(other.rbfEnabled, rbfEnabled) ||
                other.rbfEnabled == rbfEnabled) &&
            (identical(other.broadcastTime, broadcastTime) ||
                other.broadcastTime == broadcastTime) &&
            const DeepCollectionEquality().equals(other._outAddrs, _outAddrs) &&
            const DeepCollectionEquality().equals(other._inputs, _inputs) &&
            (identical(other.bdkTx, bdkTx) || other.bdkTx == bdkTx) &&
            (identical(other.isSwap, isSwap) || other.isSwap == isSwap) &&
            (identical(other.swapTx, swapTx) || other.swapTx == swapTx) &&
            (identical(other.isLiquid, isLiquid) ||
                other.isLiquid == isLiquid) &&
            (identical(other.unblindedUrl, unblindedUrl) ||
                other.unblindedUrl == unblindedUrl) &&
            const DeepCollectionEquality().equals(other._rbfTxIds, _rbfTxIds) &&
            (identical(other.walletId, walletId) ||
                other.walletId == walletId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        timestamp,
        txid,
        received,
        sent,
        fee,
        feeRate,
        height,
        label,
        toAddress,
        psbt,
        const DeepCollectionEquality().hash(pset),
        rbfEnabled,
        broadcastTime,
        const DeepCollectionEquality().hash(_outAddrs),
        const DeepCollectionEquality().hash(_inputs),
        bdkTx,
        isSwap,
        swapTx,
        isLiquid,
        unblindedUrl,
        const DeepCollectionEquality().hash(_rbfTxIds),
        walletId
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      __$$TransactionImplCopyWithImpl<_$TransactionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TransactionImplToJson(
      this,
    );
  }
}

abstract class _Transaction extends Transaction {
  const factory _Transaction(
      {required final int timestamp,
      required final String txid,
      final int? received,
      final int? sent,
      final int? fee,
      final double? feeRate,
      final int? height,
      final String? label,
      final String? toAddress,
      final String? psbt,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final Uint8List? pset,
      final bool rbfEnabled,
      final int? broadcastTime,
      final List<Address> outAddrs,
      final List<TxIn> inputs,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final bdk.TransactionDetails? bdkTx,
      final bool isSwap,
      final SwapTx? swapTx,
      final bool isLiquid,
      final String unblindedUrl,
      final List<String> rbfTxIds,
      final String? walletId}) = _$TransactionImpl;
  const _Transaction._() : super._();

  factory _Transaction.fromJson(Map<String, dynamic> json) =
      _$TransactionImpl.fromJson;

  @override
  int get timestamp;
  @override
  String get txid;
  @override
  int? get received;
  @override
  int? get sent;
  @override
  int? get fee;
  @override
  double? get feeRate;
  @override
  int? get height;
  @override
  String? get label;
  @override
  String? get toAddress;
  @override
  String? get psbt;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  Uint8List? get pset;
  @override
  bool get rbfEnabled;
  @override // @Default(false) bool oldTx,
  int? get broadcastTime;
  @override // String? serializedTx,
  List<Address> get outAddrs;
  @override
  List<TxIn> get inputs;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.TransactionDetails? get bdkTx;
  @override // Wallet? wallet,
  bool get isSwap;
  @override
  SwapTx? get swapTx;
  @override
  bool get isLiquid;
  @override
  String get unblindedUrl;
  @override
  List<String> get rbfTxIds;
  @override
  String? get walletId;
  @override
  @JsonKey(ignore: true)
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TxIn _$TxInFromJson(Map<String, dynamic> json) {
  return _TxIn.fromJson(json);
}

/// @nodoc
mixin _$TxIn {
  String get prevOut => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TxInCopyWith<TxIn> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TxInCopyWith<$Res> {
  factory $TxInCopyWith(TxIn value, $Res Function(TxIn) then) =
      _$TxInCopyWithImpl<$Res, TxIn>;
  @useResult
  $Res call({String prevOut});
}

/// @nodoc
class _$TxInCopyWithImpl<$Res, $Val extends TxIn>
    implements $TxInCopyWith<$Res> {
  _$TxInCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? prevOut = null,
  }) {
    return _then(_value.copyWith(
      prevOut: null == prevOut
          ? _value.prevOut
          : prevOut // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TxInImplCopyWith<$Res> implements $TxInCopyWith<$Res> {
  factory _$$TxInImplCopyWith(
          _$TxInImpl value, $Res Function(_$TxInImpl) then) =
      __$$TxInImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String prevOut});
}

/// @nodoc
class __$$TxInImplCopyWithImpl<$Res>
    extends _$TxInCopyWithImpl<$Res, _$TxInImpl>
    implements _$$TxInImplCopyWith<$Res> {
  __$$TxInImplCopyWithImpl(_$TxInImpl _value, $Res Function(_$TxInImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? prevOut = null,
  }) {
    return _then(_$TxInImpl(
      prevOut: null == prevOut
          ? _value.prevOut
          : prevOut // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TxInImpl extends _TxIn with DiagnosticableTreeMixin {
  const _$TxInImpl({required this.prevOut}) : super._();

  factory _$TxInImpl.fromJson(Map<String, dynamic> json) =>
      _$$TxInImplFromJson(json);

  @override
  final String prevOut;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'TxIn(prevOut: $prevOut)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'TxIn'))
      ..add(DiagnosticsProperty('prevOut', prevOut));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TxInImpl &&
            (identical(other.prevOut, prevOut) || other.prevOut == prevOut));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, prevOut);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TxInImplCopyWith<_$TxInImpl> get copyWith =>
      __$$TxInImplCopyWithImpl<_$TxInImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TxInImplToJson(
      this,
    );
  }
}

abstract class _TxIn extends TxIn {
  const factory _TxIn({required final String prevOut}) = _$TxInImpl;
  const _TxIn._() : super._();

  factory _TxIn.fromJson(Map<String, dynamic> json) = _$TxInImpl.fromJson;

  @override
  String get prevOut;
  @override
  @JsonKey(ignore: true)
  _$$TxInImplCopyWith<_$TxInImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChainSwapDetails _$ChainSwapDetailsFromJson(Map<String, dynamic> json) {
  return _ChainSwapDetails.fromJson(json);
}

/// @nodoc
mixin _$ChainSwapDetails {
  boltz.ChainSwapDirection get direction => throw _privateConstructorUsedError;
  int get refundKeyIndex => throw _privateConstructorUsedError;
  String get refundSecretKey => throw _privateConstructorUsedError;
  String get refundPublicKey => throw _privateConstructorUsedError;
  int get claimKeyIndex => throw _privateConstructorUsedError;
  String get claimSecretKey => throw _privateConstructorUsedError;
  String get claimPublicKey => throw _privateConstructorUsedError;
  int get lockupLocktime => throw _privateConstructorUsedError;
  int get claimLocktime => throw _privateConstructorUsedError;
  String get btcElectrumUrl => throw _privateConstructorUsedError;
  String get lbtcElectrumUrl => throw _privateConstructorUsedError;
  String get blindingKey => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ChainSwapDetailsCopyWith<ChainSwapDetails> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChainSwapDetailsCopyWith<$Res> {
  factory $ChainSwapDetailsCopyWith(
          ChainSwapDetails value, $Res Function(ChainSwapDetails) then) =
      _$ChainSwapDetailsCopyWithImpl<$Res, ChainSwapDetails>;
  @useResult
  $Res call(
      {boltz.ChainSwapDirection direction,
      int refundKeyIndex,
      String refundSecretKey,
      String refundPublicKey,
      int claimKeyIndex,
      String claimSecretKey,
      String claimPublicKey,
      int lockupLocktime,
      int claimLocktime,
      String btcElectrumUrl,
      String lbtcElectrumUrl,
      String blindingKey});
}

/// @nodoc
class _$ChainSwapDetailsCopyWithImpl<$Res, $Val extends ChainSwapDetails>
    implements $ChainSwapDetailsCopyWith<$Res> {
  _$ChainSwapDetailsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? direction = null,
    Object? refundKeyIndex = null,
    Object? refundSecretKey = null,
    Object? refundPublicKey = null,
    Object? claimKeyIndex = null,
    Object? claimSecretKey = null,
    Object? claimPublicKey = null,
    Object? lockupLocktime = null,
    Object? claimLocktime = null,
    Object? btcElectrumUrl = null,
    Object? lbtcElectrumUrl = null,
    Object? blindingKey = null,
  }) {
    return _then(_value.copyWith(
      direction: null == direction
          ? _value.direction
          : direction // ignore: cast_nullable_to_non_nullable
              as boltz.ChainSwapDirection,
      refundKeyIndex: null == refundKeyIndex
          ? _value.refundKeyIndex
          : refundKeyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      refundSecretKey: null == refundSecretKey
          ? _value.refundSecretKey
          : refundSecretKey // ignore: cast_nullable_to_non_nullable
              as String,
      refundPublicKey: null == refundPublicKey
          ? _value.refundPublicKey
          : refundPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      claimKeyIndex: null == claimKeyIndex
          ? _value.claimKeyIndex
          : claimKeyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      claimSecretKey: null == claimSecretKey
          ? _value.claimSecretKey
          : claimSecretKey // ignore: cast_nullable_to_non_nullable
              as String,
      claimPublicKey: null == claimPublicKey
          ? _value.claimPublicKey
          : claimPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      lockupLocktime: null == lockupLocktime
          ? _value.lockupLocktime
          : lockupLocktime // ignore: cast_nullable_to_non_nullable
              as int,
      claimLocktime: null == claimLocktime
          ? _value.claimLocktime
          : claimLocktime // ignore: cast_nullable_to_non_nullable
              as int,
      btcElectrumUrl: null == btcElectrumUrl
          ? _value.btcElectrumUrl
          : btcElectrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      lbtcElectrumUrl: null == lbtcElectrumUrl
          ? _value.lbtcElectrumUrl
          : lbtcElectrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      blindingKey: null == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChainSwapDetailsImplCopyWith<$Res>
    implements $ChainSwapDetailsCopyWith<$Res> {
  factory _$$ChainSwapDetailsImplCopyWith(_$ChainSwapDetailsImpl value,
          $Res Function(_$ChainSwapDetailsImpl) then) =
      __$$ChainSwapDetailsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {boltz.ChainSwapDirection direction,
      int refundKeyIndex,
      String refundSecretKey,
      String refundPublicKey,
      int claimKeyIndex,
      String claimSecretKey,
      String claimPublicKey,
      int lockupLocktime,
      int claimLocktime,
      String btcElectrumUrl,
      String lbtcElectrumUrl,
      String blindingKey});
}

/// @nodoc
class __$$ChainSwapDetailsImplCopyWithImpl<$Res>
    extends _$ChainSwapDetailsCopyWithImpl<$Res, _$ChainSwapDetailsImpl>
    implements _$$ChainSwapDetailsImplCopyWith<$Res> {
  __$$ChainSwapDetailsImplCopyWithImpl(_$ChainSwapDetailsImpl _value,
      $Res Function(_$ChainSwapDetailsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? direction = null,
    Object? refundKeyIndex = null,
    Object? refundSecretKey = null,
    Object? refundPublicKey = null,
    Object? claimKeyIndex = null,
    Object? claimSecretKey = null,
    Object? claimPublicKey = null,
    Object? lockupLocktime = null,
    Object? claimLocktime = null,
    Object? btcElectrumUrl = null,
    Object? lbtcElectrumUrl = null,
    Object? blindingKey = null,
  }) {
    return _then(_$ChainSwapDetailsImpl(
      direction: null == direction
          ? _value.direction
          : direction // ignore: cast_nullable_to_non_nullable
              as boltz.ChainSwapDirection,
      refundKeyIndex: null == refundKeyIndex
          ? _value.refundKeyIndex
          : refundKeyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      refundSecretKey: null == refundSecretKey
          ? _value.refundSecretKey
          : refundSecretKey // ignore: cast_nullable_to_non_nullable
              as String,
      refundPublicKey: null == refundPublicKey
          ? _value.refundPublicKey
          : refundPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      claimKeyIndex: null == claimKeyIndex
          ? _value.claimKeyIndex
          : claimKeyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      claimSecretKey: null == claimSecretKey
          ? _value.claimSecretKey
          : claimSecretKey // ignore: cast_nullable_to_non_nullable
              as String,
      claimPublicKey: null == claimPublicKey
          ? _value.claimPublicKey
          : claimPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      lockupLocktime: null == lockupLocktime
          ? _value.lockupLocktime
          : lockupLocktime // ignore: cast_nullable_to_non_nullable
              as int,
      claimLocktime: null == claimLocktime
          ? _value.claimLocktime
          : claimLocktime // ignore: cast_nullable_to_non_nullable
              as int,
      btcElectrumUrl: null == btcElectrumUrl
          ? _value.btcElectrumUrl
          : btcElectrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      lbtcElectrumUrl: null == lbtcElectrumUrl
          ? _value.lbtcElectrumUrl
          : lbtcElectrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      blindingKey: null == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChainSwapDetailsImpl extends _ChainSwapDetails
    with DiagnosticableTreeMixin {
  const _$ChainSwapDetailsImpl(
      {required this.direction,
      required this.refundKeyIndex,
      required this.refundSecretKey,
      required this.refundPublicKey,
      required this.claimKeyIndex,
      required this.claimSecretKey,
      required this.claimPublicKey,
      required this.lockupLocktime,
      required this.claimLocktime,
      required this.btcElectrumUrl,
      required this.lbtcElectrumUrl,
      required this.blindingKey})
      : super._();

  factory _$ChainSwapDetailsImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChainSwapDetailsImplFromJson(json);

  @override
  final boltz.ChainSwapDirection direction;
  @override
  final int refundKeyIndex;
  @override
  final String refundSecretKey;
  @override
  final String refundPublicKey;
  @override
  final int claimKeyIndex;
  @override
  final String claimSecretKey;
  @override
  final String claimPublicKey;
  @override
  final int lockupLocktime;
  @override
  final int claimLocktime;
  @override
  final String btcElectrumUrl;
  @override
  final String lbtcElectrumUrl;
  @override
  final String blindingKey;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ChainSwapDetails(direction: $direction, refundKeyIndex: $refundKeyIndex, refundSecretKey: $refundSecretKey, refundPublicKey: $refundPublicKey, claimKeyIndex: $claimKeyIndex, claimSecretKey: $claimSecretKey, claimPublicKey: $claimPublicKey, lockupLocktime: $lockupLocktime, claimLocktime: $claimLocktime, btcElectrumUrl: $btcElectrumUrl, lbtcElectrumUrl: $lbtcElectrumUrl, blindingKey: $blindingKey)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ChainSwapDetails'))
      ..add(DiagnosticsProperty('direction', direction))
      ..add(DiagnosticsProperty('refundKeyIndex', refundKeyIndex))
      ..add(DiagnosticsProperty('refundSecretKey', refundSecretKey))
      ..add(DiagnosticsProperty('refundPublicKey', refundPublicKey))
      ..add(DiagnosticsProperty('claimKeyIndex', claimKeyIndex))
      ..add(DiagnosticsProperty('claimSecretKey', claimSecretKey))
      ..add(DiagnosticsProperty('claimPublicKey', claimPublicKey))
      ..add(DiagnosticsProperty('lockupLocktime', lockupLocktime))
      ..add(DiagnosticsProperty('claimLocktime', claimLocktime))
      ..add(DiagnosticsProperty('btcElectrumUrl', btcElectrumUrl))
      ..add(DiagnosticsProperty('lbtcElectrumUrl', lbtcElectrumUrl))
      ..add(DiagnosticsProperty('blindingKey', blindingKey));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChainSwapDetailsImpl &&
            (identical(other.direction, direction) ||
                other.direction == direction) &&
            (identical(other.refundKeyIndex, refundKeyIndex) ||
                other.refundKeyIndex == refundKeyIndex) &&
            (identical(other.refundSecretKey, refundSecretKey) ||
                other.refundSecretKey == refundSecretKey) &&
            (identical(other.refundPublicKey, refundPublicKey) ||
                other.refundPublicKey == refundPublicKey) &&
            (identical(other.claimKeyIndex, claimKeyIndex) ||
                other.claimKeyIndex == claimKeyIndex) &&
            (identical(other.claimSecretKey, claimSecretKey) ||
                other.claimSecretKey == claimSecretKey) &&
            (identical(other.claimPublicKey, claimPublicKey) ||
                other.claimPublicKey == claimPublicKey) &&
            (identical(other.lockupLocktime, lockupLocktime) ||
                other.lockupLocktime == lockupLocktime) &&
            (identical(other.claimLocktime, claimLocktime) ||
                other.claimLocktime == claimLocktime) &&
            (identical(other.btcElectrumUrl, btcElectrumUrl) ||
                other.btcElectrumUrl == btcElectrumUrl) &&
            (identical(other.lbtcElectrumUrl, lbtcElectrumUrl) ||
                other.lbtcElectrumUrl == lbtcElectrumUrl) &&
            (identical(other.blindingKey, blindingKey) ||
                other.blindingKey == blindingKey));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      direction,
      refundKeyIndex,
      refundSecretKey,
      refundPublicKey,
      claimKeyIndex,
      claimSecretKey,
      claimPublicKey,
      lockupLocktime,
      claimLocktime,
      btcElectrumUrl,
      lbtcElectrumUrl,
      blindingKey);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChainSwapDetailsImplCopyWith<_$ChainSwapDetailsImpl> get copyWith =>
      __$$ChainSwapDetailsImplCopyWithImpl<_$ChainSwapDetailsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChainSwapDetailsImplToJson(
      this,
    );
  }
}

abstract class _ChainSwapDetails extends ChainSwapDetails {
  const factory _ChainSwapDetails(
      {required final boltz.ChainSwapDirection direction,
      required final int refundKeyIndex,
      required final String refundSecretKey,
      required final String refundPublicKey,
      required final int claimKeyIndex,
      required final String claimSecretKey,
      required final String claimPublicKey,
      required final int lockupLocktime,
      required final int claimLocktime,
      required final String btcElectrumUrl,
      required final String lbtcElectrumUrl,
      required final String blindingKey}) = _$ChainSwapDetailsImpl;
  const _ChainSwapDetails._() : super._();

  factory _ChainSwapDetails.fromJson(Map<String, dynamic> json) =
      _$ChainSwapDetailsImpl.fromJson;

  @override
  boltz.ChainSwapDirection get direction;
  @override
  int get refundKeyIndex;
  @override
  String get refundSecretKey;
  @override
  String get refundPublicKey;
  @override
  int get claimKeyIndex;
  @override
  String get claimSecretKey;
  @override
  String get claimPublicKey;
  @override
  int get lockupLocktime;
  @override
  int get claimLocktime;
  @override
  String get btcElectrumUrl;
  @override
  String get lbtcElectrumUrl;
  @override
  String get blindingKey;
  @override
  @JsonKey(ignore: true)
  _$$ChainSwapDetailsImplCopyWith<_$ChainSwapDetailsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LnSwapDetails _$LnSwapDetailsFromJson(Map<String, dynamic> json) {
  return _LnSwapDetails.fromJson(json);
}

/// @nodoc
mixin _$LnSwapDetails {
  boltz.SwapType get swapType => throw _privateConstructorUsedError;
  String get invoice => throw _privateConstructorUsedError;
  String get boltzPubKey => throw _privateConstructorUsedError;
  int get keyIndex => throw _privateConstructorUsedError;
  String get mySecretKey => throw _privateConstructorUsedError;
  String get myPublicKey => throw _privateConstructorUsedError;
  String get sha256 => throw _privateConstructorUsedError;
  String get electrumUrl => throw _privateConstructorUsedError;
  int get locktime => throw _privateConstructorUsedError;
  String? get hash160 => throw _privateConstructorUsedError;
  String? get blindingKey => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $LnSwapDetailsCopyWith<LnSwapDetails> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LnSwapDetailsCopyWith<$Res> {
  factory $LnSwapDetailsCopyWith(
          LnSwapDetails value, $Res Function(LnSwapDetails) then) =
      _$LnSwapDetailsCopyWithImpl<$Res, LnSwapDetails>;
  @useResult
  $Res call(
      {boltz.SwapType swapType,
      String invoice,
      String boltzPubKey,
      int keyIndex,
      String mySecretKey,
      String myPublicKey,
      String sha256,
      String electrumUrl,
      int locktime,
      String? hash160,
      String? blindingKey});
}

/// @nodoc
class _$LnSwapDetailsCopyWithImpl<$Res, $Val extends LnSwapDetails>
    implements $LnSwapDetailsCopyWith<$Res> {
  _$LnSwapDetailsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? swapType = null,
    Object? invoice = null,
    Object? boltzPubKey = null,
    Object? keyIndex = null,
    Object? mySecretKey = null,
    Object? myPublicKey = null,
    Object? sha256 = null,
    Object? electrumUrl = null,
    Object? locktime = null,
    Object? hash160 = freezed,
    Object? blindingKey = freezed,
  }) {
    return _then(_value.copyWith(
      swapType: null == swapType
          ? _value.swapType
          : swapType // ignore: cast_nullable_to_non_nullable
              as boltz.SwapType,
      invoice: null == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as String,
      boltzPubKey: null == boltzPubKey
          ? _value.boltzPubKey
          : boltzPubKey // ignore: cast_nullable_to_non_nullable
              as String,
      keyIndex: null == keyIndex
          ? _value.keyIndex
          : keyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      mySecretKey: null == mySecretKey
          ? _value.mySecretKey
          : mySecretKey // ignore: cast_nullable_to_non_nullable
              as String,
      myPublicKey: null == myPublicKey
          ? _value.myPublicKey
          : myPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      sha256: null == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String,
      electrumUrl: null == electrumUrl
          ? _value.electrumUrl
          : electrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      locktime: null == locktime
          ? _value.locktime
          : locktime // ignore: cast_nullable_to_non_nullable
              as int,
      hash160: freezed == hash160
          ? _value.hash160
          : hash160 // ignore: cast_nullable_to_non_nullable
              as String?,
      blindingKey: freezed == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LnSwapDetailsImplCopyWith<$Res>
    implements $LnSwapDetailsCopyWith<$Res> {
  factory _$$LnSwapDetailsImplCopyWith(
          _$LnSwapDetailsImpl value, $Res Function(_$LnSwapDetailsImpl) then) =
      __$$LnSwapDetailsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {boltz.SwapType swapType,
      String invoice,
      String boltzPubKey,
      int keyIndex,
      String mySecretKey,
      String myPublicKey,
      String sha256,
      String electrumUrl,
      int locktime,
      String? hash160,
      String? blindingKey});
}

/// @nodoc
class __$$LnSwapDetailsImplCopyWithImpl<$Res>
    extends _$LnSwapDetailsCopyWithImpl<$Res, _$LnSwapDetailsImpl>
    implements _$$LnSwapDetailsImplCopyWith<$Res> {
  __$$LnSwapDetailsImplCopyWithImpl(
      _$LnSwapDetailsImpl _value, $Res Function(_$LnSwapDetailsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? swapType = null,
    Object? invoice = null,
    Object? boltzPubKey = null,
    Object? keyIndex = null,
    Object? mySecretKey = null,
    Object? myPublicKey = null,
    Object? sha256 = null,
    Object? electrumUrl = null,
    Object? locktime = null,
    Object? hash160 = freezed,
    Object? blindingKey = freezed,
  }) {
    return _then(_$LnSwapDetailsImpl(
      swapType: null == swapType
          ? _value.swapType
          : swapType // ignore: cast_nullable_to_non_nullable
              as boltz.SwapType,
      invoice: null == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as String,
      boltzPubKey: null == boltzPubKey
          ? _value.boltzPubKey
          : boltzPubKey // ignore: cast_nullable_to_non_nullable
              as String,
      keyIndex: null == keyIndex
          ? _value.keyIndex
          : keyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      mySecretKey: null == mySecretKey
          ? _value.mySecretKey
          : mySecretKey // ignore: cast_nullable_to_non_nullable
              as String,
      myPublicKey: null == myPublicKey
          ? _value.myPublicKey
          : myPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      sha256: null == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String,
      electrumUrl: null == electrumUrl
          ? _value.electrumUrl
          : electrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      locktime: null == locktime
          ? _value.locktime
          : locktime // ignore: cast_nullable_to_non_nullable
              as int,
      hash160: freezed == hash160
          ? _value.hash160
          : hash160 // ignore: cast_nullable_to_non_nullable
              as String?,
      blindingKey: freezed == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LnSwapDetailsImpl extends _LnSwapDetails with DiagnosticableTreeMixin {
  const _$LnSwapDetailsImpl(
      {required this.swapType,
      required this.invoice,
      required this.boltzPubKey,
      required this.keyIndex,
      required this.mySecretKey,
      required this.myPublicKey,
      required this.sha256,
      required this.electrumUrl,
      required this.locktime,
      this.hash160,
      this.blindingKey})
      : super._();

  factory _$LnSwapDetailsImpl.fromJson(Map<String, dynamic> json) =>
      _$$LnSwapDetailsImplFromJson(json);

  @override
  final boltz.SwapType swapType;
  @override
  final String invoice;
  @override
  final String boltzPubKey;
  @override
  final int keyIndex;
  @override
  final String mySecretKey;
  @override
  final String myPublicKey;
  @override
  final String sha256;
  @override
  final String electrumUrl;
  @override
  final int locktime;
  @override
  final String? hash160;
  @override
  final String? blindingKey;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'LnSwapDetails(swapType: $swapType, invoice: $invoice, boltzPubKey: $boltzPubKey, keyIndex: $keyIndex, mySecretKey: $mySecretKey, myPublicKey: $myPublicKey, sha256: $sha256, electrumUrl: $electrumUrl, locktime: $locktime, hash160: $hash160, blindingKey: $blindingKey)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'LnSwapDetails'))
      ..add(DiagnosticsProperty('swapType', swapType))
      ..add(DiagnosticsProperty('invoice', invoice))
      ..add(DiagnosticsProperty('boltzPubKey', boltzPubKey))
      ..add(DiagnosticsProperty('keyIndex', keyIndex))
      ..add(DiagnosticsProperty('mySecretKey', mySecretKey))
      ..add(DiagnosticsProperty('myPublicKey', myPublicKey))
      ..add(DiagnosticsProperty('sha256', sha256))
      ..add(DiagnosticsProperty('electrumUrl', electrumUrl))
      ..add(DiagnosticsProperty('locktime', locktime))
      ..add(DiagnosticsProperty('hash160', hash160))
      ..add(DiagnosticsProperty('blindingKey', blindingKey));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LnSwapDetailsImpl &&
            (identical(other.swapType, swapType) ||
                other.swapType == swapType) &&
            (identical(other.invoice, invoice) || other.invoice == invoice) &&
            (identical(other.boltzPubKey, boltzPubKey) ||
                other.boltzPubKey == boltzPubKey) &&
            (identical(other.keyIndex, keyIndex) ||
                other.keyIndex == keyIndex) &&
            (identical(other.mySecretKey, mySecretKey) ||
                other.mySecretKey == mySecretKey) &&
            (identical(other.myPublicKey, myPublicKey) ||
                other.myPublicKey == myPublicKey) &&
            (identical(other.sha256, sha256) || other.sha256 == sha256) &&
            (identical(other.electrumUrl, electrumUrl) ||
                other.electrumUrl == electrumUrl) &&
            (identical(other.locktime, locktime) ||
                other.locktime == locktime) &&
            (identical(other.hash160, hash160) || other.hash160 == hash160) &&
            (identical(other.blindingKey, blindingKey) ||
                other.blindingKey == blindingKey));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      swapType,
      invoice,
      boltzPubKey,
      keyIndex,
      mySecretKey,
      myPublicKey,
      sha256,
      electrumUrl,
      locktime,
      hash160,
      blindingKey);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$LnSwapDetailsImplCopyWith<_$LnSwapDetailsImpl> get copyWith =>
      __$$LnSwapDetailsImplCopyWithImpl<_$LnSwapDetailsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LnSwapDetailsImplToJson(
      this,
    );
  }
}

abstract class _LnSwapDetails extends LnSwapDetails {
  const factory _LnSwapDetails(
      {required final boltz.SwapType swapType,
      required final String invoice,
      required final String boltzPubKey,
      required final int keyIndex,
      required final String mySecretKey,
      required final String myPublicKey,
      required final String sha256,
      required final String electrumUrl,
      required final int locktime,
      final String? hash160,
      final String? blindingKey}) = _$LnSwapDetailsImpl;
  const _LnSwapDetails._() : super._();

  factory _LnSwapDetails.fromJson(Map<String, dynamic> json) =
      _$LnSwapDetailsImpl.fromJson;

  @override
  boltz.SwapType get swapType;
  @override
  String get invoice;
  @override
  String get boltzPubKey;
  @override
  int get keyIndex;
  @override
  String get mySecretKey;
  @override
  String get myPublicKey;
  @override
  String get sha256;
  @override
  String get electrumUrl;
  @override
  int get locktime;
  @override
  String? get hash160;
  @override
  String? get blindingKey;
  @override
  @JsonKey(ignore: true)
  _$$LnSwapDetailsImplCopyWith<_$LnSwapDetailsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SwapTx _$SwapTxFromJson(Map<String, dynamic> json) {
  return _SwapTx.fromJson(json);
}

/// @nodoc
mixin _$SwapTx {
  String get id => throw _privateConstructorUsedError;
  BBNetwork get network => throw _privateConstructorUsedError;
  BaseWalletType get baseWalletType => throw _privateConstructorUsedError;
  int get outAmount => throw _privateConstructorUsedError;
  String get scriptAddress => throw _privateConstructorUsedError;
  String get boltzUrl => throw _privateConstructorUsedError;
  ChainSwapDetails? get chainSwapDetails => throw _privateConstructorUsedError;
  LnSwapDetails? get lnSwapDetails => throw _privateConstructorUsedError;
  String? get txid => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  boltz.SwapStreamStatus? get status =>
      throw _privateConstructorUsedError; // should this be SwapStaus?
  int? get boltzFees => throw _privateConstructorUsedError;
  int? get lockupFees => throw _privateConstructorUsedError;
  int? get claimFees => throw _privateConstructorUsedError;
  String? get claimAddress => throw _privateConstructorUsedError;
  DateTime? get creationTime => throw _privateConstructorUsedError;
  DateTime? get completionTime => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SwapTxCopyWith<SwapTx> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SwapTxCopyWith<$Res> {
  factory $SwapTxCopyWith(SwapTx value, $Res Function(SwapTx) then) =
      _$SwapTxCopyWithImpl<$Res, SwapTx>;
  @useResult
  $Res call(
      {String id,
      BBNetwork network,
      BaseWalletType baseWalletType,
      int outAmount,
      String scriptAddress,
      String boltzUrl,
      ChainSwapDetails? chainSwapDetails,
      LnSwapDetails? lnSwapDetails,
      String? txid,
      String? label,
      boltz.SwapStreamStatus? status,
      int? boltzFees,
      int? lockupFees,
      int? claimFees,
      String? claimAddress,
      DateTime? creationTime,
      DateTime? completionTime});

  $ChainSwapDetailsCopyWith<$Res>? get chainSwapDetails;
  $LnSwapDetailsCopyWith<$Res>? get lnSwapDetails;
  $SwapStreamStatusCopyWith<$Res>? get status;
}

/// @nodoc
class _$SwapTxCopyWithImpl<$Res, $Val extends SwapTx>
    implements $SwapTxCopyWith<$Res> {
  _$SwapTxCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? network = null,
    Object? baseWalletType = null,
    Object? outAmount = null,
    Object? scriptAddress = null,
    Object? boltzUrl = null,
    Object? chainSwapDetails = freezed,
    Object? lnSwapDetails = freezed,
    Object? txid = freezed,
    Object? label = freezed,
    Object? status = freezed,
    Object? boltzFees = freezed,
    Object? lockupFees = freezed,
    Object? claimFees = freezed,
    Object? claimAddress = freezed,
    Object? creationTime = freezed,
    Object? completionTime = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as BBNetwork,
      baseWalletType: null == baseWalletType
          ? _value.baseWalletType
          : baseWalletType // ignore: cast_nullable_to_non_nullable
              as BaseWalletType,
      outAmount: null == outAmount
          ? _value.outAmount
          : outAmount // ignore: cast_nullable_to_non_nullable
              as int,
      scriptAddress: null == scriptAddress
          ? _value.scriptAddress
          : scriptAddress // ignore: cast_nullable_to_non_nullable
              as String,
      boltzUrl: null == boltzUrl
          ? _value.boltzUrl
          : boltzUrl // ignore: cast_nullable_to_non_nullable
              as String,
      chainSwapDetails: freezed == chainSwapDetails
          ? _value.chainSwapDetails
          : chainSwapDetails // ignore: cast_nullable_to_non_nullable
              as ChainSwapDetails?,
      lnSwapDetails: freezed == lnSwapDetails
          ? _value.lnSwapDetails
          : lnSwapDetails // ignore: cast_nullable_to_non_nullable
              as LnSwapDetails?,
      txid: freezed == txid
          ? _value.txid
          : txid // ignore: cast_nullable_to_non_nullable
              as String?,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as boltz.SwapStreamStatus?,
      boltzFees: freezed == boltzFees
          ? _value.boltzFees
          : boltzFees // ignore: cast_nullable_to_non_nullable
              as int?,
      lockupFees: freezed == lockupFees
          ? _value.lockupFees
          : lockupFees // ignore: cast_nullable_to_non_nullable
              as int?,
      claimFees: freezed == claimFees
          ? _value.claimFees
          : claimFees // ignore: cast_nullable_to_non_nullable
              as int?,
      claimAddress: freezed == claimAddress
          ? _value.claimAddress
          : claimAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      creationTime: freezed == creationTime
          ? _value.creationTime
          : creationTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completionTime: freezed == completionTime
          ? _value.completionTime
          : completionTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $ChainSwapDetailsCopyWith<$Res>? get chainSwapDetails {
    if (_value.chainSwapDetails == null) {
      return null;
    }

    return $ChainSwapDetailsCopyWith<$Res>(_value.chainSwapDetails!, (value) {
      return _then(_value.copyWith(chainSwapDetails: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $LnSwapDetailsCopyWith<$Res>? get lnSwapDetails {
    if (_value.lnSwapDetails == null) {
      return null;
    }

    return $LnSwapDetailsCopyWith<$Res>(_value.lnSwapDetails!, (value) {
      return _then(_value.copyWith(lnSwapDetails: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $SwapStreamStatusCopyWith<$Res>? get status {
    if (_value.status == null) {
      return null;
    }

    return $SwapStreamStatusCopyWith<$Res>(_value.status!, (value) {
      return _then(_value.copyWith(status: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SwapTxImplCopyWith<$Res> implements $SwapTxCopyWith<$Res> {
  factory _$$SwapTxImplCopyWith(
          _$SwapTxImpl value, $Res Function(_$SwapTxImpl) then) =
      __$$SwapTxImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      BBNetwork network,
      BaseWalletType baseWalletType,
      int outAmount,
      String scriptAddress,
      String boltzUrl,
      ChainSwapDetails? chainSwapDetails,
      LnSwapDetails? lnSwapDetails,
      String? txid,
      String? label,
      boltz.SwapStreamStatus? status,
      int? boltzFees,
      int? lockupFees,
      int? claimFees,
      String? claimAddress,
      DateTime? creationTime,
      DateTime? completionTime});

  @override
  $ChainSwapDetailsCopyWith<$Res>? get chainSwapDetails;
  @override
  $LnSwapDetailsCopyWith<$Res>? get lnSwapDetails;
  @override
  $SwapStreamStatusCopyWith<$Res>? get status;
}

/// @nodoc
class __$$SwapTxImplCopyWithImpl<$Res>
    extends _$SwapTxCopyWithImpl<$Res, _$SwapTxImpl>
    implements _$$SwapTxImplCopyWith<$Res> {
  __$$SwapTxImplCopyWithImpl(
      _$SwapTxImpl _value, $Res Function(_$SwapTxImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? network = null,
    Object? baseWalletType = null,
    Object? outAmount = null,
    Object? scriptAddress = null,
    Object? boltzUrl = null,
    Object? chainSwapDetails = freezed,
    Object? lnSwapDetails = freezed,
    Object? txid = freezed,
    Object? label = freezed,
    Object? status = freezed,
    Object? boltzFees = freezed,
    Object? lockupFees = freezed,
    Object? claimFees = freezed,
    Object? claimAddress = freezed,
    Object? creationTime = freezed,
    Object? completionTime = freezed,
  }) {
    return _then(_$SwapTxImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as BBNetwork,
      baseWalletType: null == baseWalletType
          ? _value.baseWalletType
          : baseWalletType // ignore: cast_nullable_to_non_nullable
              as BaseWalletType,
      outAmount: null == outAmount
          ? _value.outAmount
          : outAmount // ignore: cast_nullable_to_non_nullable
              as int,
      scriptAddress: null == scriptAddress
          ? _value.scriptAddress
          : scriptAddress // ignore: cast_nullable_to_non_nullable
              as String,
      boltzUrl: null == boltzUrl
          ? _value.boltzUrl
          : boltzUrl // ignore: cast_nullable_to_non_nullable
              as String,
      chainSwapDetails: freezed == chainSwapDetails
          ? _value.chainSwapDetails
          : chainSwapDetails // ignore: cast_nullable_to_non_nullable
              as ChainSwapDetails?,
      lnSwapDetails: freezed == lnSwapDetails
          ? _value.lnSwapDetails
          : lnSwapDetails // ignore: cast_nullable_to_non_nullable
              as LnSwapDetails?,
      txid: freezed == txid
          ? _value.txid
          : txid // ignore: cast_nullable_to_non_nullable
              as String?,
      label: freezed == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as boltz.SwapStreamStatus?,
      boltzFees: freezed == boltzFees
          ? _value.boltzFees
          : boltzFees // ignore: cast_nullable_to_non_nullable
              as int?,
      lockupFees: freezed == lockupFees
          ? _value.lockupFees
          : lockupFees // ignore: cast_nullable_to_non_nullable
              as int?,
      claimFees: freezed == claimFees
          ? _value.claimFees
          : claimFees // ignore: cast_nullable_to_non_nullable
              as int?,
      claimAddress: freezed == claimAddress
          ? _value.claimAddress
          : claimAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      creationTime: freezed == creationTime
          ? _value.creationTime
          : creationTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completionTime: freezed == completionTime
          ? _value.completionTime
          : completionTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SwapTxImpl extends _SwapTx with DiagnosticableTreeMixin {
  const _$SwapTxImpl(
      {required this.id,
      required this.network,
      required this.baseWalletType,
      required this.outAmount,
      required this.scriptAddress,
      required this.boltzUrl,
      this.chainSwapDetails,
      this.lnSwapDetails,
      this.txid,
      this.label,
      this.status,
      this.boltzFees,
      this.lockupFees,
      this.claimFees,
      this.claimAddress,
      this.creationTime,
      this.completionTime})
      : super._();

  factory _$SwapTxImpl.fromJson(Map<String, dynamic> json) =>
      _$$SwapTxImplFromJson(json);

  @override
  final String id;
  @override
  final BBNetwork network;
  @override
  final BaseWalletType baseWalletType;
  @override
  final int outAmount;
  @override
  final String scriptAddress;
  @override
  final String boltzUrl;
  @override
  final ChainSwapDetails? chainSwapDetails;
  @override
  final LnSwapDetails? lnSwapDetails;
  @override
  final String? txid;
  @override
  final String? label;
  @override
  final boltz.SwapStreamStatus? status;
// should this be SwapStaus?
  @override
  final int? boltzFees;
  @override
  final int? lockupFees;
  @override
  final int? claimFees;
  @override
  final String? claimAddress;
  @override
  final DateTime? creationTime;
  @override
  final DateTime? completionTime;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'SwapTx(id: $id, network: $network, baseWalletType: $baseWalletType, outAmount: $outAmount, scriptAddress: $scriptAddress, boltzUrl: $boltzUrl, chainSwapDetails: $chainSwapDetails, lnSwapDetails: $lnSwapDetails, txid: $txid, label: $label, status: $status, boltzFees: $boltzFees, lockupFees: $lockupFees, claimFees: $claimFees, claimAddress: $claimAddress, creationTime: $creationTime, completionTime: $completionTime)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'SwapTx'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('network', network))
      ..add(DiagnosticsProperty('baseWalletType', baseWalletType))
      ..add(DiagnosticsProperty('outAmount', outAmount))
      ..add(DiagnosticsProperty('scriptAddress', scriptAddress))
      ..add(DiagnosticsProperty('boltzUrl', boltzUrl))
      ..add(DiagnosticsProperty('chainSwapDetails', chainSwapDetails))
      ..add(DiagnosticsProperty('lnSwapDetails', lnSwapDetails))
      ..add(DiagnosticsProperty('txid', txid))
      ..add(DiagnosticsProperty('label', label))
      ..add(DiagnosticsProperty('status', status))
      ..add(DiagnosticsProperty('boltzFees', boltzFees))
      ..add(DiagnosticsProperty('lockupFees', lockupFees))
      ..add(DiagnosticsProperty('claimFees', claimFees))
      ..add(DiagnosticsProperty('claimAddress', claimAddress))
      ..add(DiagnosticsProperty('creationTime', creationTime))
      ..add(DiagnosticsProperty('completionTime', completionTime));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SwapTxImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.baseWalletType, baseWalletType) ||
                other.baseWalletType == baseWalletType) &&
            (identical(other.outAmount, outAmount) ||
                other.outAmount == outAmount) &&
            (identical(other.scriptAddress, scriptAddress) ||
                other.scriptAddress == scriptAddress) &&
            (identical(other.boltzUrl, boltzUrl) ||
                other.boltzUrl == boltzUrl) &&
            (identical(other.chainSwapDetails, chainSwapDetails) ||
                other.chainSwapDetails == chainSwapDetails) &&
            (identical(other.lnSwapDetails, lnSwapDetails) ||
                other.lnSwapDetails == lnSwapDetails) &&
            (identical(other.txid, txid) || other.txid == txid) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.boltzFees, boltzFees) ||
                other.boltzFees == boltzFees) &&
            (identical(other.lockupFees, lockupFees) ||
                other.lockupFees == lockupFees) &&
            (identical(other.claimFees, claimFees) ||
                other.claimFees == claimFees) &&
            (identical(other.claimAddress, claimAddress) ||
                other.claimAddress == claimAddress) &&
            (identical(other.creationTime, creationTime) ||
                other.creationTime == creationTime) &&
            (identical(other.completionTime, completionTime) ||
                other.completionTime == completionTime));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      network,
      baseWalletType,
      outAmount,
      scriptAddress,
      boltzUrl,
      chainSwapDetails,
      lnSwapDetails,
      txid,
      label,
      status,
      boltzFees,
      lockupFees,
      claimFees,
      claimAddress,
      creationTime,
      completionTime);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SwapTxImplCopyWith<_$SwapTxImpl> get copyWith =>
      __$$SwapTxImplCopyWithImpl<_$SwapTxImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SwapTxImplToJson(
      this,
    );
  }
}

abstract class _SwapTx extends SwapTx {
  const factory _SwapTx(
      {required final String id,
      required final BBNetwork network,
      required final BaseWalletType baseWalletType,
      required final int outAmount,
      required final String scriptAddress,
      required final String boltzUrl,
      final ChainSwapDetails? chainSwapDetails,
      final LnSwapDetails? lnSwapDetails,
      final String? txid,
      final String? label,
      final boltz.SwapStreamStatus? status,
      final int? boltzFees,
      final int? lockupFees,
      final int? claimFees,
      final String? claimAddress,
      final DateTime? creationTime,
      final DateTime? completionTime}) = _$SwapTxImpl;
  const _SwapTx._() : super._();

  factory _SwapTx.fromJson(Map<String, dynamic> json) = _$SwapTxImpl.fromJson;

  @override
  String get id;
  @override
  BBNetwork get network;
  @override
  BaseWalletType get baseWalletType;
  @override
  int get outAmount;
  @override
  String get scriptAddress;
  @override
  String get boltzUrl;
  @override
  ChainSwapDetails? get chainSwapDetails;
  @override
  LnSwapDetails? get lnSwapDetails;
  @override
  String? get txid;
  @override
  String? get label;
  @override
  boltz.SwapStreamStatus? get status;
  @override // should this be SwapStaus?
  int? get boltzFees;
  @override
  int? get lockupFees;
  @override
  int? get claimFees;
  @override
  String? get claimAddress;
  @override
  DateTime? get creationTime;
  @override
  DateTime? get completionTime;
  @override
  @JsonKey(ignore: true)
  _$$SwapTxImplCopyWith<_$SwapTxImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LnSwapTxSensitive _$LnSwapTxSensitiveFromJson(Map<String, dynamic> json) {
  return _LnSwapTxSensitive.fromJson(json);
}

/// @nodoc
mixin _$LnSwapTxSensitive {
  String get id => throw _privateConstructorUsedError;
  String get secretKey => throw _privateConstructorUsedError;
  String get publicKey => throw _privateConstructorUsedError;
  String get preimage => throw _privateConstructorUsedError;
  String get sha256 => throw _privateConstructorUsedError;
  String get hash160 => throw _privateConstructorUsedError;
  String? get boltzPubkey => throw _privateConstructorUsedError;
  bool? get isSubmarine => throw _privateConstructorUsedError;
  String? get scriptAddress => throw _privateConstructorUsedError;
  int? get locktime => throw _privateConstructorUsedError;
  String? get blindingKey => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $LnSwapTxSensitiveCopyWith<LnSwapTxSensitive> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LnSwapTxSensitiveCopyWith<$Res> {
  factory $LnSwapTxSensitiveCopyWith(
          LnSwapTxSensitive value, $Res Function(LnSwapTxSensitive) then) =
      _$LnSwapTxSensitiveCopyWithImpl<$Res, LnSwapTxSensitive>;
  @useResult
  $Res call(
      {String id,
      String secretKey,
      String publicKey,
      String preimage,
      String sha256,
      String hash160,
      String? boltzPubkey,
      bool? isSubmarine,
      String? scriptAddress,
      int? locktime,
      String? blindingKey});
}

/// @nodoc
class _$LnSwapTxSensitiveCopyWithImpl<$Res, $Val extends LnSwapTxSensitive>
    implements $LnSwapTxSensitiveCopyWith<$Res> {
  _$LnSwapTxSensitiveCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? secretKey = null,
    Object? publicKey = null,
    Object? preimage = null,
    Object? sha256 = null,
    Object? hash160 = null,
    Object? boltzPubkey = freezed,
    Object? isSubmarine = freezed,
    Object? scriptAddress = freezed,
    Object? locktime = freezed,
    Object? blindingKey = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      secretKey: null == secretKey
          ? _value.secretKey
          : secretKey // ignore: cast_nullable_to_non_nullable
              as String,
      publicKey: null == publicKey
          ? _value.publicKey
          : publicKey // ignore: cast_nullable_to_non_nullable
              as String,
      preimage: null == preimage
          ? _value.preimage
          : preimage // ignore: cast_nullable_to_non_nullable
              as String,
      sha256: null == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String,
      hash160: null == hash160
          ? _value.hash160
          : hash160 // ignore: cast_nullable_to_non_nullable
              as String,
      boltzPubkey: freezed == boltzPubkey
          ? _value.boltzPubkey
          : boltzPubkey // ignore: cast_nullable_to_non_nullable
              as String?,
      isSubmarine: freezed == isSubmarine
          ? _value.isSubmarine
          : isSubmarine // ignore: cast_nullable_to_non_nullable
              as bool?,
      scriptAddress: freezed == scriptAddress
          ? _value.scriptAddress
          : scriptAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      locktime: freezed == locktime
          ? _value.locktime
          : locktime // ignore: cast_nullable_to_non_nullable
              as int?,
      blindingKey: freezed == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LnSwapTxSensitiveImplCopyWith<$Res>
    implements $LnSwapTxSensitiveCopyWith<$Res> {
  factory _$$LnSwapTxSensitiveImplCopyWith(_$LnSwapTxSensitiveImpl value,
          $Res Function(_$LnSwapTxSensitiveImpl) then) =
      __$$LnSwapTxSensitiveImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String secretKey,
      String publicKey,
      String preimage,
      String sha256,
      String hash160,
      String? boltzPubkey,
      bool? isSubmarine,
      String? scriptAddress,
      int? locktime,
      String? blindingKey});
}

/// @nodoc
class __$$LnSwapTxSensitiveImplCopyWithImpl<$Res>
    extends _$LnSwapTxSensitiveCopyWithImpl<$Res, _$LnSwapTxSensitiveImpl>
    implements _$$LnSwapTxSensitiveImplCopyWith<$Res> {
  __$$LnSwapTxSensitiveImplCopyWithImpl(_$LnSwapTxSensitiveImpl _value,
      $Res Function(_$LnSwapTxSensitiveImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? secretKey = null,
    Object? publicKey = null,
    Object? preimage = null,
    Object? sha256 = null,
    Object? hash160 = null,
    Object? boltzPubkey = freezed,
    Object? isSubmarine = freezed,
    Object? scriptAddress = freezed,
    Object? locktime = freezed,
    Object? blindingKey = freezed,
  }) {
    return _then(_$LnSwapTxSensitiveImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      secretKey: null == secretKey
          ? _value.secretKey
          : secretKey // ignore: cast_nullable_to_non_nullable
              as String,
      publicKey: null == publicKey
          ? _value.publicKey
          : publicKey // ignore: cast_nullable_to_non_nullable
              as String,
      preimage: null == preimage
          ? _value.preimage
          : preimage // ignore: cast_nullable_to_non_nullable
              as String,
      sha256: null == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String,
      hash160: null == hash160
          ? _value.hash160
          : hash160 // ignore: cast_nullable_to_non_nullable
              as String,
      boltzPubkey: freezed == boltzPubkey
          ? _value.boltzPubkey
          : boltzPubkey // ignore: cast_nullable_to_non_nullable
              as String?,
      isSubmarine: freezed == isSubmarine
          ? _value.isSubmarine
          : isSubmarine // ignore: cast_nullable_to_non_nullable
              as bool?,
      scriptAddress: freezed == scriptAddress
          ? _value.scriptAddress
          : scriptAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      locktime: freezed == locktime
          ? _value.locktime
          : locktime // ignore: cast_nullable_to_non_nullable
              as int?,
      blindingKey: freezed == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LnSwapTxSensitiveImpl extends _LnSwapTxSensitive
    with DiagnosticableTreeMixin {
  const _$LnSwapTxSensitiveImpl(
      {required this.id,
      required this.secretKey,
      required this.publicKey,
      required this.preimage,
      required this.sha256,
      required this.hash160,
      this.boltzPubkey,
      this.isSubmarine,
      this.scriptAddress,
      this.locktime,
      this.blindingKey})
      : super._();

  factory _$LnSwapTxSensitiveImpl.fromJson(Map<String, dynamic> json) =>
      _$$LnSwapTxSensitiveImplFromJson(json);

  @override
  final String id;
  @override
  final String secretKey;
  @override
  final String publicKey;
  @override
  final String preimage;
  @override
  final String sha256;
  @override
  final String hash160;
  @override
  final String? boltzPubkey;
  @override
  final bool? isSubmarine;
  @override
  final String? scriptAddress;
  @override
  final int? locktime;
  @override
  final String? blindingKey;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'LnSwapTxSensitive(id: $id, secretKey: $secretKey, publicKey: $publicKey, preimage: $preimage, sha256: $sha256, hash160: $hash160, boltzPubkey: $boltzPubkey, isSubmarine: $isSubmarine, scriptAddress: $scriptAddress, locktime: $locktime, blindingKey: $blindingKey)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'LnSwapTxSensitive'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('secretKey', secretKey))
      ..add(DiagnosticsProperty('publicKey', publicKey))
      ..add(DiagnosticsProperty('preimage', preimage))
      ..add(DiagnosticsProperty('sha256', sha256))
      ..add(DiagnosticsProperty('hash160', hash160))
      ..add(DiagnosticsProperty('boltzPubkey', boltzPubkey))
      ..add(DiagnosticsProperty('isSubmarine', isSubmarine))
      ..add(DiagnosticsProperty('scriptAddress', scriptAddress))
      ..add(DiagnosticsProperty('locktime', locktime))
      ..add(DiagnosticsProperty('blindingKey', blindingKey));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LnSwapTxSensitiveImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.secretKey, secretKey) ||
                other.secretKey == secretKey) &&
            (identical(other.publicKey, publicKey) ||
                other.publicKey == publicKey) &&
            (identical(other.preimage, preimage) ||
                other.preimage == preimage) &&
            (identical(other.sha256, sha256) || other.sha256 == sha256) &&
            (identical(other.hash160, hash160) || other.hash160 == hash160) &&
            (identical(other.boltzPubkey, boltzPubkey) ||
                other.boltzPubkey == boltzPubkey) &&
            (identical(other.isSubmarine, isSubmarine) ||
                other.isSubmarine == isSubmarine) &&
            (identical(other.scriptAddress, scriptAddress) ||
                other.scriptAddress == scriptAddress) &&
            (identical(other.locktime, locktime) ||
                other.locktime == locktime) &&
            (identical(other.blindingKey, blindingKey) ||
                other.blindingKey == blindingKey));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      secretKey,
      publicKey,
      preimage,
      sha256,
      hash160,
      boltzPubkey,
      isSubmarine,
      scriptAddress,
      locktime,
      blindingKey);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$LnSwapTxSensitiveImplCopyWith<_$LnSwapTxSensitiveImpl> get copyWith =>
      __$$LnSwapTxSensitiveImplCopyWithImpl<_$LnSwapTxSensitiveImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LnSwapTxSensitiveImplToJson(
      this,
    );
  }
}

abstract class _LnSwapTxSensitive extends LnSwapTxSensitive {
  const factory _LnSwapTxSensitive(
      {required final String id,
      required final String secretKey,
      required final String publicKey,
      required final String preimage,
      required final String sha256,
      required final String hash160,
      final String? boltzPubkey,
      final bool? isSubmarine,
      final String? scriptAddress,
      final int? locktime,
      final String? blindingKey}) = _$LnSwapTxSensitiveImpl;
  const _LnSwapTxSensitive._() : super._();

  factory _LnSwapTxSensitive.fromJson(Map<String, dynamic> json) =
      _$LnSwapTxSensitiveImpl.fromJson;

  @override
  String get id;
  @override
  String get secretKey;
  @override
  String get publicKey;
  @override
  String get preimage;
  @override
  String get sha256;
  @override
  String get hash160;
  @override
  String? get boltzPubkey;
  @override
  bool? get isSubmarine;
  @override
  String? get scriptAddress;
  @override
  int? get locktime;
  @override
  String? get blindingKey;
  @override
  @JsonKey(ignore: true)
  _$$LnSwapTxSensitiveImplCopyWith<_$LnSwapTxSensitiveImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Invoice _$InvoiceFromJson(Map<String, dynamic> json) {
  return _Invoice.fromJson(json);
}

/// @nodoc
mixin _$Invoice {
  int get msats => throw _privateConstructorUsedError;
  int get expiry => throw _privateConstructorUsedError;
  int get expiresIn => throw _privateConstructorUsedError;
  int get expiresAt => throw _privateConstructorUsedError;
  bool get isExpired => throw _privateConstructorUsedError;
  String get network => throw _privateConstructorUsedError;
  int get cltvExpDelta => throw _privateConstructorUsedError;
  String get invoice => throw _privateConstructorUsedError;
  String? get bip21 => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $InvoiceCopyWith<Invoice> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InvoiceCopyWith<$Res> {
  factory $InvoiceCopyWith(Invoice value, $Res Function(Invoice) then) =
      _$InvoiceCopyWithImpl<$Res, Invoice>;
  @useResult
  $Res call(
      {int msats,
      int expiry,
      int expiresIn,
      int expiresAt,
      bool isExpired,
      String network,
      int cltvExpDelta,
      String invoice,
      String? bip21});
}

/// @nodoc
class _$InvoiceCopyWithImpl<$Res, $Val extends Invoice>
    implements $InvoiceCopyWith<$Res> {
  _$InvoiceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? msats = null,
    Object? expiry = null,
    Object? expiresIn = null,
    Object? expiresAt = null,
    Object? isExpired = null,
    Object? network = null,
    Object? cltvExpDelta = null,
    Object? invoice = null,
    Object? bip21 = freezed,
  }) {
    return _then(_value.copyWith(
      msats: null == msats
          ? _value.msats
          : msats // ignore: cast_nullable_to_non_nullable
              as int,
      expiry: null == expiry
          ? _value.expiry
          : expiry // ignore: cast_nullable_to_non_nullable
              as int,
      expiresIn: null == expiresIn
          ? _value.expiresIn
          : expiresIn // ignore: cast_nullable_to_non_nullable
              as int,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as int,
      isExpired: null == isExpired
          ? _value.isExpired
          : isExpired // ignore: cast_nullable_to_non_nullable
              as bool,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as String,
      cltvExpDelta: null == cltvExpDelta
          ? _value.cltvExpDelta
          : cltvExpDelta // ignore: cast_nullable_to_non_nullable
              as int,
      invoice: null == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as String,
      bip21: freezed == bip21
          ? _value.bip21
          : bip21 // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InvoiceImplCopyWith<$Res> implements $InvoiceCopyWith<$Res> {
  factory _$$InvoiceImplCopyWith(
          _$InvoiceImpl value, $Res Function(_$InvoiceImpl) then) =
      __$$InvoiceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int msats,
      int expiry,
      int expiresIn,
      int expiresAt,
      bool isExpired,
      String network,
      int cltvExpDelta,
      String invoice,
      String? bip21});
}

/// @nodoc
class __$$InvoiceImplCopyWithImpl<$Res>
    extends _$InvoiceCopyWithImpl<$Res, _$InvoiceImpl>
    implements _$$InvoiceImplCopyWith<$Res> {
  __$$InvoiceImplCopyWithImpl(
      _$InvoiceImpl _value, $Res Function(_$InvoiceImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? msats = null,
    Object? expiry = null,
    Object? expiresIn = null,
    Object? expiresAt = null,
    Object? isExpired = null,
    Object? network = null,
    Object? cltvExpDelta = null,
    Object? invoice = null,
    Object? bip21 = freezed,
  }) {
    return _then(_$InvoiceImpl(
      msats: null == msats
          ? _value.msats
          : msats // ignore: cast_nullable_to_non_nullable
              as int,
      expiry: null == expiry
          ? _value.expiry
          : expiry // ignore: cast_nullable_to_non_nullable
              as int,
      expiresIn: null == expiresIn
          ? _value.expiresIn
          : expiresIn // ignore: cast_nullable_to_non_nullable
              as int,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as int,
      isExpired: null == isExpired
          ? _value.isExpired
          : isExpired // ignore: cast_nullable_to_non_nullable
              as bool,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as String,
      cltvExpDelta: null == cltvExpDelta
          ? _value.cltvExpDelta
          : cltvExpDelta // ignore: cast_nullable_to_non_nullable
              as int,
      invoice: null == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as String,
      bip21: freezed == bip21
          ? _value.bip21
          : bip21 // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$InvoiceImpl extends _Invoice with DiagnosticableTreeMixin {
  const _$InvoiceImpl(
      {required this.msats,
      required this.expiry,
      required this.expiresIn,
      required this.expiresAt,
      required this.isExpired,
      required this.network,
      required this.cltvExpDelta,
      required this.invoice,
      this.bip21})
      : super._();

  factory _$InvoiceImpl.fromJson(Map<String, dynamic> json) =>
      _$$InvoiceImplFromJson(json);

  @override
  final int msats;
  @override
  final int expiry;
  @override
  final int expiresIn;
  @override
  final int expiresAt;
  @override
  final bool isExpired;
  @override
  final String network;
  @override
  final int cltvExpDelta;
  @override
  final String invoice;
  @override
  final String? bip21;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'Invoice(msats: $msats, expiry: $expiry, expiresIn: $expiresIn, expiresAt: $expiresAt, isExpired: $isExpired, network: $network, cltvExpDelta: $cltvExpDelta, invoice: $invoice, bip21: $bip21)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'Invoice'))
      ..add(DiagnosticsProperty('msats', msats))
      ..add(DiagnosticsProperty('expiry', expiry))
      ..add(DiagnosticsProperty('expiresIn', expiresIn))
      ..add(DiagnosticsProperty('expiresAt', expiresAt))
      ..add(DiagnosticsProperty('isExpired', isExpired))
      ..add(DiagnosticsProperty('network', network))
      ..add(DiagnosticsProperty('cltvExpDelta', cltvExpDelta))
      ..add(DiagnosticsProperty('invoice', invoice))
      ..add(DiagnosticsProperty('bip21', bip21));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InvoiceImpl &&
            (identical(other.msats, msats) || other.msats == msats) &&
            (identical(other.expiry, expiry) || other.expiry == expiry) &&
            (identical(other.expiresIn, expiresIn) ||
                other.expiresIn == expiresIn) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.isExpired, isExpired) ||
                other.isExpired == isExpired) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.cltvExpDelta, cltvExpDelta) ||
                other.cltvExpDelta == cltvExpDelta) &&
            (identical(other.invoice, invoice) || other.invoice == invoice) &&
            (identical(other.bip21, bip21) || other.bip21 == bip21));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, msats, expiry, expiresIn,
      expiresAt, isExpired, network, cltvExpDelta, invoice, bip21);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$InvoiceImplCopyWith<_$InvoiceImpl> get copyWith =>
      __$$InvoiceImplCopyWithImpl<_$InvoiceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InvoiceImplToJson(
      this,
    );
  }
}

abstract class _Invoice extends Invoice {
  const factory _Invoice(
      {required final int msats,
      required final int expiry,
      required final int expiresIn,
      required final int expiresAt,
      required final bool isExpired,
      required final String network,
      required final int cltvExpDelta,
      required final String invoice,
      final String? bip21}) = _$InvoiceImpl;
  const _Invoice._() : super._();

  factory _Invoice.fromJson(Map<String, dynamic> json) = _$InvoiceImpl.fromJson;

  @override
  int get msats;
  @override
  int get expiry;
  @override
  int get expiresIn;
  @override
  int get expiresAt;
  @override
  bool get isExpired;
  @override
  String get network;
  @override
  int get cltvExpDelta;
  @override
  String get invoice;
  @override
  String? get bip21;
  @override
  @JsonKey(ignore: true)
  _$$InvoiceImplCopyWith<_$InvoiceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
