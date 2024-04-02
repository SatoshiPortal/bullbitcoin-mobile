// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wallet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Wallet _$WalletFromJson(Map<String, dynamic> json) {
  return _Wallet.fromJson(json);
}

/// @nodoc
mixin _$Wallet {
  String get id => throw _privateConstructorUsedError;
  String get externalPublicDescriptor => throw _privateConstructorUsedError;
  String get internalPublicDescriptor => throw _privateConstructorUsedError;
  String get mnemonicFingerprint => throw _privateConstructorUsedError;
  String get sourceFingerprint => throw _privateConstructorUsedError;
  BBNetwork get network => throw _privateConstructorUsedError;
  BBWalletType get type => throw _privateConstructorUsedError;
  ScriptType get scriptType => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get path => throw _privateConstructorUsedError;
  int? get balance => throw _privateConstructorUsedError;
  Balance? get fullBalance => throw _privateConstructorUsedError;
  Address? get lastGeneratedAddress => throw _privateConstructorUsedError;
  List<Address> get myAddressBook => throw _privateConstructorUsedError;
  List<Address>? get externalAddressBook => throw _privateConstructorUsedError;
  List<UTXO> get utxos => throw _privateConstructorUsedError;
  List<Transaction> get transactions => throw _privateConstructorUsedError;
  List<Transaction> get unsignedTxs => throw _privateConstructorUsedError;
  List<SwapTx> get swaps => throw _privateConstructorUsedError;
  int get revKeyIndex => throw _privateConstructorUsedError;
  int get subKeyIndex =>
      throw _privateConstructorUsedError; // List<String>? labelTags,
// List<Bip329Label>? bip329Labels,
  bool get backupTested => throw _privateConstructorUsedError;
  DateTime? get lastBackupTested => throw _privateConstructorUsedError;
  bool get hide => throw _privateConstructorUsedError;
  bool get mainWallet => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $WalletCopyWith<Wallet> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WalletCopyWith<$Res> {
  factory $WalletCopyWith(Wallet value, $Res Function(Wallet) then) =
      _$WalletCopyWithImpl<$Res, Wallet>;
  @useResult
  $Res call(
      {String id,
      String externalPublicDescriptor,
      String internalPublicDescriptor,
      String mnemonicFingerprint,
      String sourceFingerprint,
      BBNetwork network,
      BBWalletType type,
      ScriptType scriptType,
      String? name,
      String? path,
      int? balance,
      Balance? fullBalance,
      Address? lastGeneratedAddress,
      List<Address> myAddressBook,
      List<Address>? externalAddressBook,
      List<UTXO> utxos,
      List<Transaction> transactions,
      List<Transaction> unsignedTxs,
      List<SwapTx> swaps,
      int revKeyIndex,
      int subKeyIndex,
      bool backupTested,
      DateTime? lastBackupTested,
      bool hide,
      bool mainWallet});

  $BalanceCopyWith<$Res>? get fullBalance;
  $AddressCopyWith<$Res>? get lastGeneratedAddress;
}

/// @nodoc
class _$WalletCopyWithImpl<$Res, $Val extends Wallet>
    implements $WalletCopyWith<$Res> {
  _$WalletCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? externalPublicDescriptor = null,
    Object? internalPublicDescriptor = null,
    Object? mnemonicFingerprint = null,
    Object? sourceFingerprint = null,
    Object? network = null,
    Object? type = null,
    Object? scriptType = null,
    Object? name = freezed,
    Object? path = freezed,
    Object? balance = freezed,
    Object? fullBalance = freezed,
    Object? lastGeneratedAddress = freezed,
    Object? myAddressBook = null,
    Object? externalAddressBook = freezed,
    Object? utxos = null,
    Object? transactions = null,
    Object? unsignedTxs = null,
    Object? swaps = null,
    Object? revKeyIndex = null,
    Object? subKeyIndex = null,
    Object? backupTested = null,
    Object? lastBackupTested = freezed,
    Object? hide = null,
    Object? mainWallet = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      externalPublicDescriptor: null == externalPublicDescriptor
          ? _value.externalPublicDescriptor
          : externalPublicDescriptor // ignore: cast_nullable_to_non_nullable
              as String,
      internalPublicDescriptor: null == internalPublicDescriptor
          ? _value.internalPublicDescriptor
          : internalPublicDescriptor // ignore: cast_nullable_to_non_nullable
              as String,
      mnemonicFingerprint: null == mnemonicFingerprint
          ? _value.mnemonicFingerprint
          : mnemonicFingerprint // ignore: cast_nullable_to_non_nullable
              as String,
      sourceFingerprint: null == sourceFingerprint
          ? _value.sourceFingerprint
          : sourceFingerprint // ignore: cast_nullable_to_non_nullable
              as String,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as BBNetwork,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as BBWalletType,
      scriptType: null == scriptType
          ? _value.scriptType
          : scriptType // ignore: cast_nullable_to_non_nullable
              as ScriptType,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      path: freezed == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String?,
      balance: freezed == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as int?,
      fullBalance: freezed == fullBalance
          ? _value.fullBalance
          : fullBalance // ignore: cast_nullable_to_non_nullable
              as Balance?,
      lastGeneratedAddress: freezed == lastGeneratedAddress
          ? _value.lastGeneratedAddress
          : lastGeneratedAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
      myAddressBook: null == myAddressBook
          ? _value.myAddressBook
          : myAddressBook // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      externalAddressBook: freezed == externalAddressBook
          ? _value.externalAddressBook
          : externalAddressBook // ignore: cast_nullable_to_non_nullable
              as List<Address>?,
      utxos: null == utxos
          ? _value.utxos
          : utxos // ignore: cast_nullable_to_non_nullable
              as List<UTXO>,
      transactions: null == transactions
          ? _value.transactions
          : transactions // ignore: cast_nullable_to_non_nullable
              as List<Transaction>,
      unsignedTxs: null == unsignedTxs
          ? _value.unsignedTxs
          : unsignedTxs // ignore: cast_nullable_to_non_nullable
              as List<Transaction>,
      swaps: null == swaps
          ? _value.swaps
          : swaps // ignore: cast_nullable_to_non_nullable
              as List<SwapTx>,
      revKeyIndex: null == revKeyIndex
          ? _value.revKeyIndex
          : revKeyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      subKeyIndex: null == subKeyIndex
          ? _value.subKeyIndex
          : subKeyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      backupTested: null == backupTested
          ? _value.backupTested
          : backupTested // ignore: cast_nullable_to_non_nullable
              as bool,
      lastBackupTested: freezed == lastBackupTested
          ? _value.lastBackupTested
          : lastBackupTested // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      hide: null == hide
          ? _value.hide
          : hide // ignore: cast_nullable_to_non_nullable
              as bool,
      mainWallet: null == mainWallet
          ? _value.mainWallet
          : mainWallet // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $BalanceCopyWith<$Res>? get fullBalance {
    if (_value.fullBalance == null) {
      return null;
    }

    return $BalanceCopyWith<$Res>(_value.fullBalance!, (value) {
      return _then(_value.copyWith(fullBalance: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $AddressCopyWith<$Res>? get lastGeneratedAddress {
    if (_value.lastGeneratedAddress == null) {
      return null;
    }

    return $AddressCopyWith<$Res>(_value.lastGeneratedAddress!, (value) {
      return _then(_value.copyWith(lastGeneratedAddress: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$WalletImplCopyWith<$Res> implements $WalletCopyWith<$Res> {
  factory _$$WalletImplCopyWith(
          _$WalletImpl value, $Res Function(_$WalletImpl) then) =
      __$$WalletImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String externalPublicDescriptor,
      String internalPublicDescriptor,
      String mnemonicFingerprint,
      String sourceFingerprint,
      BBNetwork network,
      BBWalletType type,
      ScriptType scriptType,
      String? name,
      String? path,
      int? balance,
      Balance? fullBalance,
      Address? lastGeneratedAddress,
      List<Address> myAddressBook,
      List<Address>? externalAddressBook,
      List<UTXO> utxos,
      List<Transaction> transactions,
      List<Transaction> unsignedTxs,
      List<SwapTx> swaps,
      int revKeyIndex,
      int subKeyIndex,
      bool backupTested,
      DateTime? lastBackupTested,
      bool hide,
      bool mainWallet});

  @override
  $BalanceCopyWith<$Res>? get fullBalance;
  @override
  $AddressCopyWith<$Res>? get lastGeneratedAddress;
}

/// @nodoc
class __$$WalletImplCopyWithImpl<$Res>
    extends _$WalletCopyWithImpl<$Res, _$WalletImpl>
    implements _$$WalletImplCopyWith<$Res> {
  __$$WalletImplCopyWithImpl(
      _$WalletImpl _value, $Res Function(_$WalletImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? externalPublicDescriptor = null,
    Object? internalPublicDescriptor = null,
    Object? mnemonicFingerprint = null,
    Object? sourceFingerprint = null,
    Object? network = null,
    Object? type = null,
    Object? scriptType = null,
    Object? name = freezed,
    Object? path = freezed,
    Object? balance = freezed,
    Object? fullBalance = freezed,
    Object? lastGeneratedAddress = freezed,
    Object? myAddressBook = null,
    Object? externalAddressBook = freezed,
    Object? utxos = null,
    Object? transactions = null,
    Object? unsignedTxs = null,
    Object? swaps = null,
    Object? revKeyIndex = null,
    Object? subKeyIndex = null,
    Object? backupTested = null,
    Object? lastBackupTested = freezed,
    Object? hide = null,
    Object? mainWallet = null,
  }) {
    return _then(_$WalletImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      externalPublicDescriptor: null == externalPublicDescriptor
          ? _value.externalPublicDescriptor
          : externalPublicDescriptor // ignore: cast_nullable_to_non_nullable
              as String,
      internalPublicDescriptor: null == internalPublicDescriptor
          ? _value.internalPublicDescriptor
          : internalPublicDescriptor // ignore: cast_nullable_to_non_nullable
              as String,
      mnemonicFingerprint: null == mnemonicFingerprint
          ? _value.mnemonicFingerprint
          : mnemonicFingerprint // ignore: cast_nullable_to_non_nullable
              as String,
      sourceFingerprint: null == sourceFingerprint
          ? _value.sourceFingerprint
          : sourceFingerprint // ignore: cast_nullable_to_non_nullable
              as String,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as BBNetwork,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as BBWalletType,
      scriptType: null == scriptType
          ? _value.scriptType
          : scriptType // ignore: cast_nullable_to_non_nullable
              as ScriptType,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      path: freezed == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String?,
      balance: freezed == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as int?,
      fullBalance: freezed == fullBalance
          ? _value.fullBalance
          : fullBalance // ignore: cast_nullable_to_non_nullable
              as Balance?,
      lastGeneratedAddress: freezed == lastGeneratedAddress
          ? _value.lastGeneratedAddress
          : lastGeneratedAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
      myAddressBook: null == myAddressBook
          ? _value._myAddressBook
          : myAddressBook // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      externalAddressBook: freezed == externalAddressBook
          ? _value._externalAddressBook
          : externalAddressBook // ignore: cast_nullable_to_non_nullable
              as List<Address>?,
      utxos: null == utxos
          ? _value._utxos
          : utxos // ignore: cast_nullable_to_non_nullable
              as List<UTXO>,
      transactions: null == transactions
          ? _value._transactions
          : transactions // ignore: cast_nullable_to_non_nullable
              as List<Transaction>,
      unsignedTxs: null == unsignedTxs
          ? _value._unsignedTxs
          : unsignedTxs // ignore: cast_nullable_to_non_nullable
              as List<Transaction>,
      swaps: null == swaps
          ? _value._swaps
          : swaps // ignore: cast_nullable_to_non_nullable
              as List<SwapTx>,
      revKeyIndex: null == revKeyIndex
          ? _value.revKeyIndex
          : revKeyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      subKeyIndex: null == subKeyIndex
          ? _value.subKeyIndex
          : subKeyIndex // ignore: cast_nullable_to_non_nullable
              as int,
      backupTested: null == backupTested
          ? _value.backupTested
          : backupTested // ignore: cast_nullable_to_non_nullable
              as bool,
      lastBackupTested: freezed == lastBackupTested
          ? _value.lastBackupTested
          : lastBackupTested // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      hide: null == hide
          ? _value.hide
          : hide // ignore: cast_nullable_to_non_nullable
              as bool,
      mainWallet: null == mainWallet
          ? _value.mainWallet
          : mainWallet // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WalletImpl extends _Wallet {
  const _$WalletImpl(
      {this.id = '',
      this.externalPublicDescriptor = '',
      this.internalPublicDescriptor = '',
      this.mnemonicFingerprint = '',
      this.sourceFingerprint = '',
      required this.network,
      required this.type,
      required this.scriptType,
      this.name,
      this.path,
      this.balance,
      this.fullBalance,
      this.lastGeneratedAddress,
      final List<Address> myAddressBook = const [],
      final List<Address>? externalAddressBook,
      final List<UTXO> utxos = const [],
      final List<Transaction> transactions = const [],
      final List<Transaction> unsignedTxs = const [],
      final List<SwapTx> swaps = const [],
      this.revKeyIndex = 0,
      this.subKeyIndex = 0,
      this.backupTested = false,
      this.lastBackupTested,
      this.hide = false,
      this.mainWallet = false})
      : _myAddressBook = myAddressBook,
        _externalAddressBook = externalAddressBook,
        _utxos = utxos,
        _transactions = transactions,
        _unsignedTxs = unsignedTxs,
        _swaps = swaps,
        super._();

  factory _$WalletImpl.fromJson(Map<String, dynamic> json) =>
      _$$WalletImplFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String externalPublicDescriptor;
  @override
  @JsonKey()
  final String internalPublicDescriptor;
  @override
  @JsonKey()
  final String mnemonicFingerprint;
  @override
  @JsonKey()
  final String sourceFingerprint;
  @override
  final BBNetwork network;
  @override
  final BBWalletType type;
  @override
  final ScriptType scriptType;
  @override
  final String? name;
  @override
  final String? path;
  @override
  final int? balance;
  @override
  final Balance? fullBalance;
  @override
  final Address? lastGeneratedAddress;
  final List<Address> _myAddressBook;
  @override
  @JsonKey()
  List<Address> get myAddressBook {
    if (_myAddressBook is EqualUnmodifiableListView) return _myAddressBook;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_myAddressBook);
  }

  final List<Address>? _externalAddressBook;
  @override
  List<Address>? get externalAddressBook {
    final value = _externalAddressBook;
    if (value == null) return null;
    if (_externalAddressBook is EqualUnmodifiableListView)
      return _externalAddressBook;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<UTXO> _utxos;
  @override
  @JsonKey()
  List<UTXO> get utxos {
    if (_utxos is EqualUnmodifiableListView) return _utxos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_utxos);
  }

  final List<Transaction> _transactions;
  @override
  @JsonKey()
  List<Transaction> get transactions {
    if (_transactions is EqualUnmodifiableListView) return _transactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_transactions);
  }

  final List<Transaction> _unsignedTxs;
  @override
  @JsonKey()
  List<Transaction> get unsignedTxs {
    if (_unsignedTxs is EqualUnmodifiableListView) return _unsignedTxs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_unsignedTxs);
  }

  final List<SwapTx> _swaps;
  @override
  @JsonKey()
  List<SwapTx> get swaps {
    if (_swaps is EqualUnmodifiableListView) return _swaps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_swaps);
  }

  @override
  @JsonKey()
  final int revKeyIndex;
  @override
  @JsonKey()
  final int subKeyIndex;
// List<String>? labelTags,
// List<Bip329Label>? bip329Labels,
  @override
  @JsonKey()
  final bool backupTested;
  @override
  final DateTime? lastBackupTested;
  @override
  @JsonKey()
  final bool hide;
  @override
  @JsonKey()
  final bool mainWallet;

  @override
  String toString() {
    return 'Wallet(id: $id, externalPublicDescriptor: $externalPublicDescriptor, internalPublicDescriptor: $internalPublicDescriptor, mnemonicFingerprint: $mnemonicFingerprint, sourceFingerprint: $sourceFingerprint, network: $network, type: $type, scriptType: $scriptType, name: $name, path: $path, balance: $balance, fullBalance: $fullBalance, lastGeneratedAddress: $lastGeneratedAddress, myAddressBook: $myAddressBook, externalAddressBook: $externalAddressBook, utxos: $utxos, transactions: $transactions, unsignedTxs: $unsignedTxs, swaps: $swaps, revKeyIndex: $revKeyIndex, subKeyIndex: $subKeyIndex, backupTested: $backupTested, lastBackupTested: $lastBackupTested, hide: $hide, mainWallet: $mainWallet)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WalletImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(
                    other.externalPublicDescriptor, externalPublicDescriptor) ||
                other.externalPublicDescriptor == externalPublicDescriptor) &&
            (identical(
                    other.internalPublicDescriptor, internalPublicDescriptor) ||
                other.internalPublicDescriptor == internalPublicDescriptor) &&
            (identical(other.mnemonicFingerprint, mnemonicFingerprint) ||
                other.mnemonicFingerprint == mnemonicFingerprint) &&
            (identical(other.sourceFingerprint, sourceFingerprint) ||
                other.sourceFingerprint == sourceFingerprint) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.scriptType, scriptType) ||
                other.scriptType == scriptType) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.fullBalance, fullBalance) ||
                other.fullBalance == fullBalance) &&
            (identical(other.lastGeneratedAddress, lastGeneratedAddress) ||
                other.lastGeneratedAddress == lastGeneratedAddress) &&
            const DeepCollectionEquality()
                .equals(other._myAddressBook, _myAddressBook) &&
            const DeepCollectionEquality()
                .equals(other._externalAddressBook, _externalAddressBook) &&
            const DeepCollectionEquality().equals(other._utxos, _utxos) &&
            const DeepCollectionEquality()
                .equals(other._transactions, _transactions) &&
            const DeepCollectionEquality()
                .equals(other._unsignedTxs, _unsignedTxs) &&
            const DeepCollectionEquality().equals(other._swaps, _swaps) &&
            (identical(other.revKeyIndex, revKeyIndex) ||
                other.revKeyIndex == revKeyIndex) &&
            (identical(other.subKeyIndex, subKeyIndex) ||
                other.subKeyIndex == subKeyIndex) &&
            (identical(other.backupTested, backupTested) ||
                other.backupTested == backupTested) &&
            (identical(other.lastBackupTested, lastBackupTested) ||
                other.lastBackupTested == lastBackupTested) &&
            (identical(other.hide, hide) || other.hide == hide) &&
            (identical(other.mainWallet, mainWallet) ||
                other.mainWallet == mainWallet));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        externalPublicDescriptor,
        internalPublicDescriptor,
        mnemonicFingerprint,
        sourceFingerprint,
        network,
        type,
        scriptType,
        name,
        path,
        balance,
        fullBalance,
        lastGeneratedAddress,
        const DeepCollectionEquality().hash(_myAddressBook),
        const DeepCollectionEquality().hash(_externalAddressBook),
        const DeepCollectionEquality().hash(_utxos),
        const DeepCollectionEquality().hash(_transactions),
        const DeepCollectionEquality().hash(_unsignedTxs),
        const DeepCollectionEquality().hash(_swaps),
        revKeyIndex,
        subKeyIndex,
        backupTested,
        lastBackupTested,
        hide,
        mainWallet
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WalletImplCopyWith<_$WalletImpl> get copyWith =>
      __$$WalletImplCopyWithImpl<_$WalletImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WalletImplToJson(
      this,
    );
  }
}

