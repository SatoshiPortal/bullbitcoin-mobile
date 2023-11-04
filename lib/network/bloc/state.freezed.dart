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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

NetworkState _$NetworkStateFromJson(Map<String, dynamic> json) {
  return _NetworkState.fromJson(json);
}

/// @nodoc
mixin _$NetworkState {
  bool get testnet => throw _privateConstructorUsedError; //
  bool get loadingFees => throw _privateConstructorUsedError;
  String get errLoadingFees => throw _privateConstructorUsedError;

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
  $Res call({bool testnet, bool loadingFees, String errLoadingFees});
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
    Object? loadingFees = null,
    Object? errLoadingFees = null,
  }) {
    return _then(_value.copyWith(
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as bool,
      loadingFees: null == loadingFees
          ? _value.loadingFees
          : loadingFees // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingFees: null == errLoadingFees
          ? _value.errLoadingFees
          : errLoadingFees // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_NetworkStateCopyWith<$Res>
    implements $NetworkStateCopyWith<$Res> {
  factory _$$_NetworkStateCopyWith(
          _$_NetworkState value, $Res Function(_$_NetworkState) then) =
      __$$_NetworkStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool testnet, bool loadingFees, String errLoadingFees});
}

/// @nodoc
class __$$_NetworkStateCopyWithImpl<$Res>
    extends _$NetworkStateCopyWithImpl<$Res, _$_NetworkState>
    implements _$$_NetworkStateCopyWith<$Res> {
  __$$_NetworkStateCopyWithImpl(
      _$_NetworkState _value, $Res Function(_$_NetworkState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? testnet = null,
    Object? loadingFees = null,
    Object? errLoadingFees = null,
  }) {
    return _then(_$_NetworkState(
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as bool,
      loadingFees: null == loadingFees
          ? _value.loadingFees
          : loadingFees // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingFees: null == errLoadingFees
          ? _value.errLoadingFees
          : errLoadingFees // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_NetworkState extends _NetworkState {
  const _$_NetworkState(
      {this.testnet = false,
      this.loadingFees = false,
      this.errLoadingFees = ''})
      : super._();

  factory _$_NetworkState.fromJson(Map<String, dynamic> json) =>
      _$$_NetworkStateFromJson(json);

  @override
  @JsonKey()
  final bool testnet;
//
  @override
  @JsonKey()
  final bool loadingFees;
  @override
  @JsonKey()
  final String errLoadingFees;

  @override
  String toString() {
    return 'NetworkState(testnet: $testnet, loadingFees: $loadingFees, errLoadingFees: $errLoadingFees)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_NetworkState &&
            (identical(other.testnet, testnet) || other.testnet == testnet) &&
            (identical(other.loadingFees, loadingFees) ||
                other.loadingFees == loadingFees) &&
            (identical(other.errLoadingFees, errLoadingFees) ||
                other.errLoadingFees == errLoadingFees));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, testnet, loadingFees, errLoadingFees);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_NetworkStateCopyWith<_$_NetworkState> get copyWith =>
      __$$_NetworkStateCopyWithImpl<_$_NetworkState>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_NetworkStateToJson(
      this,
    );
  }
}

abstract class _NetworkState extends NetworkState {
  const factory _NetworkState(
      {final bool testnet,
      final bool loadingFees,
      final String errLoadingFees}) = _$_NetworkState;
  const _NetworkState._() : super._();

  factory _NetworkState.fromJson(Map<String, dynamic> json) =
      _$_NetworkState.fromJson;

  @override
  bool get testnet;
  @override //
  bool get loadingFees;
  @override
  String get errLoadingFees;
  @override
  @JsonKey(ignore: true)
  _$$_NetworkStateCopyWith<_$_NetworkState> get copyWith =>
      throw _privateConstructorUsedError;
}
