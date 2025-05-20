// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'network.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

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
  ElectrumTypes get type => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String mainnet,
            String testnet,
            int stopGap,
            int timeout,
            int retry,
            bool validateDomain,
            String name,
            ElectrumTypes type)
        bullbitcoin,
    required TResult Function(
            String mainnet,
            String testnet,
            int stopGap,
            int timeout,
            int retry,
            bool validateDomain,
            String name,
            ElectrumTypes type)
        defaultElectrum,
    required TResult Function(
            String mainnet,
            String testnet,
            int stopGap,
            int timeout,
            int retry,
            bool validateDomain,
            String name,
            ElectrumTypes type)
        custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        bullbitcoin,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        defaultElectrum,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        bullbitcoin,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        defaultElectrum,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
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

  /// Serializes this ElectrumNetwork to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
      String name,
      ElectrumTypes type});
}

/// @nodoc
class _$ElectrumNetworkCopyWithImpl<$Res, $Val extends ElectrumNetwork>
    implements $ElectrumNetworkCopyWith<$Res> {
  _$ElectrumNetworkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
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
    Object? type = null,
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
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ElectrumTypes,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BullbitcoinElectrumNetworkImplCopyWith<$Res>
    implements $ElectrumNetworkCopyWith<$Res> {
  factory _$$BullbitcoinElectrumNetworkImplCopyWith(
          _$BullbitcoinElectrumNetworkImpl value,
          $Res Function(_$BullbitcoinElectrumNetworkImpl) then) =
      __$$BullbitcoinElectrumNetworkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String mainnet,
      String testnet,
      int stopGap,
      int timeout,
      int retry,
      bool validateDomain,
      String name,
      ElectrumTypes type});
}

/// @nodoc
class __$$BullbitcoinElectrumNetworkImplCopyWithImpl<$Res>
    extends _$ElectrumNetworkCopyWithImpl<$Res,
        _$BullbitcoinElectrumNetworkImpl>
    implements _$$BullbitcoinElectrumNetworkImplCopyWith<$Res> {
  __$$BullbitcoinElectrumNetworkImplCopyWithImpl(
      _$BullbitcoinElectrumNetworkImpl _value,
      $Res Function(_$BullbitcoinElectrumNetworkImpl) _then)
      : super(_value, _then);

  /// Create a copy of ElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
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
    Object? type = null,
  }) {
    return _then(_$BullbitcoinElectrumNetworkImpl(
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
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ElectrumTypes,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BullbitcoinElectrumNetworkImpl extends _BullbitcoinElectrumNetwork {
  const _$BullbitcoinElectrumNetworkImpl(
      {this.mainnet = 'ssl://$bbelectrumMain',
      this.testnet = 'ssl://$bbelectrumTest',
      this.stopGap = 20,
      this.timeout = 5,
      this.retry = 5,
      this.validateDomain = true,
      this.name = 'bullbitcoin',
      this.type = ElectrumTypes.bullbitcoin,
      final String? $type})
      : $type = $type ?? 'bullbitcoin',
        super._();

  factory _$BullbitcoinElectrumNetworkImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$BullbitcoinElectrumNetworkImplFromJson(json);

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
  @override
  @JsonKey()
  final ElectrumTypes type;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'ElectrumNetwork.bullbitcoin(mainnet: $mainnet, testnet: $testnet, stopGap: $stopGap, timeout: $timeout, retry: $retry, validateDomain: $validateDomain, name: $name, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BullbitcoinElectrumNetworkImpl &&
            (identical(other.mainnet, mainnet) || other.mainnet == mainnet) &&
            (identical(other.testnet, testnet) || other.testnet == testnet) &&
            (identical(other.stopGap, stopGap) || other.stopGap == stopGap) &&
            (identical(other.timeout, timeout) || other.timeout == timeout) &&
            (identical(other.retry, retry) || other.retry == retry) &&
            (identical(other.validateDomain, validateDomain) ||
                other.validateDomain == validateDomain) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, mainnet, testnet, stopGap,
      timeout, retry, validateDomain, name, type);

  /// Create a copy of ElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BullbitcoinElectrumNetworkImplCopyWith<_$BullbitcoinElectrumNetworkImpl>
      get copyWith => __$$BullbitcoinElectrumNetworkImplCopyWithImpl<
          _$BullbitcoinElectrumNetworkImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String mainnet,
            String testnet,
            int stopGap,
            int timeout,
            int retry,
            bool validateDomain,
            String name,
            ElectrumTypes type)
        bullbitcoin,
    required TResult Function(
            String mainnet,
            String testnet,
            int stopGap,
            int timeout,
            int retry,
            bool validateDomain,
            String name,
            ElectrumTypes type)
        defaultElectrum,
    required TResult Function(
            String mainnet,
            String testnet,
            int stopGap,
            int timeout,
            int retry,
            bool validateDomain,
            String name,
            ElectrumTypes type)
        custom,
  }) {
    return bullbitcoin(
        mainnet, testnet, stopGap, timeout, retry, validateDomain, name, type);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        bullbitcoin,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        defaultElectrum,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        custom,
  }) {
    return bullbitcoin?.call(
        mainnet, testnet, stopGap, timeout, retry, validateDomain, name, type);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        bullbitcoin,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        defaultElectrum,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        custom,
    required TResult orElse(),
  }) {
    if (bullbitcoin != null) {
      return bullbitcoin(mainnet, testnet, stopGap, timeout, retry,
          validateDomain, name, type);
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
    return _$$BullbitcoinElectrumNetworkImplToJson(
      this,
    );
  }
}

