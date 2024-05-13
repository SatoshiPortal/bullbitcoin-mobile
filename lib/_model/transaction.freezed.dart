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
  int? get height => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  String? get toAddress => throw _privateConstructorUsedError;
  String? get psbt => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  Uint8List? get pset => throw _privateConstructorUsedError;
  bool get rbfEnabled => throw _privateConstructorUsedError;
  bool get oldTx => throw _privateConstructorUsedError;
  int? get broadcastTime =>
      throw _privateConstructorUsedError; // String? serializedTx,
  List<Address> get outAddrs => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.TransactionDetails? get bdkTx => throw _privateConstructorUsedError;
  Wallet? get wallet => throw _privateConstructorUsedError;
  bool get isSwap => throw _privateConstructorUsedError;
  SwapTx? get swapTx => throw _privateConstructorUsedError;
  bool get isLiquid => throw _privateConstructorUsedError;

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
      int? height,
      String? label,
      String? toAddress,
      String? psbt,
      @JsonKey(includeFromJson: false, includeToJson: false) Uint8List? pset,
      bool rbfEnabled,
      bool oldTx,
      int? broadcastTime,
      List<Address> outAddrs,
      @JsonKey(includeFromJson: false, includeToJson: false)
      bdk.TransactionDetails? bdkTx,
      Wallet? wallet,
      bool isSwap,
      SwapTx? swapTx,
      bool isLiquid});

  $WalletCopyWith<$Res>? get wallet;
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
    Object? height = freezed,
    Object? label = freezed,
    Object? toAddress = freezed,
    Object? psbt = freezed,
    Object? pset = freezed,
    Object? rbfEnabled = null,
    Object? oldTx = null,
    Object? broadcastTime = freezed,
    Object? outAddrs = null,
    Object? bdkTx = freezed,
    Object? wallet = freezed,
    Object? isSwap = null,
    Object? swapTx = freezed,
    Object? isLiquid = null,
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
      oldTx: null == oldTx
          ? _value.oldTx
          : oldTx // ignore: cast_nullable_to_non_nullable
              as bool,
      broadcastTime: freezed == broadcastTime
          ? _value.broadcastTime
          : broadcastTime // ignore: cast_nullable_to_non_nullable
              as int?,
      outAddrs: null == outAddrs
          ? _value.outAddrs
          : outAddrs // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      bdkTx: freezed == bdkTx
          ? _value.bdkTx
          : bdkTx // ignore: cast_nullable_to_non_nullable
              as bdk.TransactionDetails?,
      wallet: freezed == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
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
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $WalletCopyWith<$Res>? get wallet {
    if (_value.wallet == null) {
      return null;
    }

    return $WalletCopyWith<$Res>(_value.wallet!, (value) {
      return _then(_value.copyWith(wallet: value) as $Val);
    });
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
      int? height,
      String? label,
      String? toAddress,
      String? psbt,
      @JsonKey(includeFromJson: false, includeToJson: false) Uint8List? pset,
      bool rbfEnabled,
      bool oldTx,
      int? broadcastTime,
      List<Address> outAddrs,
      @JsonKey(includeFromJson: false, includeToJson: false)
      bdk.TransactionDetails? bdkTx,
      Wallet? wallet,
      bool isSwap,
      SwapTx? swapTx,
      bool isLiquid});

  @override
  $WalletCopyWith<$Res>? get wallet;
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
    Object? height = freezed,
    Object? label = freezed,
    Object? toAddress = freezed,
    Object? psbt = freezed,
    Object? pset = freezed,
    Object? rbfEnabled = null,
    Object? oldTx = null,
    Object? broadcastTime = freezed,
    Object? outAddrs = null,
    Object? bdkTx = freezed,
    Object? wallet = freezed,
    Object? isSwap = null,
    Object? swapTx = freezed,
    Object? isLiquid = null,
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
      oldTx: null == oldTx
          ? _value.oldTx
          : oldTx // ignore: cast_nullable_to_non_nullable
              as bool,
      broadcastTime: freezed == broadcastTime
          ? _value.broadcastTime
          : broadcastTime // ignore: cast_nullable_to_non_nullable
              as int?,
      outAddrs: null == outAddrs
          ? _value._outAddrs
          : outAddrs // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      bdkTx: freezed == bdkTx
          ? _value.bdkTx
          : bdkTx // ignore: cast_nullable_to_non_nullable
              as bdk.TransactionDetails?,
      wallet: freezed == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
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
      this.height,
      this.label,
      this.toAddress,
      this.psbt,
      @JsonKey(includeFromJson: false, includeToJson: false) this.pset,
      this.rbfEnabled = true,
      this.oldTx = false,
      this.broadcastTime,
      final List<Address> outAddrs = const [],
      @JsonKey(includeFromJson: false, includeToJson: false) this.bdkTx,
      this.wallet,
      this.isSwap = false,
      this.swapTx,
      this.isLiquid = false})
      : _outAddrs = outAddrs,
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
  @override
  @JsonKey()
  final bool oldTx;
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

  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bdk.TransactionDetails? bdkTx;
  @override
  final Wallet? wallet;
  @override
  @JsonKey()
  final bool isSwap;
  @override
  final SwapTx? swapTx;
  @override
  @JsonKey()
  final bool isLiquid;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'Transaction(timestamp: $timestamp, txid: $txid, received: $received, sent: $sent, fee: $fee, height: $height, label: $label, toAddress: $toAddress, psbt: $psbt, pset: $pset, rbfEnabled: $rbfEnabled, oldTx: $oldTx, broadcastTime: $broadcastTime, outAddrs: $outAddrs, bdkTx: $bdkTx, wallet: $wallet, isSwap: $isSwap, swapTx: $swapTx, isLiquid: $isLiquid)';
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
      ..add(DiagnosticsProperty('height', height))
      ..add(DiagnosticsProperty('label', label))
      ..add(DiagnosticsProperty('toAddress', toAddress))
      ..add(DiagnosticsProperty('psbt', psbt))
      ..add(DiagnosticsProperty('pset', pset))
      ..add(DiagnosticsProperty('rbfEnabled', rbfEnabled))
      ..add(DiagnosticsProperty('oldTx', oldTx))
      ..add(DiagnosticsProperty('broadcastTime', broadcastTime))
      ..add(DiagnosticsProperty('outAddrs', outAddrs))
      ..add(DiagnosticsProperty('bdkTx', bdkTx))
      ..add(DiagnosticsProperty('wallet', wallet))
      ..add(DiagnosticsProperty('isSwap', isSwap))
      ..add(DiagnosticsProperty('swapTx', swapTx))
      ..add(DiagnosticsProperty('isLiquid', isLiquid));
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
            (identical(other.height, height) || other.height == height) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.toAddress, toAddress) ||
                other.toAddress == toAddress) &&
            (identical(other.psbt, psbt) || other.psbt == psbt) &&
            const DeepCollectionEquality().equals(other.pset, pset) &&
            (identical(other.rbfEnabled, rbfEnabled) ||
                other.rbfEnabled == rbfEnabled) &&
            (identical(other.oldTx, oldTx) || other.oldTx == oldTx) &&
            (identical(other.broadcastTime, broadcastTime) ||
                other.broadcastTime == broadcastTime) &&
            const DeepCollectionEquality().equals(other._outAddrs, _outAddrs) &&
            (identical(other.bdkTx, bdkTx) || other.bdkTx == bdkTx) &&
            (identical(other.wallet, wallet) || other.wallet == wallet) &&
            (identical(other.isSwap, isSwap) || other.isSwap == isSwap) &&
            (identical(other.swapTx, swapTx) || other.swapTx == swapTx) &&
            (identical(other.isLiquid, isLiquid) ||
                other.isLiquid == isLiquid));
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
        height,
        label,
        toAddress,
        psbt,
        const DeepCollectionEquality().hash(pset),
        rbfEnabled,
        oldTx,
        broadcastTime,
        const DeepCollectionEquality().hash(_outAddrs),
        bdkTx,
        wallet,
        isSwap,
        swapTx,
        isLiquid
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
      final int? height,
      final String? label,
      final String? toAddress,
      final String? psbt,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final Uint8List? pset,
      final bool rbfEnabled,
      final bool oldTx,
      final int? broadcastTime,
      final List<Address> outAddrs,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final bdk.TransactionDetails? bdkTx,
      final Wallet? wallet,
      final bool isSwap,
      final SwapTx? swapTx,
      final bool isLiquid}) = _$TransactionImpl;
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
  @override
  bool get oldTx;
  @override
  int? get broadcastTime;
  @override // String? serializedTx,
  List<Address> get outAddrs;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.TransactionDetails? get bdkTx;
  @override
  Wallet? get wallet;
  @override
  bool get isSwap;
  @override
  SwapTx? get swapTx;
  @override
  bool get isLiquid;
  @override
  @JsonKey(ignore: true)
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SwapTx _$SwapTxFromJson(Map<String, dynamic> json) {
  return _SwapTx.fromJson(json);
}