abstract class _Wallet extends Wallet {
  const factory _Wallet(
      {final String id,
      final String externalPublicDescriptor,
      final String internalPublicDescriptor,
      final String mnemonicFingerprint,
      final String sourceFingerprint,
      required final BBNetwork network,
      required final BBWalletType type,
      required final ScriptType scriptType,
      final String? name,
      final String? path,
      final int? balance,
      final Balance? fullBalance,
      final Address? lastGeneratedAddress,
      final List<Address> myAddressBook,
      final List<Address>? externalAddressBook,
      final List<UTXO> utxos,
      final List<Transaction> transactions,
      final List<Transaction> unsignedTxs,
      final List<SwapTx> swaps,
      final int revKeyIndex,
      final int subKeyIndex,
      final bool backupTested,
      final DateTime? lastBackupTested,
      final bool hide,
      final bool mainWallet}) = _$WalletImpl;
  const _Wallet._() : super._();

  factory _Wallet.fromJson(Map<String, dynamic> json) = _$WalletImpl.fromJson;

  @override
  String get id;
  @override
  String get externalPublicDescriptor;
  @override
  String get internalPublicDescriptor;
  @override
  String get mnemonicFingerprint;
  @override
  String get sourceFingerprint;
  @override
  BBNetwork get network;
  @override
  BBWalletType get type;
  @override
  ScriptType get scriptType;
  @override
  String? get name;
  @override
  String? get path;
  @override
  int? get balance;
  @override
  Balance? get fullBalance;
  @override
  Address? get lastGeneratedAddress;
  @override
  List<Address> get myAddressBook;
  @override
  List<Address>? get externalAddressBook;
  @override
  List<UTXO> get utxos;
  @override
  List<Transaction> get transactions;
  @override
  List<Transaction> get unsignedTxs;
  @override
  List<SwapTx> get swaps;
  @override
  int get revKeyIndex;
  @override
  int get subKeyIndex;
  @override // List<String>? labelTags,
// List<Bip329Label>? bip329Labels,
  bool get backupTested;
  @override
  DateTime? get lastBackupTested;
  @override
  bool get hide;
  @override
  bool get mainWallet;
  @override
  @JsonKey(ignore: true)
  _$$WalletImplCopyWith<_$WalletImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Balance _$BalanceFromJson(Map<String, dynamic> json) {
  return _Balance.fromJson(json);
}

/// @nodoc
mixin _$Balance {
  int get immature => throw _privateConstructorUsedError;
  int get trustedPending => throw _privateConstructorUsedError;
  int get untrustedPending => throw _privateConstructorUsedError;
  int get confirmed => throw _privateConstructorUsedError;
  int get spendable => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BalanceCopyWith<Balance> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BalanceCopyWith<$Res> {
  factory $BalanceCopyWith(Balance value, $Res Function(Balance) then) =
      _$BalanceCopyWithImpl<$Res, Balance>;
  @useResult
  $Res call(
      {int immature,
      int trustedPending,
      int untrustedPending,
      int confirmed,
      int spendable,
      int total});
}

/// @nodoc
class _$BalanceCopyWithImpl<$Res, $Val extends Balance>
    implements $BalanceCopyWith<$Res> {
  _$BalanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? immature = null,
    Object? trustedPending = null,
    Object? untrustedPending = null,
    Object? confirmed = null,
    Object? spendable = null,
    Object? total = null,
  }) {
    return _then(_value.copyWith(
      immature: null == immature
          ? _value.immature
          : immature // ignore: cast_nullable_to_non_nullable
              as int,
      trustedPending: null == trustedPending
          ? _value.trustedPending
          : trustedPending // ignore: cast_nullable_to_non_nullable
              as int,
      untrustedPending: null == untrustedPending
          ? _value.untrustedPending
          : untrustedPending // ignore: cast_nullable_to_non_nullable
              as int,
      confirmed: null == confirmed
          ? _value.confirmed
          : confirmed // ignore: cast_nullable_to_non_nullable
              as int,
      spendable: null == spendable
          ? _value.spendable
          : spendable // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BalanceImplCopyWith<$Res> implements $BalanceCopyWith<$Res> {
  factory _$$BalanceImplCopyWith(
          _$BalanceImpl value, $Res Function(_$BalanceImpl) then) =
      __$$BalanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int immature,
      int trustedPending,
      int untrustedPending,
      int confirmed,
      int spendable,
      int total});
}

/// @nodoc
class __$$BalanceImplCopyWithImpl<$Res>
    extends _$BalanceCopyWithImpl<$Res, _$BalanceImpl>
    implements _$$BalanceImplCopyWith<$Res> {
  __$$BalanceImplCopyWithImpl(
      _$BalanceImpl _value, $Res Function(_$BalanceImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? immature = null,
    Object? trustedPending = null,
    Object? untrustedPending = null,
    Object? confirmed = null,
    Object? spendable = null,
    Object? total = null,
  }) {
    return _then(_$BalanceImpl(
      immature: null == immature
          ? _value.immature
          : immature // ignore: cast_nullable_to_non_nullable
              as int,
      trustedPending: null == trustedPending
          ? _value.trustedPending
          : trustedPending // ignore: cast_nullable_to_non_nullable
              as int,
      untrustedPending: null == untrustedPending
          ? _value.untrustedPending
          : untrustedPending // ignore: cast_nullable_to_non_nullable
              as int,
      confirmed: null == confirmed
          ? _value.confirmed
          : confirmed // ignore: cast_nullable_to_non_nullable
              as int,
      spendable: null == spendable
          ? _value.spendable
          : spendable // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BalanceImpl extends _Balance {
  const _$BalanceImpl(
      {required this.immature,
      required this.trustedPending,
      required this.untrustedPending,
      required this.confirmed,
      required this.spendable,
      required this.total})
      : super._();

  factory _$BalanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$BalanceImplFromJson(json);

  @override
  final int immature;
  @override
  final int trustedPending;
  @override
  final int untrustedPending;
  @override
  final int confirmed;
  @override
  final int spendable;
  @override
  final int total;

  @override
  String toString() {
    return 'Balance(immature: $immature, trustedPending: $trustedPending, untrustedPending: $untrustedPending, confirmed: $confirmed, spendable: $spendable, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BalanceImpl &&
            (identical(other.immature, immature) ||
                other.immature == immature) &&
            (identical(other.trustedPending, trustedPending) ||
                other.trustedPending == trustedPending) &&
            (identical(other.untrustedPending, untrustedPending) ||
                other.untrustedPending == untrustedPending) &&
            (identical(other.confirmed, confirmed) ||
                other.confirmed == confirmed) &&
            (identical(other.spendable, spendable) ||
                other.spendable == spendable) &&
            (identical(other.total, total) || other.total == total));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, immature, trustedPending,
      untrustedPending, confirmed, spendable, total);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BalanceImplCopyWith<_$BalanceImpl> get copyWith =>
      __$$BalanceImplCopyWithImpl<_$BalanceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BalanceImplToJson(
      this,
    );
  }
}

abstract class _Balance extends Balance {
  const factory _Balance(
      {required final int immature,
      required final int trustedPending,
      required final int untrustedPending,
      required final int confirmed,
      required final int spendable,
      required final int total}) = _$BalanceImpl;
  const _Balance._() : super._();

  factory _Balance.fromJson(Map<String, dynamic> json) = _$BalanceImpl.fromJson;

  @override
  int get immature;
  @override
  int get trustedPending;
  @override
  int get untrustedPending;
  @override
  int get confirmed;
  @override
  int get spendable;
  @override
  int get total;
  @override
  @JsonKey(ignore: true)
  _$$BalanceImplCopyWith<_$BalanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