abstract class _BullbitcoinElectrumNetwork extends ElectrumNetwork {
  const factory _BullbitcoinElectrumNetwork(
      {final String mainnet,
      final String testnet,
      final int stopGap,
      final int timeout,
      final int retry,
      final bool validateDomain,
      final String name,
      final ElectrumTypes type}) = _$BullbitcoinElectrumNetworkImpl;
  const _BullbitcoinElectrumNetwork._() : super._();

  factory _BullbitcoinElectrumNetwork.fromJson(Map<String, dynamic> json) =
      _$BullbitcoinElectrumNetworkImpl.fromJson;

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
  ElectrumTypes get type;

  /// Create a copy of ElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BullbitcoinElectrumNetworkImplCopyWith<_$BullbitcoinElectrumNetworkImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DefaultElectrumNetworkImplCopyWith<$Res>
    implements $ElectrumNetworkCopyWith<$Res> {
  factory _$$DefaultElectrumNetworkImplCopyWith(
          _$DefaultElectrumNetworkImpl value,
          $Res Function(_$DefaultElectrumNetworkImpl) then) =
      __$$DefaultElectrumNetworkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String mainnet,
      String testnet,
      int stopGap,
      int timeout,
      int retry,
      bool validateDomain,
      String name,
      ElectrumTypes type});
}

/// @nodoc
class __$$DefaultElectrumNetworkImplCopyWithImpl<$Res>
    extends _$ElectrumNetworkCopyWithImpl<$Res, _$DefaultElectrumNetworkImpl>
    implements _$$DefaultElectrumNetworkImplCopyWith<$Res> {
  __$$DefaultElectrumNetworkImplCopyWithImpl(
      _$DefaultElectrumNetworkImpl _value,
      $Res Function(_$DefaultElectrumNetworkImpl) _then)
      : super(_value, _then);

  /// Create a copy of ElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
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
    Object? type = null,
  }) {
    return _then(_$DefaultElectrumNetworkImpl(
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
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ElectrumTypes,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DefaultElectrumNetworkImpl extends _DefaultElectrumNetwork {
  const _$DefaultElectrumNetworkImpl(
      {this.mainnet = 'ssl://$openelectrumMain',
      this.testnet = 'ssl://$openelectrumTest',
      this.stopGap = 20,
      this.timeout = 5,
      this.retry = 5,
      this.validateDomain = true,
      this.name = 'blockstream',
      this.type = ElectrumTypes.blockstream,
      final String? $type})
      : $type = $type ?? 'defaultElectrum',
        super._();

  factory _$DefaultElectrumNetworkImpl.fromJson(Map<String, dynamic> json) =>
      _$$DefaultElectrumNetworkImplFromJson(json);

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
  @override
  @JsonKey()
  final ElectrumTypes type;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'ElectrumNetwork.defaultElectrum(mainnet: $mainnet, testnet: $testnet, stopGap: $stopGap, timeout: $timeout, retry: $retry, validateDomain: $validateDomain, name: $name, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DefaultElectrumNetworkImpl &&
            (identical(other.mainnet, mainnet) || other.mainnet == mainnet) &&
            (identical(other.testnet, testnet) || other.testnet == testnet) &&
            (identical(other.stopGap, stopGap) || other.stopGap == stopGap) &&
            (identical(other.timeout, timeout) || other.timeout == timeout) &&
            (identical(other.retry, retry) || other.retry == retry) &&
            (identical(other.validateDomain, validateDomain) ||
                other.validateDomain == validateDomain) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, mainnet, testnet, stopGap,
      timeout, retry, validateDomain, name, type);

  /// Create a copy of ElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DefaultElectrumNetworkImplCopyWith<_$DefaultElectrumNetworkImpl>
      get copyWith => __$$DefaultElectrumNetworkImplCopyWithImpl<
          _$DefaultElectrumNetworkImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String mainnet,
            String testnet,
            int stopGap,
            int timeout,
            int retry,
            bool validateDomain,
            String name,
            ElectrumTypes type)
        bullbitcoin,
    required TResult Function(
            String mainnet,
            String testnet,
            int stopGap,
            int timeout,
            int retry,
            bool validateDomain,
            String name,
            ElectrumTypes type)
        defaultElectrum,
    required TResult Function(
            String mainnet,
            String testnet,
            int stopGap,
            int timeout,
            int retry,
            bool validateDomain,
            String name,
            ElectrumTypes type)
        custom,
  }) {
    return defaultElectrum(
        mainnet, testnet, stopGap, timeout, retry, validateDomain, name, type);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        bullbitcoin,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        defaultElectrum,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        custom,
  }) {
    return defaultElectrum?.call(
        mainnet, testnet, stopGap, timeout, retry, validateDomain, name, type);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        bullbitcoin,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        defaultElectrum,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        custom,
    required TResult orElse(),
  }) {
    if (defaultElectrum != null) {
      return defaultElectrum(mainnet, testnet, stopGap, timeout, retry,
          validateDomain, name, type);
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
    return _$$DefaultElectrumNetworkImplToJson(
      this,
    );
  }
}

