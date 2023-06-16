// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'electrum.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

ElectrumNetwork _$ElectrumNetworkFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'bullbitcoin':
      return _BullbitcoinElectrumNetwork.fromJson(json);
    case 'defaultElectrum':
      return _DefaultElectrumNetwork.fromJson(json);
    case 'custom':
      return _CustomElectrumNetwork.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'ElectrumNetwork',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$ElectrumNetwork {
  String get mainnet => throw _privateConstructorUsedError;
  String get testnet => throw _privateConstructorUsedError;
  int get stopGap => throw _privateConstructorUsedError;
  int get timeout => throw _privateConstructorUsedError;
  int get retry => throw _privateConstructorUsedError;
  bool get validateDomain => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String mainnet, String testnet, int stopGap,
            int timeout, int retry, bool validateDomain, String name)
        bullbitcoin,
    required TResult Function(String mainnet, String testnet, int stopGap,
            int timeout, int retry, bool validateDomain, String name)
        defaultElectrum,
    required TResult Function(String mainnet, String testnet, int stopGap,
            int timeout, int retry, bool validateDomain, String name)
        custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        bullbitcoin,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        defaultElectrum,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        bullbitcoin,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        defaultElectrum,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        custom,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_BullbitcoinElectrumNetwork value) bullbitcoin,
    required TResult Function(_DefaultElectrumNetwork value) defaultElectrum,
    required TResult Function(_CustomElectrumNetwork value) custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_BullbitcoinElectrumNetwork value)? bullbitcoin,
    TResult? Function(_DefaultElectrumNetwork value)? defaultElectrum,
    TResult? Function(_CustomElectrumNetwork value)? custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_BullbitcoinElectrumNetwork value)? bullbitcoin,
    TResult Function(_DefaultElectrumNetwork value)? defaultElectrum,
    TResult Function(_CustomElectrumNetwork value)? custom,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ElectrumNetworkCopyWith<ElectrumNetwork> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ElectrumNetworkCopyWith<$Res> {
  factory $ElectrumNetworkCopyWith(
          ElectrumNetwork value, $Res Function(ElectrumNetwork) then) =
      _$ElectrumNetworkCopyWithImpl<$Res, ElectrumNetwork>;
  @useResult
  $Res call(
      {String mainnet,
      String testnet,
      int stopGap,
      int timeout,
      int retry,
      bool validateDomain,
      String name});
}

