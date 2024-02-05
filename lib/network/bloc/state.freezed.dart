// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NetworkState _$NetworkStateFromJson(Map<String, dynamic> json) {
  return _NetworkState.fromJson(json);
}

/// @nodoc
mixin _$NetworkState {
  bool get testnet => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.Blockchain? get blockchain => throw _privateConstructorUsedError;
  int get reloadWalletTimer => throw _privateConstructorUsedError;
  List<ElectrumNetwork> get networks => throw _privateConstructorUsedError;
  ElectrumTypes get selectedNetwork => throw _privateConstructorUsedError;
  bool get loadingNetworks => throw _privateConstructorUsedError;
  String get errLoadingNetworks => throw _privateConstructorUsedError;
  bool get networkConnected => throw _privateConstructorUsedError;
  bool get networkErrorOpened =>
      throw _privateConstructorUsedError; // @Default(20) int stopGap,
  ElectrumTypes? get tempNetwork => throw _privateConstructorUsedError;
  ElectrumNetwork? get tempNetworkDetails => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $NetworkStateCopyWith<NetworkState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NetworkStateCopyWith<$Res> {
  factory $NetworkStateCopyWith(
          NetworkState value, $Res Function(NetworkState) then) =
      _$NetworkStateCopyWithImpl<$Res, NetworkState>;
  @useResult
  $Res call(
      {bool testnet,
      @JsonKey(includeFromJson: false, includeToJson: false)
      bdk.Blockchain? blockchain,
      int reloadWalletTimer,
      List<ElectrumNetwork> networks,
      ElectrumTypes selectedNetwork,
      bool loadingNetworks,
      String errLoadingNetworks,
      bool networkConnected,
      bool networkErrorOpened,
      ElectrumTypes? tempNetwork,
      ElectrumNetwork? tempNetworkDetails});

  $ElectrumNetworkCopyWith<$Res>? get tempNetworkDetails;
}

/// @nodoc
class _$NetworkStateCopyWithImpl<$Res, $Val extends NetworkState>
    implements $NetworkStateCopyWith<$Res> {
  _$NetworkStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? testnet = null,
    Object? blockchain = freezed,
    Object? reloadWalletTimer = null,
    Object? networks = null,
    Object? selectedNetwork = null,
    Object? loadingNetworks = null,
    Object? errLoadingNetworks = null,
    Object? networkConnected = null,
    Object? networkErrorOpened = null,
    Object? tempNetwork = freezed,
    Object? tempNetworkDetails = freezed,
  }) {
    return _then(_value.copyWith(
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as bool,
      blockchain: freezed == blockchain
          ? _value.blockchain
          : blockchain // ignore: cast_nullable_to_non_nullable
              as bdk.Blockchain?,
      reloadWalletTimer: null == reloadWalletTimer
          ? _value.reloadWalletTimer
          : reloadWalletTimer // ignore: cast_nullable_to_non_nullable
              as int,
      networks: null == networks
          ? _value.networks
          : networks // ignore: cast_nullable_to_non_nullable
              as List<ElectrumNetwork>,
      selectedNetwork: null == selectedNetwork
          ? _value.selectedNetwork
          : selectedNetwork // ignore: cast_nullable_to_non_nullable
              as ElectrumTypes,
      loadingNetworks: null == loadingNetworks
          ? _value.loadingNetworks
          : loadingNetworks // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingNetworks: null == errLoadingNetworks
          ? _value.errLoadingNetworks
          : errLoadingNetworks // ignore: cast_nullable_to_non_nullable
              as String,
      networkConnected: null == networkConnected
          ? _value.networkConnected
          : networkConnected // ignore: cast_nullable_to_non_nullable
              as bool,
      networkErrorOpened: null == networkErrorOpened
          ? _value.networkErrorOpened
          : networkErrorOpened // ignore: cast_nullable_to_non_nullable
              as bool,
      tempNetwork: freezed == tempNetwork
          ? _value.tempNetwork
          : tempNetwork // ignore: cast_nullable_to_non_nullable
              as ElectrumTypes?,
      tempNetworkDetails: freezed == tempNetworkDetails
          ? _value.tempNetworkDetails
          : tempNetworkDetails // ignore: cast_nullable_to_non_nullable
              as ElectrumNetwork?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $ElectrumNetworkCopyWith<$Res>? get tempNetworkDetails {
    if (_value.tempNetworkDetails == null) {
      return null;
    }

    return $ElectrumNetworkCopyWith<$Res>(_value.tempNetworkDetails!, (value) {
      return _then(_value.copyWith(tempNetworkDetails: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$NetworkStateImplCopyWith<$Res>
    implements $NetworkStateCopyWith<$Res> {
  factory _$$NetworkStateImplCopyWith(
          _$NetworkStateImpl value, $Res Function(_$NetworkStateImpl) then) =
      __$$NetworkStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool testnet,
      @JsonKey(includeFromJson: false, includeToJson: false)
      bdk.Blockchain? blockchain,
      int reloadWalletTimer,
      List<ElectrumNetwork> networks,
      ElectrumTypes selectedNetwork,
      bool loadingNetworks,
      String errLoadingNetworks,
      bool networkConnected,
      bool networkErrorOpened,
      ElectrumTypes? tempNetwork,
      ElectrumNetwork? tempNetworkDetails});

  @override
  $ElectrumNetworkCopyWith<$Res>? get tempNetworkDetails;
}

/// @nodoc
class __$$NetworkStateImplCopyWithImpl<$Res>
    extends _$NetworkStateCopyWithImpl<$Res, _$NetworkStateImpl>
    implements _$$NetworkStateImplCopyWith<$Res> {
  __$$NetworkStateImplCopyWithImpl(
      _$NetworkStateImpl _value, $Res Function(_$NetworkStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? testnet = null,
    Object? blockchain = freezed,
    Object? reloadWalletTimer = null,
    Object? networks = null,
    Object? selectedNetwork = null,
    Object? loadingNetworks = null,
    Object? errLoadingNetworks = null,
    Object? networkConnected = null,
    Object? networkErrorOpened = null,
    Object? tempNetwork = freezed,
    Object? tempNetworkDetails = freezed,
  }) {
    return _then(_$NetworkStateImpl(
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as bool,
      blockchain: freezed == blockchain
          ? _value.blockchain
          : blockchain // ignore: cast_nullable_to_non_nullable
              as bdk.Blockchain?,
      reloadWalletTimer: null == reloadWalletTimer
          ? _value.reloadWalletTimer
          : reloadWalletTimer // ignore: cast_nullable_to_non_nullable
              as int,
      networks: null == networks
          ? _value._networks
          : networks // ignore: cast_nullable_to_non_nullable
              as List<ElectrumNetwork>,
      selectedNetwork: null == selectedNetwork
          ? _value.selectedNetwork
          : selectedNetwork // ignore: cast_nullable_to_non_nullable
              as ElectrumTypes,
      loadingNetworks: null == loadingNetworks
          ? _value.loadingNetworks
          : loadingNetworks // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingNetworks: null == errLoadingNetworks
          ? _value.errLoadingNetworks
          : errLoadingNetworks // ignore: cast_nullable_to_non_nullable
              as String,
      networkConnected: null == networkConnected
          ? _value.networkConnected
          : networkConnected // ignore: cast_nullable_to_non_nullable
              as bool,
      networkErrorOpened: null == networkErrorOpened
          ? _value.networkErrorOpened
          : networkErrorOpened // ignore: cast_nullable_to_non_nullable
              as bool,
      tempNetwork: freezed == tempNetwork
          ? _value.tempNetwork
          : tempNetwork // ignore: cast_nullable_to_non_nullable
              as ElectrumTypes?,
      tempNetworkDetails: freezed == tempNetworkDetails
          ? _value.tempNetworkDetails
          : tempNetworkDetails // ignore: cast_nullable_to_non_nullable
              as ElectrumNetwork?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NetworkStateImpl extends _NetworkState {
  const _$NetworkStateImpl(
      {this.testnet = false,
      @JsonKey(includeFromJson: false, includeToJson: false) this.blockchain,
      this.reloadWalletTimer = 20,
      final List<ElectrumNetwork> networks = const [],
      this.selectedNetwork = ElectrumTypes.bullbitcoin,
      this.loadingNetworks = false,
      this.errLoadingNetworks = '',
      this.networkConnected = false,
      this.networkErrorOpened = false,
      this.tempNetwork,
      this.tempNetworkDetails})
      : _networks = networks,
        super._();

  factory _$NetworkStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$NetworkStateImplFromJson(json);

  @override
  @JsonKey()
  final bool testnet;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bdk.Blockchain? blockchain;
  @override
  @JsonKey()
  final int reloadWalletTimer;
  final List<ElectrumNetwork> _networks;
  @override
  @JsonKey()
  List<ElectrumNetwork> get networks {
    if (_networks is EqualUnmodifiableListView) return _networks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_networks);
  }

  @override
  @JsonKey()
  final ElectrumTypes selectedNetwork;
  @override
  @JsonKey()
  final bool loadingNetworks;
  @override
  @JsonKey()
  final String errLoadingNetworks;
  @override
  @JsonKey()
  final bool networkConnected;
  @override
  @JsonKey()
  final bool networkErrorOpened;
// @Default(20) int stopGap,
  @override
  final ElectrumTypes? tempNetwork;
  @override
  final ElectrumNetwork? tempNetworkDetails;

  @override
  String toString() {
    return 'NetworkState(testnet: $testnet, blockchain: $blockchain, reloadWalletTimer: $reloadWalletTimer, networks: $networks, selectedNetwork: $selectedNetwork, loadingNetworks: $loadingNetworks, errLoadingNetworks: $errLoadingNetworks, networkConnected: $networkConnected, networkErrorOpened: $networkErrorOpened, tempNetwork: $tempNetwork, tempNetworkDetails: $tempNetworkDetails)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkStateImpl &&
            (identical(other.testnet, testnet) || other.testnet == testnet) &&
            (identical(other.blockchain, blockchain) ||
                other.blockchain == blockchain) &&
            (identical(other.reloadWalletTimer, reloadWalletTimer) ||
                other.reloadWalletTimer == reloadWalletTimer) &&
            const DeepCollectionEquality().equals(other._networks, _networks) &&
            (identical(other.selectedNetwork, selectedNetwork) ||
                other.selectedNetwork == selectedNetwork) &&
            (identical(other.loadingNetworks, loadingNetworks) ||
                other.loadingNetworks == loadingNetworks) &&
            (identical(other.errLoadingNetworks, errLoadingNetworks) ||
                other.errLoadingNetworks == errLoadingNetworks) &&
            (identical(other.networkConnected, networkConnected) ||
                other.networkConnected == networkConnected) &&
            (identical(other.networkErrorOpened, networkErrorOpened) ||
                other.networkErrorOpened == networkErrorOpened) &&
            (identical(other.tempNetwork, tempNetwork) ||
                other.tempNetwork == tempNetwork) &&
            (identical(other.tempNetworkDetails, tempNetworkDetails) ||
                other.tempNetworkDetails == tempNetworkDetails));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      testnet,
      blockchain,
      reloadWalletTimer,
      const DeepCollectionEquality().hash(_networks),
      selectedNetwork,
      loadingNetworks,
      errLoadingNetworks,
      networkConnected,
      networkErrorOpened,
      tempNetwork,
      tempNetworkDetails);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$NetworkStateImplCopyWith<_$NetworkStateImpl> get copyWith =>
      __$$NetworkStateImplCopyWithImpl<_$NetworkStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NetworkStateImplToJson(
      this,
    );
  }
}

abstract class _NetworkState extends NetworkState {
  const factory _NetworkState(
      {final bool testnet,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final bdk.Blockchain? blockchain,
      final int reloadWalletTimer,
      final List<ElectrumNetwork> networks,
      final ElectrumTypes selectedNetwork,
      final bool loadingNetworks,
      final String errLoadingNetworks,
      final bool networkConnected,
      final bool networkErrorOpened,
      final ElectrumTypes? tempNetwork,
      final ElectrumNetwork? tempNetworkDetails}) = _$NetworkStateImpl;
  const _NetworkState._() : super._();

  factory _NetworkState.fromJson(Map<String, dynamic> json) =
      _$NetworkStateImpl.fromJson;

  @override
  bool get testnet;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.Blockchain? get blockchain;
  @override
  int get reloadWalletTimer;
  @override
  List<ElectrumNetwork> get networks;
  @override
  ElectrumTypes get selectedNetwork;
  @override
  bool get loadingNetworks;
  @override
  String get errLoadingNetworks;
  @override
  bool get networkConnected;
  @override
  bool get networkErrorOpened;
  @override // @Default(20) int stopGap,
  ElectrumTypes? get tempNetwork;
  @override
  ElectrumNetwork? get tempNetworkDetails;
  @override
  @JsonKey(ignore: true)
  _$$NetworkStateImplCopyWith<_$NetworkStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