abstract class _DefaultElectrumNetwork extends ElectrumNetwork {
  const factory _DefaultElectrumNetwork(
      {final String mainnet,
      final String testnet,
      final int stopGap,
      final int timeout,
      final int retry,
      final bool validateDomain,
      final String name,
      final ElectrumTypes type}) = _$DefaultElectrumNetworkImpl;
  const _DefaultElectrumNetwork._() : super._();

  factory _DefaultElectrumNetwork.fromJson(Map<String, dynamic> json) =
      _$DefaultElectrumNetworkImpl.fromJson;

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
  ElectrumTypes get type;

  /// Create a copy of ElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DefaultElectrumNetworkImplCopyWith<_$DefaultElectrumNetworkImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$CustomElectrumNetworkImplCopyWith<$Res>
    implements $ElectrumNetworkCopyWith<$Res> {
  factory _$$CustomElectrumNetworkImplCopyWith(
          _$CustomElectrumNetworkImpl value,
          $Res Function(_$CustomElectrumNetworkImpl) then) =
      __$$CustomElectrumNetworkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String mainnet,
      String testnet,
      int stopGap,
      int timeout,
      int retry,
      bool validateDomain,
      String name,
      ElectrumTypes type});
}

/// @nodoc
class __$$CustomElectrumNetworkImplCopyWithImpl<$Res>
    extends _$ElectrumNetworkCopyWithImpl<$Res, _$CustomElectrumNetworkImpl>
    implements _$$CustomElectrumNetworkImplCopyWith<$Res> {
  __$$CustomElectrumNetworkImplCopyWithImpl(_$CustomElectrumNetworkImpl _value,
      $Res Function(_$CustomElectrumNetworkImpl) _then)
      : super(_value, _then);

  /// Create a copy of ElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
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
    Object? type = null,
  }) {
    return _then(_$CustomElectrumNetworkImpl(
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
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ElectrumTypes,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CustomElectrumNetworkImpl extends _CustomElectrumNetwork {
  const _$CustomElectrumNetworkImpl(
      {required this.mainnet,
      required this.testnet,
      this.stopGap = 20,
      this.timeout = 5,
      this.retry = 5,
      this.validateDomain = true,
      this.name = 'custom',
      this.type = ElectrumTypes.custom,
      final String? $type})
      : $type = $type ?? 'custom',
        super._();

  factory _$CustomElectrumNetworkImpl.fromJson(Map<String, dynamic> json) =>
      _$$CustomElectrumNetworkImplFromJson(json);

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
  @override
  @JsonKey()
  final ElectrumTypes type;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'ElectrumNetwork.custom(mainnet: $mainnet, testnet: $testnet, stopGap: $stopGap, timeout: $timeout, retry: $retry, validateDomain: $validateDomain, name: $name, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CustomElectrumNetworkImpl &&
            (identical(other.mainnet, mainnet) || other.mainnet == mainnet) &&
            (identical(other.testnet, testnet) || other.testnet == testnet) &&
            (identical(other.stopGap, stopGap) || other.stopGap == stopGap) &&
            (identical(other.timeout, timeout) || other.timeout == timeout) &&
            (identical(other.retry, retry) || other.retry == retry) &&
            (identical(other.validateDomain, validateDomain) ||
                other.validateDomain == validateDomain) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, mainnet, testnet, stopGap,
      timeout, retry, validateDomain, name, type);

  /// Create a copy of ElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CustomElectrumNetworkImplCopyWith<_$CustomElectrumNetworkImpl>
      get copyWith => __$$CustomElectrumNetworkImplCopyWithImpl<
          _$CustomElectrumNetworkImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String mainnet,
            String testnet,
            int stopGap,
            int timeout,
            int retry,
            bool validateDomain,
            String name,
            ElectrumTypes type)
        bullbitcoin,
    required TResult Function(
            String mainnet,
            String testnet,
            int stopGap,
            int timeout,
            int retry,
            bool validateDomain,
            String name,
            ElectrumTypes type)
        defaultElectrum,
    required TResult Function(
            String mainnet,
            String testnet,
            int stopGap,
            int timeout,
            int retry,
            bool validateDomain,
            String name,
            ElectrumTypes type)
        custom,
  }) {
    return custom(
        mainnet, testnet, stopGap, timeout, retry, validateDomain, name, type);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        bullbitcoin,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        defaultElectrum,
    TResult? Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        custom,
  }) {
    return custom?.call(
        mainnet, testnet, stopGap, timeout, retry, validateDomain, name, type);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        bullbitcoin,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        defaultElectrum,
    TResult Function(String mainnet, String testnet, int stopGap, int timeout,
            int retry, bool validateDomain, String name, ElectrumTypes type)?
        custom,
    required TResult orElse(),
  }) {
    if (custom != null) {
      return custom(mainnet, testnet, stopGap, timeout, retry, validateDomain,
          name, type);
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
    return _$$CustomElectrumNetworkImplToJson(
      this,
    );
  }
}