/// @nodoc
mixin _$SwapTx {
  String get id => throw _privateConstructorUsedError;
  String? get txid => throw _privateConstructorUsedError;
  int? get keyIndex => throw _privateConstructorUsedError;
  bool get isSubmarine => throw _privateConstructorUsedError;
  BBNetwork get network => throw _privateConstructorUsedError;
  BaseWalletType get walletType => throw _privateConstructorUsedError;
  String? get secretKey => throw _privateConstructorUsedError;
  String? get publicKey => throw _privateConstructorUsedError;
  String? get sha256 => throw _privateConstructorUsedError;
  String? get hash160 => throw _privateConstructorUsedError;
  String get redeemScript => throw _privateConstructorUsedError;
  String? get boltzPubkey => throw _privateConstructorUsedError;
  int? get locktime => throw _privateConstructorUsedError;
  String get invoice => throw _privateConstructorUsedError;
  int get outAmount => throw _privateConstructorUsedError;
  String get scriptAddress => throw _privateConstructorUsedError;
  String get electrumUrl => throw _privateConstructorUsedError;
  String get boltzUrl => throw _privateConstructorUsedError;
  SwapStreamStatus? get status =>
      throw _privateConstructorUsedError; // should this be SwapStaus?
  String? get blindingKey => throw _privateConstructorUsedError; // sensitive
  int? get boltzFees => throw _privateConstructorUsedError;
  int? get lockupFees => throw _privateConstructorUsedError;
  int? get claimFees => throw _privateConstructorUsedError;
  String? get claimAddress => throw _privateConstructorUsedError;

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
      String? txid,
      int? keyIndex,
      bool isSubmarine,
      BBNetwork network,
      BaseWalletType walletType,
      String? secretKey,
      String? publicKey,
      String? sha256,
      String? hash160,
      String redeemScript,
      String? boltzPubkey,
      int? locktime,
      String invoice,
      int outAmount,
      String scriptAddress,
      String electrumUrl,
      String boltzUrl,
      SwapStreamStatus? status,
      String? blindingKey,
      int? boltzFees,
      int? lockupFees,
      int? claimFees,
      String? claimAddress});

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
    Object? txid = freezed,
    Object? keyIndex = freezed,
    Object? isSubmarine = null,
    Object? network = null,
    Object? walletType = null,
    Object? secretKey = freezed,
    Object? publicKey = freezed,
    Object? sha256 = freezed,
    Object? hash160 = freezed,
    Object? redeemScript = null,
    Object? boltzPubkey = freezed,
    Object? locktime = freezed,
    Object? invoice = null,
    Object? outAmount = null,
    Object? scriptAddress = null,
    Object? electrumUrl = null,
    Object? boltzUrl = null,
    Object? status = freezed,
    Object? blindingKey = freezed,
    Object? boltzFees = freezed,
    Object? lockupFees = freezed,
    Object? claimFees = freezed,
    Object? claimAddress = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      txid: freezed == txid
          ? _value.txid
          : txid // ignore: cast_nullable_to_non_nullable
              as String?,
      keyIndex: freezed == keyIndex
          ? _value.keyIndex
          : keyIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      isSubmarine: null == isSubmarine
          ? _value.isSubmarine
          : isSubmarine // ignore: cast_nullable_to_non_nullable
              as bool,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as BBNetwork,
      walletType: null == walletType
          ? _value.walletType
          : walletType // ignore: cast_nullable_to_non_nullable
              as BaseWalletType,
      secretKey: freezed == secretKey
          ? _value.secretKey
          : secretKey // ignore: cast_nullable_to_non_nullable
              as String?,
      publicKey: freezed == publicKey
          ? _value.publicKey
          : publicKey // ignore: cast_nullable_to_non_nullable
              as String?,
      sha256: freezed == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String?,
      hash160: freezed == hash160
          ? _value.hash160
          : hash160 // ignore: cast_nullable_to_non_nullable
              as String?,
      redeemScript: null == redeemScript
          ? _value.redeemScript
          : redeemScript // ignore: cast_nullable_to_non_nullable
              as String,
      boltzPubkey: freezed == boltzPubkey
          ? _value.boltzPubkey
          : boltzPubkey // ignore: cast_nullable_to_non_nullable
              as String?,
      locktime: freezed == locktime
          ? _value.locktime
          : locktime // ignore: cast_nullable_to_non_nullable
              as int?,
      invoice: null == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as String,
      outAmount: null == outAmount
          ? _value.outAmount
          : outAmount // ignore: cast_nullable_to_non_nullable
              as int,
      scriptAddress: null == scriptAddress
          ? _value.scriptAddress
          : scriptAddress // ignore: cast_nullable_to_non_nullable
              as String,
      electrumUrl: null == electrumUrl
          ? _value.electrumUrl
          : electrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      boltzUrl: null == boltzUrl
          ? _value.boltzUrl
          : boltzUrl // ignore: cast_nullable_to_non_nullable
              as String,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SwapStreamStatus?,
      blindingKey: freezed == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String?,
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
    ) as $Val);
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
      String? txid,
      int? keyIndex,
      bool isSubmarine,
      BBNetwork network,
      BaseWalletType walletType,
      String? secretKey,
      String? publicKey,
      String? sha256,
      String? hash160,
      String redeemScript,
      String? boltzPubkey,
      int? locktime,
      String invoice,
      int outAmount,
      String scriptAddress,
      String electrumUrl,
      String boltzUrl,
      SwapStreamStatus? status,
      String? blindingKey,
      int? boltzFees,
      int? lockupFees,
      int? claimFees,
      String? claimAddress});

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
    Object? txid = freezed,
    Object? keyIndex = freezed,
    Object? isSubmarine = null,
    Object? network = null,
    Object? walletType = null,
    Object? secretKey = freezed,
    Object? publicKey = freezed,
    Object? sha256 = freezed,
    Object? hash160 = freezed,
    Object? redeemScript = null,
    Object? boltzPubkey = freezed,
    Object? locktime = freezed,
    Object? invoice = null,
    Object? outAmount = null,
    Object? scriptAddress = null,
    Object? electrumUrl = null,
    Object? boltzUrl = null,
    Object? status = freezed,
    Object? blindingKey = freezed,
    Object? boltzFees = freezed,
    Object? lockupFees = freezed,
    Object? claimFees = freezed,
    Object? claimAddress = freezed,
  }) {
    return _then(_$SwapTxImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      txid: freezed == txid
          ? _value.txid
          : txid // ignore: cast_nullable_to_non_nullable
              as String?,
      keyIndex: freezed == keyIndex
          ? _value.keyIndex
          : keyIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      isSubmarine: null == isSubmarine
          ? _value.isSubmarine
          : isSubmarine // ignore: cast_nullable_to_non_nullable
              as bool,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as BBNetwork,
      walletType: null == walletType
          ? _value.walletType
          : walletType // ignore: cast_nullable_to_non_nullable
              as BaseWalletType,
      secretKey: freezed == secretKey
          ? _value.secretKey
          : secretKey // ignore: cast_nullable_to_non_nullable
              as String?,
      publicKey: freezed == publicKey
          ? _value.publicKey
          : publicKey // ignore: cast_nullable_to_non_nullable
              as String?,
      sha256: freezed == sha256
          ? _value.sha256
          : sha256 // ignore: cast_nullable_to_non_nullable
              as String?,
      hash160: freezed == hash160
          ? _value.hash160
          : hash160 // ignore: cast_nullable_to_non_nullable
              as String?,
      redeemScript: null == redeemScript
          ? _value.redeemScript
          : redeemScript // ignore: cast_nullable_to_non_nullable
              as String,
      boltzPubkey: freezed == boltzPubkey
          ? _value.boltzPubkey
          : boltzPubkey // ignore: cast_nullable_to_non_nullable
              as String?,
      locktime: freezed == locktime
          ? _value.locktime
          : locktime // ignore: cast_nullable_to_non_nullable
              as int?,
      invoice: null == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as String,
      outAmount: null == outAmount
          ? _value.outAmount
          : outAmount // ignore: cast_nullable_to_non_nullable
              as int,
      scriptAddress: null == scriptAddress
          ? _value.scriptAddress
          : scriptAddress // ignore: cast_nullable_to_non_nullable
              as String,
      electrumUrl: null == electrumUrl
          ? _value.electrumUrl
          : electrumUrl // ignore: cast_nullable_to_non_nullable
              as String,
      boltzUrl: null == boltzUrl
          ? _value.boltzUrl
          : boltzUrl // ignore: cast_nullable_to_non_nullable
              as String,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SwapStreamStatus?,
      blindingKey: freezed == blindingKey
          ? _value.blindingKey
          : blindingKey // ignore: cast_nullable_to_non_nullable
              as String?,
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
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SwapTxImpl extends _SwapTx with DiagnosticableTreeMixin {
  const _$SwapTxImpl(
      {required this.id,
      this.txid,
      this.keyIndex,
      required this.isSubmarine,
      required this.network,
      required this.walletType,
      this.secretKey,
      this.publicKey,
      this.sha256,
      this.hash160,
      required this.redeemScript,
      this.boltzPubkey,
      this.locktime,
      required this.invoice,
      required this.outAmount,
      required this.scriptAddress,
      required this.electrumUrl,
      required this.boltzUrl,
      this.status,
      this.blindingKey,
      this.boltzFees,
      this.lockupFees,
      this.claimFees,
      this.claimAddress})
      : super._();

  factory _$SwapTxImpl.fromJson(Map<String, dynamic> json) =>
      _$$SwapTxImplFromJson(json);

  @override
  final String id;
  @override
  final String? txid;
  @override
  final int? keyIndex;
  @override
  final bool isSubmarine;
  @override
  final BBNetwork network;
  @override
  final BaseWalletType walletType;
  @override
  final String? secretKey;
  @override
  final String? publicKey;
  @override
  final String? sha256;
  @override
  final String? hash160;
  @override
  final String redeemScript;
  @override
  final String? boltzPubkey;
  @override
  final int? locktime;
  @override
  final String invoice;
  @override
  final int outAmount;
  @override
  final String scriptAddress;
  @override
  final String electrumUrl;
  @override
  final String boltzUrl;
  @override
  final SwapStreamStatus? status;
// should this be SwapStaus?
  @override
  final String? blindingKey;
// sensitive
  @override
  final int? boltzFees;
  @override
  final int? lockupFees;
  @override
  final int? claimFees;
  @override
  final String? claimAddress;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'SwapTx(id: $id, txid: $txid, keyIndex: $keyIndex, isSubmarine: $isSubmarine, network: $network, walletType: $walletType, secretKey: $secretKey, publicKey: $publicKey, sha256: $sha256, hash160: $hash160, redeemScript: $redeemScript, boltzPubkey: $boltzPubkey, locktime: $locktime, invoice: $invoice, outAmount: $outAmount, scriptAddress: $scriptAddress, electrumUrl: $electrumUrl, boltzUrl: $boltzUrl, status: $status, blindingKey: $blindingKey, boltzFees: $boltzFees, lockupFees: $lockupFees, claimFees: $claimFees, claimAddress: $claimAddress)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'SwapTx'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('txid', txid))
      ..add(DiagnosticsProperty('keyIndex', keyIndex))
      ..add(DiagnosticsProperty('isSubmarine', isSubmarine))
      ..add(DiagnosticsProperty('network', network))
      ..add(DiagnosticsProperty('walletType', walletType))
      ..add(DiagnosticsProperty('secretKey', secretKey))
      ..add(DiagnosticsProperty('publicKey', publicKey))
      ..add(DiagnosticsProperty('sha256', sha256))
      ..add(DiagnosticsProperty('hash160', hash160))
      ..add(DiagnosticsProperty('redeemScript', redeemScript))
      ..add(DiagnosticsProperty('boltzPubkey', boltzPubkey))
      ..add(DiagnosticsProperty('locktime', locktime))
      ..add(DiagnosticsProperty('invoice', invoice))
      ..add(DiagnosticsProperty('outAmount', outAmount))
      ..add(DiagnosticsProperty('scriptAddress', scriptAddress))
      ..add(DiagnosticsProperty('electrumUrl', electrumUrl))
      ..add(DiagnosticsProperty('boltzUrl', boltzUrl))
      ..add(DiagnosticsProperty('status', status))
      ..add(DiagnosticsProperty('blindingKey', blindingKey))
      ..add(DiagnosticsProperty('boltzFees', boltzFees))
      ..add(DiagnosticsProperty('lockupFees', lockupFees))
      ..add(DiagnosticsProperty('claimFees', claimFees))
      ..add(DiagnosticsProperty('claimAddress', claimAddress));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SwapTxImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.txid, txid) || other.txid == txid) &&
            (identical(other.keyIndex, keyIndex) ||
                other.keyIndex == keyIndex) &&
            (identical(other.isSubmarine, isSubmarine) ||
                other.isSubmarine == isSubmarine) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.walletType, walletType) ||
                other.walletType == walletType) &&
            (identical(other.secretKey, secretKey) ||
                other.secretKey == secretKey) &&
            (identical(other.publicKey, publicKey) ||
                other.publicKey == publicKey) &&
            (identical(other.sha256, sha256) || other.sha256 == sha256) &&
            (identical(other.hash160, hash160) || other.hash160 == hash160) &&
            (identical(other.redeemScript, redeemScript) ||
                other.redeemScript == redeemScript) &&
            (identical(other.boltzPubkey, boltzPubkey) ||
                other.boltzPubkey == boltzPubkey) &&
            (identical(other.locktime, locktime) ||
                other.locktime == locktime) &&
            (identical(other.invoice, invoice) || other.invoice == invoice) &&
            (identical(other.outAmount, outAmount) ||
                other.outAmount == outAmount) &&
            (identical(other.scriptAddress, scriptAddress) ||
                other.scriptAddress == scriptAddress) &&
            (identical(other.electrumUrl, electrumUrl) ||
                other.electrumUrl == electrumUrl) &&
            (identical(other.boltzUrl, boltzUrl) ||
                other.boltzUrl == boltzUrl) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.blindingKey, blindingKey) ||
                other.blindingKey == blindingKey) &&
            (identical(other.boltzFees, boltzFees) ||
                other.boltzFees == boltzFees) &&
            (identical(other.lockupFees, lockupFees) ||
                other.lockupFees == lockupFees) &&
            (identical(other.claimFees, claimFees) ||
                other.claimFees == claimFees) &&
            (identical(other.claimAddress, claimAddress) ||
                other.claimAddress == claimAddress));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        txid,
        keyIndex,
        isSubmarine,
        network,
        walletType,
        secretKey,
        publicKey,
        sha256,
        hash160,
        redeemScript,
        boltzPubkey,
        locktime,
        invoice,
        outAmount,
        scriptAddress,
        electrumUrl,
        boltzUrl,
        status,
        blindingKey,
        boltzFees,
        lockupFees,
        claimFees,
        claimAddress
      ]);

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
      final String? txid,
      final int? keyIndex,
      required final bool isSubmarine,
      required final BBNetwork network,
      required final BaseWalletType walletType,
      final String? secretKey,
      final String? publicKey,
      final String? sha256,
      final String? hash160,
      required final String redeemScript,
      final String? boltzPubkey,
      final int? locktime,
      required final String invoice,
      required final int outAmount,
      required final String scriptAddress,
      required final String electrumUrl,
      required final String boltzUrl,
      final SwapStreamStatus? status,
      final String? blindingKey,
      final int? boltzFees,
      final int? lockupFees,
      final int? claimFees,
      final String? claimAddress}) = _$SwapTxImpl;
  const _SwapTx._() : super._();

  factory _SwapTx.fromJson(Map<String, dynamic> json) = _$SwapTxImpl.fromJson;

  @override
  String get id;
  @override
  String? get txid;
  @override
  int? get keyIndex;
  @override
  bool get isSubmarine;
  @override
  BBNetwork get network;
  @override
  BaseWalletType get walletType;
  @override
  String? get secretKey;
  @override
  String? get publicKey;
  @override
  String? get sha256;
  @override
  String? get hash160;
  @override
  String get redeemScript;
  @override
  String? get boltzPubkey;
  @override
  int? get locktime;
  @override
  String get invoice;
  @override
  int get outAmount;
  @override
  String get scriptAddress;
  @override
  String get electrumUrl;
  @override
  String get boltzUrl;
  @override
  SwapStreamStatus? get status;
  @override // should this be SwapStaus?
  String? get blindingKey;
  @override // sensitive
  int? get boltzFees;
  @override
  int? get lockupFees;
  @override
  int? get claimFees;
  @override
  String? get claimAddress;
  @override
  @JsonKey(ignore: true)
  _$$SwapTxImplCopyWith<_$SwapTxImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SwapTxSensitive _$SwapTxSensitiveFromJson(Map<String, dynamic> json) {
  return _SwapTxSensitive.fromJson(json);
}