/// @nodoc
class _$ElectrumNetworkCopyWithImpl<$Res, $Val extends ElectrumNetwork>
    implements $ElectrumNetworkCopyWith<$Res> {
  _$ElectrumNetworkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mainnet = null,
    Object? testnet = null,
    Object? stopGap = null,
    Object? timeout = null,
    Object? retry = null,
    Object? validateDomain = null,
    Object? name = null,
  }) {
    return _then(_value.copyWith(
      mainnet: null == mainnet
          ? _value.mainnet
          : mainnet // ignore: cast_nullable_to_non_nullable
              as String,
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as String,
      stopGap: null == stopGap
          ? _value.stopGap
          : stopGap // ignore: cast_nullable_to_non_nullable
              as int,
      timeout: null == timeout
          ? _value.timeout
          : timeout // ignore: cast_nullable_to_non_nullable
              as int,
      retry: null == retry
          ? _value.retry
          : retry // ignore: cast_nullable_to_non_nullable
              as int,
      validateDomain: null == validateDomain
          ? _value.validateDomain
          : validateDomain // ignore: cast_nullable_to_non_nullable
              as bool,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_BullbitcoinElectrumNetworkCopyWith<$Res>
    implements $ElectrumNetworkCopyWith<$Res> {
  factory _$$_BullbitcoinElectrumNetworkCopyWith(
          _$_BullbitcoinElectrumNetwork value,
          $Res Function(_$_BullbitcoinElectrumNetwork) then) =
      __$$_BullbitcoinElectrumNetworkCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String mainnet,
      String testnet,
      int stopGap,
      int timeout,
      int retry,
      bool validateDomain,
      String name});
}

/// @nodoc
class __$$_BullbitcoinElectrumNetworkCopyWithImpl<$Res>
    extends _$ElectrumNetworkCopyWithImpl<$Res, _$_BullbitcoinElectrumNetwork>
    implements _$$_BullbitcoinElectrumNetworkCopyWith<$Res> {
  __$$_BullbitcoinElectrumNetworkCopyWithImpl(
      _$_BullbitcoinElectrumNetwork _value,
      $Res Function(_$_BullbitcoinElectrumNetwork) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mainnet = null,
    Object? testnet = null,
    Object? stopGap = null,
    Object? timeout = null,
    Object? retry = null,
    Object? validateDomain = null,
    Object? name = null,
  }) {
    return _then(_$_BullbitcoinElectrumNetwork(
      mainnet: null == mainnet
          ? _value.mainnet
          : mainnet // ignore: cast_nullable_to_non_nullable
              as String,
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as String,
      stopGap: null == stopGap
          ? _value.stopGap
          : stopGap // ignore: cast_nullable_to_non_nullable
              as int,
      timeout: null == timeout
          ? _value.timeout
          : timeout // ignore: cast_nullable_to_non_nullable
              as int,
      retry: null == retry
          ? _value.retry
          : retry // ignore: cast_nullable_to_non_nullable
              as int,
      validateDomain: null == validateDomain
          ? _value.validateDomain
          : validateDomain // ignore: cast_nullable_to_non_nullable
              as bool,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_BullbitcoinElectrumNetwork implements _BullbitcoinElectrumNetwork {
  const _$_BullbitcoinElectrumNetwork(
      {this.mainnet = 'ssl://$bbelectrum:50002',
      this.testnet = 'ssl://$bbelectrum:60002',
      this.stopGap = 20,
      this.timeout = 5,
      this.retry = 5,
      this.validateDomain = true,
      this.name = 'bullbitcoin',
      final String? $type})
      : $type = $type ?? 'bullbitcoin';

  factory _$_BullbitcoinElectrumNetwork.fromJson(Map<String, dynamic> json) =>
      _$$_BullbitcoinElectrumNetworkFromJson(json);

  @override
  @JsonKey()
  final String mainnet;
  @override
  @JsonKey()
  final String testnet;
  @override
  @JsonKey()
  final int stopGap;
  @override
  @JsonKey()
  final int timeout;
  @override
  @JsonKey()
  final int retry;
  @override
  @JsonKey()
  final bool validateDomain;
  @override
  @JsonKey()
  final String name;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'ElectrumNetwork.bullbitcoin(mainnet: $mainnet, testnet: $testnet, stopGap: $stopGap, timeout: $timeout, retry: $retry, validateDomain: $validateDomain, name: $name)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_BullbitcoinElectrumNetwork &&
            (identical(other.mainnet, mainnet) || other.mainnet == mainnet) &&
            (identical(other.testnet, testnet) || other.testnet == testnet) &&
            (identical(other.stopGap, stopGap) || other.stopGap == stopGap) &&
            (identical(other.timeout, timeout) || other.timeout == timeout) &&
            (identical(other.retry, retry) || other.retry == retry) &&
            (identical(other.validateDomain, validateDomain) ||
                other.validateDomain == validateDomain) &&
            (identical(other.name, name) || other.name == name));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, mainnet, testnet, stopGap,
      timeout, retry, validateDomain, name);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_BullbitcoinElectrumNetworkCopyWith<_$_BullbitcoinElectrumNetwork>
      get copyWith => __$$_BullbitcoinElectrumNetworkCopyWithImpl<
          _$_BullbitcoinElectrumNetwork>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String mainnet, String testnet, int stopGap,
            int timeout, int retry, bool validateDomain, String name)
        bullbitcoin,
    required TResult Function(String mainnet, String testnet, int stopGap,
            int timeout, int retry, bool validateDomain, String name)
        defaultElectrum,
    required TResult Function(String mainnet, String testnet, int stopGap,
            int timeout, int retry, bool validateDomain, String name)
        custom,
  }) {
    return bullbitcoin(
        mainnet, testnet, stopGap, timeout, retry, validateDomain, name);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        bullbitcoin,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        defaultElectrum,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        custom,
  }) {
    return bullbitcoin?.call(
        mainnet, testnet, stopGap, timeout, retry, validateDomain, name);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        bullbitcoin,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        defaultElectrum,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        custom,
    required TResult orElse(),
  }) {
    if (bullbitcoin != null) {
      return bullbitcoin(
          mainnet, testnet, stopGap, timeout, retry, validateDomain, name);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_BullbitcoinElectrumNetwork value) bullbitcoin,
    required TResult Function(_DefaultElectrumNetwork value) defaultElectrum,
    required TResult Function(_CustomElectrumNetwork value) custom,
  }) {
    return bullbitcoin(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_BullbitcoinElectrumNetwork value)? bullbitcoin,
    TResult? Function(_DefaultElectrumNetwork value)? defaultElectrum,
    TResult? Function(_CustomElectrumNetwork value)? custom,
  }) {
    return bullbitcoin?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_BullbitcoinElectrumNetwork value)? bullbitcoin,
    TResult Function(_DefaultElectrumNetwork value)? defaultElectrum,
    TResult Function(_CustomElectrumNetwork value)? custom,
    required TResult orElse(),
  }) {
    if (bullbitcoin != null) {
      return bullbitcoin(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_BullbitcoinElectrumNetworkToJson(
      this,
    );
  }
}

abstract class _BullbitcoinElectrumNetwork implements ElectrumNetwork {
  const factory _BullbitcoinElectrumNetwork(
      {final String mainnet,
      final String testnet,
      final int stopGap,
      final int timeout,
      final int retry,
      final bool validateDomain,
      final String name}) = _$_BullbitcoinElectrumNetwork;

  factory _BullbitcoinElectrumNetwork.fromJson(Map<String, dynamic> json) =
      _$_BullbitcoinElectrumNetwork.fromJson;

  @override
  String get mainnet;
  @override
  String get testnet;
  @override
  int get stopGap;
  @override
  int get timeout;
  @override
  int get retry;
  @override
  bool get validateDomain;
  @override
  String get name;
  @override
  @JsonKey(ignore: true)
  _$$_BullbitcoinElectrumNetworkCopyWith<_$_BullbitcoinElectrumNetwork>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_DefaultElectrumNetworkCopyWith<$Res>
    implements $ElectrumNetworkCopyWith<$Res> {
  factory _$$_DefaultElectrumNetworkCopyWith(_$_DefaultElectrumNetwork value,
          $Res Function(_$_DefaultElectrumNetwork) then) =
      __$$_DefaultElectrumNetworkCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String mainnet,
      String testnet,
      int stopGap,
      int timeout,
      int retry,
      bool validateDomain,
      String name});
}