abstract class _CustomElectrumNetwork extends ElectrumNetwork {
  const factory _CustomElectrumNetwork(
      {required final String mainnet,
      required final String testnet,
      final int stopGap,
      final int timeout,
      final int retry,
      final bool validateDomain,
      final String name,
      final ElectrumTypes type}) = _$CustomElectrumNetworkImpl;
  const _CustomElectrumNetwork._() : super._();

  factory _CustomElectrumNetwork.fromJson(Map<String, dynamic> json) =
      _$CustomElectrumNetworkImpl.fromJson;

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
  ElectrumTypes get type;

  /// Create a copy of ElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CustomElectrumNetworkImplCopyWith<_$CustomElectrumNetworkImpl>
      get copyWith => throw _privateConstructorUsedError;
}

LiquidElectrumNetwork _$LiquidElectrumNetworkFromJson(
    Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'blockstream':
      return _BlockstreamLiquidElectrumNetwork.fromJson(json);
    case 'bullbitcoin':
      return _BullBitcoinLiquidElectrumNetwork.fromJson(json);
    case 'custom':
      return _CustomLiquidElectrumNetwork.fromJson(json);

    default:
      throw CheckedFromJsonException(
          json,
          'runtimeType',
          'LiquidElectrumNetwork',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$LiquidElectrumNetwork {
  String get mainnet => throw _privateConstructorUsedError;
  String get testnet => throw _privateConstructorUsedError;
  bool get validateDomain => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  LiquidElectrumTypes get type => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String mainnet, String testnet,
            bool validateDomain, String name, LiquidElectrumTypes type)
        blockstream,
    required TResult Function(String mainnet, String testnet,
            bool validateDomain, String name, LiquidElectrumTypes type)
        bullbitcoin,
    required TResult Function(String mainnet, String testnet,
            bool validateDomain, String name, LiquidElectrumTypes type)
        custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        blockstream,
    TResult? Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        bullbitcoin,
    TResult? Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        blockstream,
    TResult Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        bullbitcoin,
    TResult Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        custom,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_BlockstreamLiquidElectrumNetwork value)
        blockstream,
    required TResult Function(_BullBitcoinLiquidElectrumNetwork value)
        bullbitcoin,
    required TResult Function(_CustomLiquidElectrumNetwork value) custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_BlockstreamLiquidElectrumNetwork value)? blockstream,
    TResult? Function(_BullBitcoinLiquidElectrumNetwork value)? bullbitcoin,
    TResult? Function(_CustomLiquidElectrumNetwork value)? custom,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_BlockstreamLiquidElectrumNetwork value)? blockstream,
    TResult Function(_BullBitcoinLiquidElectrumNetwork value)? bullbitcoin,
    TResult Function(_CustomLiquidElectrumNetwork value)? custom,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this LiquidElectrumNetwork to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiquidElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiquidElectrumNetworkCopyWith<LiquidElectrumNetwork> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiquidElectrumNetworkCopyWith<$Res> {
  factory $LiquidElectrumNetworkCopyWith(LiquidElectrumNetwork value,
          $Res Function(LiquidElectrumNetwork) then) =
      _$LiquidElectrumNetworkCopyWithImpl<$Res, LiquidElectrumNetwork>;
  @useResult
  $Res call(
      {String mainnet,
      String testnet,
      bool validateDomain,
      String name,
      LiquidElectrumTypes type});
}

