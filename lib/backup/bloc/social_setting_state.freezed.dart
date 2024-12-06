// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'social_setting_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SocialSettingState {
  String get secretKey => throw _privateConstructorUsedError;
  String get publicKey => throw _privateConstructorUsedError;
  String get receiverPublicKey => throw _privateConstructorUsedError;
  String get backupKey => throw _privateConstructorUsedError;
  String get relay => throw _privateConstructorUsedError;
  String get error => throw _privateConstructorUsedError;

  /// Create a copy of SocialSettingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SocialSettingStateCopyWith<SocialSettingState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SocialSettingStateCopyWith<$Res> {
  factory $SocialSettingStateCopyWith(
          SocialSettingState value, $Res Function(SocialSettingState) then) =
      _$SocialSettingStateCopyWithImpl<$Res, SocialSettingState>;
  @useResult
  $Res call(
      {String secretKey,
      String publicKey,
      String receiverPublicKey,
      String backupKey,
      String relay,
      String error});
}

/// @nodoc
class _$SocialSettingStateCopyWithImpl<$Res, $Val extends SocialSettingState>
    implements $SocialSettingStateCopyWith<$Res> {
  _$SocialSettingStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SocialSettingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? secretKey = null,
    Object? publicKey = null,
    Object? receiverPublicKey = null,
    Object? backupKey = null,
    Object? relay = null,
    Object? error = null,
  }) {
    return _then(_value.copyWith(
      secretKey: null == secretKey
          ? _value.secretKey
          : secretKey // ignore: cast_nullable_to_non_nullable
              as String,
      publicKey: null == publicKey
          ? _value.publicKey
          : publicKey // ignore: cast_nullable_to_non_nullable
              as String,
      receiverPublicKey: null == receiverPublicKey
          ? _value.receiverPublicKey
          : receiverPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      backupKey: null == backupKey
          ? _value.backupKey
          : backupKey // ignore: cast_nullable_to_non_nullable
              as String,
      relay: null == relay
          ? _value.relay
          : relay // ignore: cast_nullable_to_non_nullable
              as String,
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SocialSettingStateImplCopyWith<$Res>
    implements $SocialSettingStateCopyWith<$Res> {
  factory _$$SocialSettingStateImplCopyWith(_$SocialSettingStateImpl value,
          $Res Function(_$SocialSettingStateImpl) then) =
      __$$SocialSettingStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String secretKey,
      String publicKey,
      String receiverPublicKey,
      String backupKey,
      String relay,
      String error});
}

/// @nodoc
class __$$SocialSettingStateImplCopyWithImpl<$Res>
    extends _$SocialSettingStateCopyWithImpl<$Res, _$SocialSettingStateImpl>
    implements _$$SocialSettingStateImplCopyWith<$Res> {
  __$$SocialSettingStateImplCopyWithImpl(_$SocialSettingStateImpl _value,
      $Res Function(_$SocialSettingStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SocialSettingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? secretKey = null,
    Object? publicKey = null,
    Object? receiverPublicKey = null,
    Object? backupKey = null,
    Object? relay = null,
    Object? error = null,
  }) {
    return _then(_$SocialSettingStateImpl(
      secretKey: null == secretKey
          ? _value.secretKey
          : secretKey // ignore: cast_nullable_to_non_nullable
              as String,
      publicKey: null == publicKey
          ? _value.publicKey
          : publicKey // ignore: cast_nullable_to_non_nullable
              as String,
      receiverPublicKey: null == receiverPublicKey
          ? _value.receiverPublicKey
          : receiverPublicKey // ignore: cast_nullable_to_non_nullable
              as String,
      backupKey: null == backupKey
          ? _value.backupKey
          : backupKey // ignore: cast_nullable_to_non_nullable
              as String,
      relay: null == relay
          ? _value.relay
          : relay // ignore: cast_nullable_to_non_nullable
              as String,
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$SocialSettingStateImpl implements _SocialSettingState {
  const _$SocialSettingStateImpl(
      {this.secretKey = '',
      this.publicKey = '',
      this.receiverPublicKey = '',
      this.backupKey = '',
      this.relay = '',
      this.error = ''});

  @override
  @JsonKey()
  final String secretKey;
  @override
  @JsonKey()
  final String publicKey;
  @override
  @JsonKey()
  final String receiverPublicKey;
  @override
  @JsonKey()
  final String backupKey;
  @override
  @JsonKey()
  final String relay;
  @override
  @JsonKey()
  final String error;

  @override
  String toString() {
    return 'SocialSettingState(secretKey: $secretKey, publicKey: $publicKey, receiverPublicKey: $receiverPublicKey, backupKey: $backupKey, relay: $relay, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SocialSettingStateImpl &&
            (identical(other.secretKey, secretKey) ||
                other.secretKey == secretKey) &&
            (identical(other.publicKey, publicKey) ||
                other.publicKey == publicKey) &&
            (identical(other.receiverPublicKey, receiverPublicKey) ||
                other.receiverPublicKey == receiverPublicKey) &&
            (identical(other.backupKey, backupKey) ||
                other.backupKey == backupKey) &&
            (identical(other.relay, relay) || other.relay == relay) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType, secretKey, publicKey,
      receiverPublicKey, backupKey, relay, error);

  /// Create a copy of SocialSettingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SocialSettingStateImplCopyWith<_$SocialSettingStateImpl> get copyWith =>
      __$$SocialSettingStateImplCopyWithImpl<_$SocialSettingStateImpl>(
          this, _$identity);
}

abstract class _SocialSettingState implements SocialSettingState {
  const factory _SocialSettingState(
      {final String secretKey,
      final String publicKey,
      final String receiverPublicKey,
      final String backupKey,
      final String relay,
      final String error}) = _$SocialSettingStateImpl;

  @override
  String get secretKey;
  @override
  String get publicKey;
  @override
  String get receiverPublicKey;
  @override
  String get backupKey;
  @override
  String get relay;
  @override
  String get error;

  /// Create a copy of SocialSettingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SocialSettingStateImplCopyWith<_$SocialSettingStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