/// @nodoc
class __$$_DefaultElectrumNetworkCopyWithImpl<$Res>
    extends _$ElectrumNetworkCopyWithImpl<$Res, _$_DefaultElectrumNetwork>
    implements _$$_DefaultElectrumNetworkCopyWith<$Res> {
  __$$_DefaultElectrumNetworkCopyWithImpl(_$_DefaultElectrumNetwork _value,
      $Res Function(_$_DefaultElectrumNetwork) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mainnet = null,
    Object? testnet = null,
    Object? stopGap = null,
    Object? timeout = null,
    Object? retry = null,
    Object? validateDomain = null,
    Object? name = null,
  }) {
    return _then(_$_DefaultElectrumNetwork(
      mainnet: null == mainnet
          ? _value.mainnet
          : mainnet // ignore: cast_nullable_to_non_nullable
              as String,
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as String,
      stopGap: null == stopGap
          ? _value.stopGap
          : stopGap // ignore: cast_nullable_to_non_nullable
              as int,
      timeout: null == timeout
          ? _value.timeout
          : timeout // ignore: cast_nullable_to_non_nullable
              as int,
      retry: null == retry
          ? _value.retry
          : retry // ignore: cast_nullable_to_non_nullable
              as int,
      validateDomain: null == validateDomain
          ? _value.validateDomain
          : validateDomain // ignore: cast_nullable_to_non_nullable
              as bool,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_DefaultElectrumNetwork implements _DefaultElectrumNetwork {
  const _$_DefaultElectrumNetwork(
      {this.mainnet = 'ssl://$openelectrum:50002',
      this.testnet = 'ssl://$openelectrum:60002',
      this.stopGap = 20,
      this.timeout = 5,
      this.retry = 5,
      this.validateDomain = true,
      this.name = 'default',
      final String? $type})
      : $type = $type ?? 'defaultElectrum';

  factory _$_DefaultElectrumNetwork.fromJson(Map<String, dynamic> json) =>
      _$$_DefaultElectrumNetworkFromJson(json);

  @override
  @JsonKey()
  final String mainnet;
  @override
  @JsonKey()
  final String testnet;
  @override
  @JsonKey()
  final int stopGap;
  @override
  @JsonKey()
  final int timeout;
  @override
  @JsonKey()
  final int retry;
  @override
  @JsonKey()
  final bool validateDomain;
  @override
  @JsonKey()
  final String name;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'ElectrumNetwork.defaultElectrum(mainnet: $mainnet, testnet: $testnet, stopGap: $stopGap, timeout: $timeout, retry: $retry, validateDomain: $validateDomain, name: $name)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_DefaultElectrumNetwork &&
            (identical(other.mainnet, mainnet) || other.mainnet == mainnet) &&
            (identical(other.testnet, testnet) || other.testnet == testnet) &&
            (identical(other.stopGap, stopGap) || other.stopGap == stopGap) &&
            (identical(other.timeout, timeout) || other.timeout == timeout) &&
            (identical(other.retry, retry) || other.retry == retry) &&
            (identical(other.validateDomain, validateDomain) ||
                other.validateDomain == validateDomain) &&
            (identical(other.name, name) || other.name == name));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, mainnet, testnet, stopGap,
      timeout, retry, validateDomain, name);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_DefaultElectrumNetworkCopyWith<_$_DefaultElectrumNetwork> get copyWith =>
      __$$_DefaultElectrumNetworkCopyWithImpl<_$_DefaultElectrumNetwork>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String mainnet, String testnet, int stopGap,
            int timeout, int retry, bool validateDomain, String name)
        bullbitcoin,
    required TResult Function(String mainnet, String testnet, int stopGap,
            int timeout, int retry, bool validateDomain, String name)
        defaultElectrum,
    required TResult Function(String mainnet, String testnet, int stopGap,
            int timeout, int retry, bool validateDomain, String name)
        custom,
  }) {
    return defaultElectrum(
        mainnet, testnet, stopGap, timeout, retry, validateDomain, name);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        bullbitcoin,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        defaultElectrum,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        custom,
  }) {
    return defaultElectrum?.call(
        mainnet, testnet, stopGap, timeout, retry, validateDomain, name);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        bullbitcoin,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        defaultElectrum,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        custom,
    required TResult orElse(),
  }) {
    if (defaultElectrum != null) {
      return defaultElectrum(
          mainnet, testnet, stopGap, timeout, retry, validateDomain, name);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_BullbitcoinElectrumNetwork value) bullbitcoin,
    required TResult Function(_DefaultElectrumNetwork value) defaultElectrum,
    required TResult Function(_CustomElectrumNetwork value) custom,
  }) {
    return defaultElectrum(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_BullbitcoinElectrumNetwork value)? bullbitcoin,
    TResult? Function(_DefaultElectrumNetwork value)? defaultElectrum,
    TResult? Function(_CustomElectrumNetwork value)? custom,
  }) {
    return defaultElectrum?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_BullbitcoinElectrumNetwork value)? bullbitcoin,
    TResult Function(_DefaultElectrumNetwork value)? defaultElectrum,
    TResult Function(_CustomElectrumNetwork value)? custom,
    required TResult orElse(),
  }) {
    if (defaultElectrum != null) {
      return defaultElectrum(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_DefaultElectrumNetworkToJson(
      this,
    );
  }
}

abstract class _DefaultElectrumNetwork implements ElectrumNetwork {
  const factory _DefaultElectrumNetwork(
      {final String mainnet,
      final String testnet,
      final int stopGap,
      final int timeout,
      final int retry,
      final bool validateDomain,
      final String name}) = _$_DefaultElectrumNetwork;

  factory _DefaultElectrumNetwork.fromJson(Map<String, dynamic> json) =
      _$_DefaultElectrumNetwork.fromJson;

  @override
  String get mainnet;
  @override
  String get testnet;
  @override
  int get stopGap;
  @override
  int get timeout;
  @override
  int get retry;
  @override
  bool get validateDomain;
  @override
  String get name;
  @override
  @JsonKey(ignore: true)
  _$$_DefaultElectrumNetworkCopyWith<_$_DefaultElectrumNetwork> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_CustomElectrumNetworkCopyWith<$Res>
    implements $ElectrumNetworkCopyWith<$Res> {
  factory _$$_CustomElectrumNetworkCopyWith(_$_CustomElectrumNetwork value,
          $Res Function(_$_CustomElectrumNetwork) then) =
      __$$_CustomElectrumNetworkCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String mainnet,
      String testnet,
      int stopGap,
      int timeout,
      int retry,
      bool validateDomain,
      String name});
}