/// @nodoc
class _$LiquidElectrumNetworkCopyWithImpl<$Res,
        $Val extends LiquidElectrumNetwork>
    implements $LiquidElectrumNetworkCopyWith<$Res> {
  _$LiquidElectrumNetworkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiquidElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mainnet = null,
    Object? testnet = null,
    Object? validateDomain = null,
    Object? name = null,
    Object? type = null,
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
      validateDomain: null == validateDomain
          ? _value.validateDomain
          : validateDomain // ignore: cast_nullable_to_non_nullable
              as bool,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as LiquidElectrumTypes,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BlockstreamLiquidElectrumNetworkImplCopyWith<$Res>
    implements $LiquidElectrumNetworkCopyWith<$Res> {
  factory _$$BlockstreamLiquidElectrumNetworkImplCopyWith(
          _$BlockstreamLiquidElectrumNetworkImpl value,
          $Res Function(_$BlockstreamLiquidElectrumNetworkImpl) then) =
      __$$BlockstreamLiquidElectrumNetworkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String mainnet,
      String testnet,
      bool validateDomain,
      String name,
      LiquidElectrumTypes type});
}

/// @nodoc
class __$$BlockstreamLiquidElectrumNetworkImplCopyWithImpl<$Res>
    extends _$LiquidElectrumNetworkCopyWithImpl<$Res,
        _$BlockstreamLiquidElectrumNetworkImpl>
    implements _$$BlockstreamLiquidElectrumNetworkImplCopyWith<$Res> {
  __$$BlockstreamLiquidElectrumNetworkImplCopyWithImpl(
      _$BlockstreamLiquidElectrumNetworkImpl _value,
      $Res Function(_$BlockstreamLiquidElectrumNetworkImpl) _then)
      : super(_value, _then);

  /// Create a copy of LiquidElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mainnet = null,
    Object? testnet = null,
    Object? validateDomain = null,
    Object? name = null,
    Object? type = null,
  }) {
    return _then(_$BlockstreamLiquidElectrumNetworkImpl(
      mainnet: null == mainnet
          ? _value.mainnet
          : mainnet // ignore: cast_nullable_to_non_nullable
              as String,
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as String,
      validateDomain: null == validateDomain
          ? _value.validateDomain
          : validateDomain // ignore: cast_nullable_to_non_nullable
              as bool,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as LiquidElectrumTypes,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BlockstreamLiquidElectrumNetworkImpl
    extends _BlockstreamLiquidElectrumNetwork {
  const _$BlockstreamLiquidElectrumNetworkImpl(
      {this.mainnet = liquidElectrumUrl,
      this.testnet = liquidElectrumTestUrl,
      this.validateDomain = true,
      this.name = 'blockstream',
      this.type = LiquidElectrumTypes.blockstream,
      final String? $type})
      : $type = $type ?? 'blockstream',
        super._();

  factory _$BlockstreamLiquidElectrumNetworkImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$BlockstreamLiquidElectrumNetworkImplFromJson(json);

  @override
  @JsonKey()
  final String mainnet;
  @override
  @JsonKey()
  final String testnet;
  @override
  @JsonKey()
  final bool validateDomain;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final LiquidElectrumTypes type;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'LiquidElectrumNetwork.blockstream(mainnet: $mainnet, testnet: $testnet, validateDomain: $validateDomain, name: $name, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BlockstreamLiquidElectrumNetworkImpl &&
            (identical(other.mainnet, mainnet) || other.mainnet == mainnet) &&
            (identical(other.testnet, testnet) || other.testnet == testnet) &&
            (identical(other.validateDomain, validateDomain) ||
                other.validateDomain == validateDomain) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, mainnet, testnet, validateDomain, name, type);

  /// Create a copy of LiquidElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BlockstreamLiquidElectrumNetworkImplCopyWith<
          _$BlockstreamLiquidElectrumNetworkImpl>
      get copyWith => __$$BlockstreamLiquidElectrumNetworkImplCopyWithImpl<
          _$BlockstreamLiquidElectrumNetworkImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String mainnet, String testnet,
            bool validateDomain, String name, LiquidElectrumTypes type)
        blockstream,
    required TResult Function(String mainnet, String testnet,
            bool validateDomain, String name, LiquidElectrumTypes type)
        bullbitcoin,
    required TResult Function(String mainnet, String testnet,
            bool validateDomain, String name, LiquidElectrumTypes type)
        custom,
  }) {
    return blockstream(mainnet, testnet, validateDomain, name, type);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        blockstream,
    TResult? Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        bullbitcoin,
    TResult? Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        custom,
  }) {
    return blockstream?.call(mainnet, testnet, validateDomain, name, type);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        blockstream,
    TResult Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        bullbitcoin,
    TResult Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        custom,
    required TResult orElse(),
  }) {
    if (blockstream != null) {
      return blockstream(mainnet, testnet, validateDomain, name, type);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_BlockstreamLiquidElectrumNetwork value)
        blockstream,
    required TResult Function(_BullBitcoinLiquidElectrumNetwork value)
        bullbitcoin,
    required TResult Function(_CustomLiquidElectrumNetwork value) custom,
  }) {
    return blockstream(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_BlockstreamLiquidElectrumNetwork value)? blockstream,
    TResult? Function(_BullBitcoinLiquidElectrumNetwork value)? bullbitcoin,
    TResult? Function(_CustomLiquidElectrumNetwork value)? custom,
  }) {
    return blockstream?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_BlockstreamLiquidElectrumNetwork value)? blockstream,
    TResult Function(_BullBitcoinLiquidElectrumNetwork value)? bullbitcoin,
    TResult Function(_CustomLiquidElectrumNetwork value)? custom,
    required TResult orElse(),
  }) {
    if (blockstream != null) {
      return blockstream(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$BlockstreamLiquidElectrumNetworkImplToJson(
      this,
    );
  }
}

abstract class _BlockstreamLiquidElectrumNetwork extends LiquidElectrumNetwork {
  const factory _BlockstreamLiquidElectrumNetwork(
      {final String mainnet,
      final String testnet,
      final bool validateDomain,
      final String name,
      final LiquidElectrumTypes type}) = _$BlockstreamLiquidElectrumNetworkImpl;
  const _BlockstreamLiquidElectrumNetwork._() : super._();

  factory _BlockstreamLiquidElectrumNetwork.fromJson(
          Map<String, dynamic> json) =
      _$BlockstreamLiquidElectrumNetworkImpl.fromJson;

  @override
  String get mainnet;
  @override
  String get testnet;
  @override
  bool get validateDomain;
  @override
  String get name;
  @override
  LiquidElectrumTypes get type;

  /// Create a copy of LiquidElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BlockstreamLiquidElectrumNetworkImplCopyWith<
          _$BlockstreamLiquidElectrumNetworkImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$BullBitcoinLiquidElectrumNetworkImplCopyWith<$Res>
    implements $LiquidElectrumNetworkCopyWith<$Res> {
  factory _$$BullBitcoinLiquidElectrumNetworkImplCopyWith(
          _$BullBitcoinLiquidElectrumNetworkImpl value,
          $Res Function(_$BullBitcoinLiquidElectrumNetworkImpl) then) =
      __$$BullBitcoinLiquidElectrumNetworkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String mainnet,
      String testnet,
      bool validateDomain,
      String name,
      LiquidElectrumTypes type});
}

