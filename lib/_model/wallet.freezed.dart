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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

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
  List<Address> get addresses => throw _privateConstructorUsedError;
  Address? get lastUnusedAddress => throw _privateConstructorUsedError;
  List<Address>? get toAddresses => throw _privateConstructorUsedError;
  List<Transaction> get transactions => throw _privateConstructorUsedError;
  List<String>? get labelTags => throw _privateConstructorUsedError;
  List<Bip329Label>? get bip329Labels => throw _privateConstructorUsedError;
  bool get backupTested => throw _privateConstructorUsedError;
  bool get hide => throw _privateConstructorUsedError;

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
      List<Address> addresses,
      Address? lastUnusedAddress,
      List<Address>? toAddresses,
      List<Transaction> transactions,
      List<String>? labelTags,
      List<Bip329Label>? bip329Labels,
      bool backupTested,
      bool hide});

  $AddressCopyWith<$Res>? get lastUnusedAddress;
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
    Object? addresses = null,
    Object? lastUnusedAddress = freezed,
    Object? toAddresses = freezed,
    Object? transactions = null,
    Object? labelTags = freezed,
    Object? bip329Labels = freezed,
    Object? backupTested = null,
    Object? hide = null,
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
      addresses: null == addresses
          ? _value.addresses
          : addresses // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      lastUnusedAddress: freezed == lastUnusedAddress
          ? _value.lastUnusedAddress
          : lastUnusedAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
      toAddresses: freezed == toAddresses
          ? _value.toAddresses
          : toAddresses // ignore: cast_nullable_to_non_nullable
              as List<Address>?,
      transactions: null == transactions
          ? _value.transactions
          : transactions // ignore: cast_nullable_to_non_nullable
              as List<Transaction>,
      labelTags: freezed == labelTags
          ? _value.labelTags
          : labelTags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      bip329Labels: freezed == bip329Labels
          ? _value.bip329Labels
          : bip329Labels // ignore: cast_nullable_to_non_nullable
              as List<Bip329Label>?,
      backupTested: null == backupTested
          ? _value.backupTested
          : backupTested // ignore: cast_nullable_to_non_nullable
              as bool,
      hide: null == hide
          ? _value.hide
          : hide // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $AddressCopyWith<$Res>? get lastUnusedAddress {
    if (_value.lastUnusedAddress == null) {
      return null;
    }

    return $AddressCopyWith<$Res>(_value.lastUnusedAddress!, (value) {
      return _then(_value.copyWith(lastUnusedAddress: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$_WalletCopyWith<$Res> implements $WalletCopyWith<$Res> {
  factory _$$_WalletCopyWith(_$_Wallet value, $Res Function(_$_Wallet) then) =
      __$$_WalletCopyWithImpl<$Res>;
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
      List<Address> addresses,
      Address? lastUnusedAddress,
      List<Address>? toAddresses,
      List<Transaction> transactions,
      List<String>? labelTags,
      List<Bip329Label>? bip329Labels,
      bool backupTested,
      bool hide});

  @override
  $AddressCopyWith<$Res>? get lastUnusedAddress;
}

/// @nodoc
class __$$_WalletCopyWithImpl<$Res>
    extends _$WalletCopyWithImpl<$Res, _$_Wallet>
    implements _$$_WalletCopyWith<$Res> {
  __$$_WalletCopyWithImpl(_$_Wallet _value, $Res Function(_$_Wallet) _then)
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
    Object? addresses = null,
    Object? lastUnusedAddress = freezed,
    Object? toAddresses = freezed,
    Object? transactions = null,
    Object? labelTags = freezed,
    Object? bip329Labels = freezed,
    Object? backupTested = null,
    Object? hide = null,
  }) {
    return _then(_$_Wallet(
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
      addresses: null == addresses
          ? _value._addresses
          : addresses // ignore: cast_nullable_to_non_nullable
              as List<Address>,
      lastUnusedAddress: freezed == lastUnusedAddress
          ? _value.lastUnusedAddress
          : lastUnusedAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
      toAddresses: freezed == toAddresses
          ? _value._toAddresses
          : toAddresses // ignore: cast_nullable_to_non_nullable
              as List<Address>?,
      transactions: null == transactions
          ? _value._transactions
          : transactions // ignore: cast_nullable_to_non_nullable
              as List<Transaction>,
      labelTags: freezed == labelTags
          ? _value._labelTags
          : labelTags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      bip329Labels: freezed == bip329Labels
          ? _value._bip329Labels
          : bip329Labels // ignore: cast_nullable_to_non_nullable
              as List<Bip329Label>?,
      backupTested: null == backupTested
          ? _value.backupTested
          : backupTested // ignore: cast_nullable_to_non_nullable
              as bool,
      hide: null == hide
          ? _value.hide
          : hide // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_Wallet extends _Wallet {
  const _$_Wallet(
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
      final List<Address> addresses = const [],
      this.lastUnusedAddress,
      final List<Address>? toAddresses,
      final List<Transaction> transactions = const [],
      final List<String>? labelTags,
      final List<Bip329Label>? bip329Labels,
      this.backupTested = false,
      this.hide = false})
      : _addresses = addresses,
        _toAddresses = toAddresses,
        _transactions = transactions,
        _labelTags = labelTags,
        _bip329Labels = bip329Labels,
        super._();

  factory _$_Wallet.fromJson(Map<String, dynamic> json) =>
      _$$_WalletFromJson(json);

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
  final List<Address> _addresses;
  @override
  @JsonKey()
  List<Address> get addresses {
    if (_addresses is EqualUnmodifiableListView) return _addresses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_addresses);
  }

  @override
  final Address? lastUnusedAddress;
  final List<Address>? _toAddresses;
  @override
  List<Address>? get toAddresses {
    final value = _toAddresses;
    if (value == null) return null;
    if (_toAddresses is EqualUnmodifiableListView) return _toAddresses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<Transaction> _transactions;
  @override
  @JsonKey()
  List<Transaction> get transactions {
    if (_transactions is EqualUnmodifiableListView) return _transactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_transactions);
  }

  final List<String>? _labelTags;
  @override
  List<String>? get labelTags {
    final value = _labelTags;
    if (value == null) return null;
    if (_labelTags is EqualUnmodifiableListView) return _labelTags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<Bip329Label>? _bip329Labels;
  @override
  List<Bip329Label>? get bip329Labels {
    final value = _bip329Labels;
    if (value == null) return null;
    if (_bip329Labels is EqualUnmodifiableListView) return _bip329Labels;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final bool backupTested;
  @override
  @JsonKey()
  final bool hide;

  @override
  String toString() {
    return 'Wallet(id: $id, externalPublicDescriptor: $externalPublicDescriptor, internalPublicDescriptor: $internalPublicDescriptor, mnemonicFingerprint: $mnemonicFingerprint, sourceFingerprint: $sourceFingerprint, network: $network, type: $type, scriptType: $scriptType, name: $name, path: $path, balance: $balance, addresses: $addresses, lastUnusedAddress: $lastUnusedAddress, toAddresses: $toAddresses, transactions: $transactions, labelTags: $labelTags, bip329Labels: $bip329Labels, backupTested: $backupTested, hide: $hide)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_Wallet &&
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
            const DeepCollectionEquality()
                .equals(other._addresses, _addresses) &&
            (identical(other.lastUnusedAddress, lastUnusedAddress) ||
                other.lastUnusedAddress == lastUnusedAddress) &&
            const DeepCollectionEquality()
                .equals(other._toAddresses, _toAddresses) &&
            const DeepCollectionEquality()
                .equals(other._transactions, _transactions) &&
            const DeepCollectionEquality()
                .equals(other._labelTags, _labelTags) &&
            const DeepCollectionEquality()
                .equals(other._bip329Labels, _bip329Labels) &&
            (identical(other.backupTested, backupTested) ||
                other.backupTested == backupTested) &&
            (identical(other.hide, hide) || other.hide == hide));
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
        const DeepCollectionEquality().hash(_addresses),
        lastUnusedAddress,
        const DeepCollectionEquality().hash(_toAddresses),
        const DeepCollectionEquality().hash(_transactions),
        const DeepCollectionEquality().hash(_labelTags),
        const DeepCollectionEquality().hash(_bip329Labels),
        backupTested,
        hide
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_WalletCopyWith<_$_Wallet> get copyWith =>
      __$$_WalletCopyWithImpl<_$_Wallet>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_WalletToJson(
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
      final List<Address> addresses,
      final Address? lastUnusedAddress,
      final List<Address>? toAddresses,
      final List<Transaction> transactions,
      final List<String>? labelTags,
      final List<Bip329Label>? bip329Labels,
      final bool backupTested,
      final bool hide}) = _$_Wallet;
  const _Wallet._() : super._();

  factory _Wallet.fromJson(Map<String, dynamic> json) = _$_Wallet.fromJson;

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
  List<Address> get addresses;
  @override
  Address? get lastUnusedAddress;
  @override
  List<Address>? get toAddresses;
  @override
  List<Transaction> get transactions;
  @override
  List<String>? get labelTags;
  @override
  List<Bip329Label>? get bip329Labels;
  @override
  bool get backupTested;
  @override
  bool get hide;
  @override
  @JsonKey(ignore: true)
  _$$_WalletCopyWith<_$_Wallet> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$Balance {
  int get immature => throw _privateConstructorUsedError;
  int get trustedPending => throw _privateConstructorUsedError;
  int get untrustedPending => throw _privateConstructorUsedError;
  int get confirmed => throw _privateConstructorUsedError;
  int get spendable => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;

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
abstract class _$$_BalanceCopyWith<$Res> implements $BalanceCopyWith<$Res> {
  factory _$$_BalanceCopyWith(
          _$_Balance value, $Res Function(_$_Balance) then) =
      __$$_BalanceCopyWithImpl<$Res>;
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
class __$$_BalanceCopyWithImpl<$Res>
    extends _$BalanceCopyWithImpl<$Res, _$_Balance>
    implements _$$_BalanceCopyWith<$Res> {
  __$$_BalanceCopyWithImpl(_$_Balance _value, $Res Function(_$_Balance) _then)
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
    return _then(_$_Balance(
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

class _$_Balance implements _Balance {
  const _$_Balance(
      {required this.immature,
      required this.trustedPending,
      required this.untrustedPending,
      required this.confirmed,
      required this.spendable,
      required this.total});

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
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_Balance &&
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

  @override
  int get hashCode => Object.hash(runtimeType, immature, trustedPending,
      untrustedPending, confirmed, spendable, total);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_BalanceCopyWith<_$_Balance> get copyWith =>
      __$$_BalanceCopyWithImpl<_$_Balance>(this, _$identity);
}

abstract class _Balance implements Balance {
  const factory _Balance(
      {required final int immature,
      required final int trustedPending,
      required final int untrustedPending,
      required final int confirmed,
      required final int spendable,
      required final int total}) = _$_Balance;

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
  _$$_BalanceCopyWith<_$_Balance> get copyWith =>
      throw _privateConstructorUsedError;
}