/// @nodoc
class __$$_CustomElectrumNetworkCopyWithImpl<$Res>
    extends _$ElectrumNetworkCopyWithImpl<$Res, _$_CustomElectrumNetwork>
    implements _$$_CustomElectrumNetworkCopyWith<$Res> {
  __$$_CustomElectrumNetworkCopyWithImpl(_$_CustomElectrumNetwork _value,
      $Res Function(_$_CustomElectrumNetwork) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mainnet = null,
    Object? testnet = null,
    Object? stopGap = null,
    Object? timeout = null,
    Object? retry = null,
    Object? validateDomain = null,
    Object? name = null,
  }) {
    return _then(_$_CustomElectrumNetwork(
      mainnet: null == mainnet
          ? _value.mainnet
          : mainnet // ignore: cast_nullable_to_non_nullable
              as String,
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as String,
      stopGap: null == stopGap
          ? _value.stopGap
          : stopGap // ignore: cast_nullable_to_non_nullable
              as int,
      timeout: null == timeout
          ? _value.timeout
          : timeout // ignore: cast_nullable_to_non_nullable
              as int,
      retry: null == retry
          ? _value.retry
          : retry // ignore: cast_nullable_to_non_nullable
              as int,
      validateDomain: null == validateDomain
          ? _value.validateDomain
          : validateDomain // ignore: cast_nullable_to_non_nullable
              as bool,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_CustomElectrumNetwork implements _CustomElectrumNetwork {
  const _$_CustomElectrumNetwork(
      {required this.mainnet,
      required this.testnet,
      this.stopGap = 20,
      this.timeout = 5,
      this.retry = 5,
      this.validateDomain = true,
      this.name = 'custom',
      final String? $type})
      : $type = $type ?? 'custom';

  factory _$_CustomElectrumNetwork.fromJson(Map<String, dynamic> json) =>
      _$$_CustomElectrumNetworkFromJson(json);

  @override
  final String mainnet;
  @override
  final String testnet;
  @override
  @JsonKey()
  final int stopGap;
  @override
  @JsonKey()
  final int timeout;
  @override
  @JsonKey()
  final int retry;
  @override
  @JsonKey()
  final bool validateDomain;
  @override
  @JsonKey()
  final String name;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'ElectrumNetwork.custom(mainnet: $mainnet, testnet: $testnet, stopGap: $stopGap, timeout: $timeout, retry: $retry, validateDomain: $validateDomain, name: $name)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_CustomElectrumNetwork &&
            (identical(other.mainnet, mainnet) || other.mainnet == mainnet) &&
            (identical(other.testnet, testnet) || other.testnet == testnet) &&
            (identical(other.stopGap, stopGap) || other.stopGap == stopGap) &&
            (identical(other.timeout, timeout) || other.timeout == timeout) &&
            (identical(other.retry, retry) || other.retry == retry) &&
            (identical(other.validateDomain, validateDomain) ||
                other.validateDomain == validateDomain) &&
            (identical(other.name, name) || other.name == name));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, mainnet, testnet, stopGap,
      timeout, retry, validateDomain, name);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_CustomElectrumNetworkCopyWith<_$_CustomElectrumNetwork> get copyWith =>
      __$$_CustomElectrumNetworkCopyWithImpl<_$_CustomElectrumNetwork>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String mainnet, String testnet, int stopGap,
            int timeout, int retry, bool validateDomain, String name)
        bullbitcoin,
    required TResult Function(String mainnet, String testnet, int stopGap,
            int timeout, int retry, bool validateDomain, String name)
        defaultElectrum,
    required TResult Function(String mainnet, String testnet, int stopGap,
            int timeout, int retry, bool validateDomain, String name)
        custom,
  }) {
    return custom(
        mainnet, testnet, stopGap, timeout, retry, validateDomain, name);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        bullbitcoin,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        defaultElectrum,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        custom,
  }) {
    return custom?.call(
        mainnet, testnet, stopGap, timeout, retry, validateDomain, name);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        bullbitcoin,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        defaultElectrum,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name)?
        custom,
    required TResult orElse(),
  }) {
    if (custom != null) {
      return custom(
          mainnet, testnet, stopGap, timeout, retry, validateDomain, name);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_BullbitcoinElectrumNetwork value) bullbitcoin,
    required TResult Function(_DefaultElectrumNetwork value) defaultElectrum,
    required TResult Function(_CustomElectrumNetwork value) custom,
  }) {
    return custom(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_BullbitcoinElectrumNetwork value)? bullbitcoin,
    TResult? Function(_DefaultElectrumNetwork value)? defaultElectrum,
    TResult? Function(_CustomElectrumNetwork value)? custom,
  }) {
    return custom?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_BullbitcoinElectrumNetwork value)? bullbitcoin,
    TResult Function(_DefaultElectrumNetwork value)? defaultElectrum,
    TResult Function(_CustomElectrumNetwork value)? custom,
    required TResult orElse(),
  }) {
    if (custom != null) {
      return custom(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_CustomElectrumNetworkToJson(
      this,
    );
  }
}

abstract class _CustomElectrumNetwork implements ElectrumNetwork {
  const factory _CustomElectrumNetwork(
      {required final String mainnet,
      required final String testnet,
      final int stopGap,
      final int timeout,
      final int retry,
      final bool validateDomain,
      final String name}) = _$_CustomElectrumNetwork;

  factory _CustomElectrumNetwork.fromJson(Map<String, dynamic> json) =
      _$_CustomElectrumNetwork.fromJson;

  @override
  String get mainnet;
  @override
  String get testnet;
  @override
  int get stopGap;
  @override
  int get timeout;
  @override
  int get retry;
  @override
  bool get validateDomain;
  @override
  String get name;
  @override
  @JsonKey(ignore: true)
  _$$_CustomElectrumNetworkCopyWith<_$_CustomElectrumNetwork> get copyWith =>
      throw _privateConstructorUsedError;
}