/// @nodoc
class __$$BullBitcoinLiquidElectrumNetworkImplCopyWithImpl<$Res>
    extends _$LiquidElectrumNetworkCopyWithImpl<$Res,
        _$BullBitcoinLiquidElectrumNetworkImpl>
    implements _$$BullBitcoinLiquidElectrumNetworkImplCopyWith<$Res> {
  __$$BullBitcoinLiquidElectrumNetworkImplCopyWithImpl(
      _$BullBitcoinLiquidElectrumNetworkImpl _value,
      $Res Function(_$BullBitcoinLiquidElectrumNetworkImpl) _then)
      : super(_value, _then);

  /// Create a copy of LiquidElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mainnet = null,
    Object? testnet = null,
    Object? validateDomain = null,
    Object? name = null,
    Object? type = null,
  }) {
    return _then(_$BullBitcoinLiquidElectrumNetworkImpl(
      mainnet: null == mainnet
          ? _value.mainnet
          : mainnet // ignore: cast_nullable_to_non_nullable
              as String,
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as String,
      validateDomain: null == validateDomain
          ? _value.validateDomain
          : validateDomain // ignore: cast_nullable_to_non_nullable
              as bool,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as LiquidElectrumTypes,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BullBitcoinLiquidElectrumNetworkImpl
    extends _BullBitcoinLiquidElectrumNetwork {
  const _$BullBitcoinLiquidElectrumNetworkImpl(
      {this.mainnet = bbLiquidElectrumUrl,
      this.testnet = bbLiquidElectrumTestUrl,
      this.validateDomain = true,
      this.name = 'bullbitcoin',
      this.type = LiquidElectrumTypes.bullbitcoin,
      final String? $type})
      : $type = $type ?? 'bullbitcoin',
        super._();

  factory _$BullBitcoinLiquidElectrumNetworkImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$BullBitcoinLiquidElectrumNetworkImplFromJson(json);

  @override
  @JsonKey()
  final String mainnet;
  @override
  @JsonKey()
  final String testnet;
  @override
  @JsonKey()
  final bool validateDomain;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final LiquidElectrumTypes type;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'LiquidElectrumNetwork.bullbitcoin(mainnet: $mainnet, testnet: $testnet, validateDomain: $validateDomain, name: $name, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BullBitcoinLiquidElectrumNetworkImpl &&
            (identical(other.mainnet, mainnet) || other.mainnet == mainnet) &&
            (identical(other.testnet, testnet) || other.testnet == testnet) &&
            (identical(other.validateDomain, validateDomain) ||
                other.validateDomain == validateDomain) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, mainnet, testnet, validateDomain, name, type);

  /// Create a copy of LiquidElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BullBitcoinLiquidElectrumNetworkImplCopyWith<
          _$BullBitcoinLiquidElectrumNetworkImpl>
      get copyWith => __$$BullBitcoinLiquidElectrumNetworkImplCopyWithImpl<
          _$BullBitcoinLiquidElectrumNetworkImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String mainnet, String testnet,
            bool validateDomain, String name, LiquidElectrumTypes type)
        blockstream,
    required TResult Function(String mainnet, String testnet,
            bool validateDomain, String name, LiquidElectrumTypes type)
        bullbitcoin,
    required TResult Function(String mainnet, String testnet,
            bool validateDomain, String name, LiquidElectrumTypes type)
        custom,
  }) {
    return bullbitcoin(mainnet, testnet, validateDomain, name, type);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        blockstream,
    TResult? Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        bullbitcoin,
    TResult? Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        custom,
  }) {
    return bullbitcoin?.call(mainnet, testnet, validateDomain, name, type);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        blockstream,
    TResult Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        bullbitcoin,
    TResult Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        custom,
    required TResult orElse(),
  }) {
    if (bullbitcoin != null) {
      return bullbitcoin(mainnet, testnet, validateDomain, name, type);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_BlockstreamLiquidElectrumNetwork value)
        blockstream,
    required TResult Function(_BullBitcoinLiquidElectrumNetwork value)
        bullbitcoin,
    required TResult Function(_CustomLiquidElectrumNetwork value) custom,
  }) {
    return bullbitcoin(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_BlockstreamLiquidElectrumNetwork value)? blockstream,
    TResult? Function(_BullBitcoinLiquidElectrumNetwork value)? bullbitcoin,
    TResult? Function(_CustomLiquidElectrumNetwork value)? custom,
  }) {
    return bullbitcoin?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_BlockstreamLiquidElectrumNetwork value)? blockstream,
    TResult Function(_BullBitcoinLiquidElectrumNetwork value)? bullbitcoin,
    TResult Function(_CustomLiquidElectrumNetwork value)? custom,
    required TResult orElse(),
  }) {
    if (bullbitcoin != null) {
      return bullbitcoin(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$BullBitcoinLiquidElectrumNetworkImplToJson(
      this,
    );
  }
}

abstract class _BullBitcoinLiquidElectrumNetwork extends LiquidElectrumNetwork {
  const factory _BullBitcoinLiquidElectrumNetwork(
      {final String mainnet,
      final String testnet,
      final bool validateDomain,
      final String name,
      final LiquidElectrumTypes type}) = _$BullBitcoinLiquidElectrumNetworkImpl;
  const _BullBitcoinLiquidElectrumNetwork._() : super._();

  factory _BullBitcoinLiquidElectrumNetwork.fromJson(
          Map<String, dynamic> json) =
      _$BullBitcoinLiquidElectrumNetworkImpl.fromJson;

  @override
  String get mainnet;
  @override
  String get testnet;
  @override
  bool get validateDomain;
  @override
  String get name;
  @override
  LiquidElectrumTypes get type;

  /// Create a copy of LiquidElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BullBitcoinLiquidElectrumNetworkImplCopyWith<
          _$BullBitcoinLiquidElectrumNetworkImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$CustomLiquidElectrumNetworkImplCopyWith<$Res>
    implements $LiquidElectrumNetworkCopyWith<$Res> {
  factory _$$CustomLiquidElectrumNetworkImplCopyWith(
          _$CustomLiquidElectrumNetworkImpl value,
          $Res Function(_$CustomLiquidElectrumNetworkImpl) then) =
      __$$CustomLiquidElectrumNetworkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String mainnet,
      String testnet,
      bool validateDomain,
      String name,
      LiquidElectrumTypes type});
}