/// @nodoc
mixin _$SwapTxSensitive {
  String get id => throw _privateConstructorUsedError;
  String get secretKey => throw _privateConstructorUsedError;
  String get publicKey => throw _privateConstructorUsedError;
  String get preimage => throw _privateConstructorUsedError;
  String get sha256 => throw _privateConstructorUsedError;
  String get hash160 => throw _privateConstructorUsedError;
  String get redeemScript => throw _privateConstructorUsedError;
  String? get boltzPubkey => throw _privateConstructorUsedError;
  bool? get isSubmarine => throw _privateConstructorUsedError;
  String? get scriptAddress => throw _privateConstructorUsedError;
  int? get locktime => throw _privateConstructorUsedError;
  String? get blindingKey => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SwapTxSensitiveCopyWith<SwapTxSensitive> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SwapTxSensitiveCopyWith<$Res> {
  factory $SwapTxSensitiveCopyWith(
          SwapTxSensitive value, $Res Function(SwapTxSensitive) then) =
      _$SwapTxSensitiveCopyWithImpl<$Res, SwapTxSensitive>;
  @useResult
  $Res call(
      {String id,
      String secretKey,
      String publicKey,
      String preimage,
      String sha256,
      String hash160,
      String redeemScript,
      String? boltzPubkey,
      bool? isSubmarine,
      String? scriptAddress,
      int? locktime,
      String? blindingKey});
}

/// @nodoc
class _$SwapTxSensitiveCopyWithImpl<$Res, $Val extends SwapTxSensitive>
    implements $SwapTxSensitiveCopyWith<$Res> {
  _$SwapTxSensitiveCopyWithImpl(this._value, this._then);

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
    Object? redeemScript = null,
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
      redeemScript: null == redeemScript
          ? _value.redeemScript
          : redeemScript // ignore: cast_nullable_to_non_nullable
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
abstract class _$$SwapTxSensitiveImplCopyWith<$Res>
    implements $SwapTxSensitiveCopyWith<$Res> {
  factory _$$SwapTxSensitiveImplCopyWith(_$SwapTxSensitiveImpl value,
          $Res Function(_$SwapTxSensitiveImpl) then) =
      __$$SwapTxSensitiveImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String secretKey,
      String publicKey,
      String preimage,
      String sha256,
      String hash160,
      String redeemScript,
      String? boltzPubkey,
      bool? isSubmarine,
      String? scriptAddress,
      int? locktime,
      String? blindingKey});
}