/// @nodoc
class __$$CustomLiquidElectrumNetworkImplCopyWithImpl<$Res>
    extends _$LiquidElectrumNetworkCopyWithImpl<$Res,
        _$CustomLiquidElectrumNetworkImpl>
    implements _$$CustomLiquidElectrumNetworkImplCopyWith<$Res> {
  __$$CustomLiquidElectrumNetworkImplCopyWithImpl(
      _$CustomLiquidElectrumNetworkImpl _value,
      $Res Function(_$CustomLiquidElectrumNetworkImpl) _then)
      : super(_value, _then);

  /// Create a copy of LiquidElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mainnet = null,
    Object? testnet = null,
    Object? validateDomain = null,
    Object? name = null,
    Object? type = null,
  }) {
    return _then(_$CustomLiquidElectrumNetworkImpl(
      mainnet: null == mainnet
          ? _value.mainnet
          : mainnet // ignore: cast_nullable_to_non_nullable
              as String,
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as String,
      validateDomain: null == validateDomain
          ? _value.validateDomain
          : validateDomain // ignore: cast_nullable_to_non_nullable
              as bool,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as LiquidElectrumTypes,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CustomLiquidElectrumNetworkImpl extends _CustomLiquidElectrumNetwork {
  const _$CustomLiquidElectrumNetworkImpl(
      {required this.mainnet,
      required this.testnet,
      this.validateDomain = true,
      this.name = 'custom',
      this.type = LiquidElectrumTypes.custom,
      final String? $type})
      : $type = $type ?? 'custom',
        super._();

  factory _$CustomLiquidElectrumNetworkImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$CustomLiquidElectrumNetworkImplFromJson(json);

  @override
  final String mainnet;
  @override
  final String testnet;
  @override
  @JsonKey()
  final bool validateDomain;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final LiquidElectrumTypes type;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'LiquidElectrumNetwork.custom(mainnet: $mainnet, testnet: $testnet, validateDomain: $validateDomain, name: $name, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CustomLiquidElectrumNetworkImpl &&
            (identical(other.mainnet, mainnet) || other.mainnet == mainnet) &&
            (identical(other.testnet, testnet) || other.testnet == testnet) &&
            (identical(other.validateDomain, validateDomain) ||
                other.validateDomain == validateDomain) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, mainnet, testnet, validateDomain, name, type);

  /// Create a copy of LiquidElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CustomLiquidElectrumNetworkImplCopyWith<_$CustomLiquidElectrumNetworkImpl>
      get copyWith => __$$CustomLiquidElectrumNetworkImplCopyWithImpl<
          _$CustomLiquidElectrumNetworkImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String mainnet, String testnet,
            bool validateDomain, String name, LiquidElectrumTypes type)
        blockstream,
    required TResult Function(String mainnet, String testnet,
            bool validateDomain, String name, LiquidElectrumTypes type)
        bullbitcoin,
    required TResult Function(String mainnet, String testnet,
            bool validateDomain, String name, LiquidElectrumTypes type)
        custom,
  }) {
    return custom(mainnet, testnet, validateDomain, name, type);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        blockstream,
    TResult? Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        bullbitcoin,
    TResult? Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        custom,
  }) {
    return custom?.call(mainnet, testnet, validateDomain, name, type);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        blockstream,
    TResult Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        bullbitcoin,
    TResult Function(String mainnet, String testnet, bool validateDomain,
            String name, LiquidElectrumTypes type)?
        custom,
    required TResult orElse(),
  }) {
    if (custom != null) {
      return custom(mainnet, testnet, validateDomain, name, type);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_BlockstreamLiquidElectrumNetwork value)
        blockstream,
    required TResult Function(_BullBitcoinLiquidElectrumNetwork value)
        bullbitcoin,
    required TResult Function(_CustomLiquidElectrumNetwork value) custom,
  }) {
    return custom(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_BlockstreamLiquidElectrumNetwork value)? blockstream,
    TResult? Function(_BullBitcoinLiquidElectrumNetwork value)? bullbitcoin,
    TResult? Function(_CustomLiquidElectrumNetwork value)? custom,
  }) {
    return custom?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_BlockstreamLiquidElectrumNetwork value)? blockstream,
    TResult Function(_BullBitcoinLiquidElectrumNetwork value)? bullbitcoin,
    TResult Function(_CustomLiquidElectrumNetwork value)? custom,
    required TResult orElse(),
  }) {
    if (custom != null) {
      return custom(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$CustomLiquidElectrumNetworkImplToJson(
      this,
    );
  }
}

abstract class _CustomLiquidElectrumNetwork extends LiquidElectrumNetwork {
  const factory _CustomLiquidElectrumNetwork(
      {required final String mainnet,
      required final String testnet,
      final bool validateDomain,
      final String name,
      final LiquidElectrumTypes type}) = _$CustomLiquidElectrumNetworkImpl;
  const _CustomLiquidElectrumNetwork._() : super._();

  factory _CustomLiquidElectrumNetwork.fromJson(Map<String, dynamic> json) =
      _$CustomLiquidElectrumNetworkImpl.fromJson;

  @override
  String get mainnet;
  @override
  String get testnet;
  @override
  bool get validateDomain;
  @override
  String get name;
  @override
  LiquidElectrumTypes get type;

  /// Create a copy of LiquidElectrumNetwork
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CustomLiquidElectrumNetworkImplCopyWith<_$CustomLiquidElectrumNetworkImpl>
      get copyWith => throw _privateConstructorUsedError;
}