/// @nodoc
class __$$SwapTxSensitiveImplCopyWithImpl<$Res>
    extends _$SwapTxSensitiveCopyWithImpl<$Res, _$SwapTxSensitiveImpl>
    implements _$$SwapTxSensitiveImplCopyWith<$Res> {
  __$$SwapTxSensitiveImplCopyWithImpl(
      _$SwapTxSensitiveImpl _value, $Res Function(_$SwapTxSensitiveImpl) _then)
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
    Object? redeemScript = null,
    Object? boltzPubkey = freezed,
    Object? isSubmarine = freezed,
    Object? scriptAddress = freezed,
    Object? locktime = freezed,
    Object? blindingKey = freezed,
  }) {
    return _then(_$SwapTxSensitiveImpl(
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
      redeemScript: null == redeemScript
          ? _value.redeemScript
          : redeemScript // ignore: cast_nullable_to_non_nullable
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
class _$SwapTxSensitiveImpl extends _SwapTxSensitive
    with DiagnosticableTreeMixin {
  const _$SwapTxSensitiveImpl(
      {required this.id,
      required this.secretKey,
      required this.publicKey,
      required this.preimage,
      required this.sha256,
      required this.hash160,
      required this.redeemScript,
      this.boltzPubkey,
      this.isSubmarine,
      this.scriptAddress,
      this.locktime,
      this.blindingKey})
      : super._();

  factory _$SwapTxSensitiveImpl.fromJson(Map<String, dynamic> json) =>
      _$$SwapTxSensitiveImplFromJson(json);

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
  final String redeemScript;
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
    return 'SwapTxSensitive(id: $id, secretKey: $secretKey, publicKey: $publicKey, preimage: $preimage, sha256: $sha256, hash160: $hash160, redeemScript: $redeemScript, boltzPubkey: $boltzPubkey, isSubmarine: $isSubmarine, scriptAddress: $scriptAddress, locktime: $locktime, blindingKey: $blindingKey)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'SwapTxSensitive'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('secretKey', secretKey))
      ..add(DiagnosticsProperty('publicKey', publicKey))
      ..add(DiagnosticsProperty('preimage', preimage))
      ..add(DiagnosticsProperty('sha256', sha256))
      ..add(DiagnosticsProperty('hash160', hash160))
      ..add(DiagnosticsProperty('redeemScript', redeemScript))
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
            other is _$SwapTxSensitiveImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.secretKey, secretKey) ||
                other.secretKey == secretKey) &&
            (identical(other.publicKey, publicKey) ||
                other.publicKey == publicKey) &&
            (identical(other.preimage, preimage) ||
                other.preimage == preimage) &&
            (identical(other.sha256, sha256) || other.sha256 == sha256) &&
            (identical(other.hash160, hash160) || other.hash160 == hash160) &&
            (identical(other.redeemScript, redeemScript) ||
                other.redeemScript == redeemScript) &&
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
      redeemScript,
      boltzPubkey,
      isSubmarine,
      scriptAddress,
      locktime,
      blindingKey);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SwapTxSensitiveImplCopyWith<_$SwapTxSensitiveImpl> get copyWith =>
      __$$SwapTxSensitiveImplCopyWithImpl<_$SwapTxSensitiveImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SwapTxSensitiveImplToJson(
      this,
    );
  }
}

abstract class _SwapTxSensitive extends SwapTxSensitive {
  const factory _SwapTxSensitive(
      {required final String id,
      required final String secretKey,
      required final String publicKey,
      required final String preimage,
      required final String sha256,
      required final String hash160,
      required final String redeemScript,
      final String? boltzPubkey,
      final bool? isSubmarine,
      final String? scriptAddress,
      final int? locktime,
      final String? blindingKey}) = _$SwapTxSensitiveImpl;
  const _SwapTxSensitive._() : super._();

  factory _SwapTxSensitive.fromJson(Map<String, dynamic> json) =
      _$SwapTxSensitiveImpl.fromJson;

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
  String get redeemScript;
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
  _$$SwapTxSensitiveImplCopyWith<_$SwapTxSensitiveImpl> get copyWith =>
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
