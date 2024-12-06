// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'keychain_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$KeychainState {
  String get error => throw _privateConstructorUsedError;
  String get backupKey => throw _privateConstructorUsedError;
  String get backupId => throw _privateConstructorUsedError;
  String get secret => throw _privateConstructorUsedError;

  /// Create a copy of KeychainState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $KeychainStateCopyWith<KeychainState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $KeychainStateCopyWith<$Res> {
  factory $KeychainStateCopyWith(
          KeychainState value, $Res Function(KeychainState) then) =
      _$KeychainStateCopyWithImpl<$Res, KeychainState>;
  @useResult
  $Res call({String error, String backupKey, String backupId, String secret});
}

/// @nodoc
class _$KeychainStateCopyWithImpl<$Res, $Val extends KeychainState>
    implements $KeychainStateCopyWith<$Res> {
  _$KeychainStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of KeychainState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? error = null,
    Object? backupKey = null,
    Object? backupId = null,
    Object? secret = null,
  }) {
    return _then(_value.copyWith(
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
      backupKey: null == backupKey
          ? _value.backupKey
          : backupKey // ignore: cast_nullable_to_non_nullable
              as String,
      backupId: null == backupId
          ? _value.backupId
          : backupId // ignore: cast_nullable_to_non_nullable
              as String,
      secret: null == secret
          ? _value.secret
          : secret // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$KeychainStateImplCopyWith<$Res>
    implements $KeychainStateCopyWith<$Res> {
  factory _$$KeychainStateImplCopyWith(
          _$KeychainStateImpl value, $Res Function(_$KeychainStateImpl) then) =
      __$$KeychainStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String error, String backupKey, String backupId, String secret});
}

/// @nodoc
class __$$KeychainStateImplCopyWithImpl<$Res>
    extends _$KeychainStateCopyWithImpl<$Res, _$KeychainStateImpl>
    implements _$$KeychainStateImplCopyWith<$Res> {
  __$$KeychainStateImplCopyWithImpl(
      _$KeychainStateImpl _value, $Res Function(_$KeychainStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of KeychainState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? error = null,
    Object? backupKey = null,
    Object? backupId = null,
    Object? secret = null,
  }) {
    return _then(_$KeychainStateImpl(
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
      backupKey: null == backupKey
          ? _value.backupKey
          : backupKey // ignore: cast_nullable_to_non_nullable
              as String,
      backupId: null == backupId
          ? _value.backupId
          : backupId // ignore: cast_nullable_to_non_nullable
              as String,
      secret: null == secret
          ? _value.secret
          : secret // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$KeychainStateImpl implements _KeychainState {
  const _$KeychainStateImpl(
      {this.error = '',
      this.backupKey = '',
      this.backupId = '',
      this.secret = ''});

  @override
  @JsonKey()
  final String error;
  @override
  @JsonKey()
  final String backupKey;
  @override
  @JsonKey()
  final String backupId;
  @override
  @JsonKey()
  final String secret;

  @override
  String toString() {
    return 'KeychainState(error: $error, backupKey: $backupKey, backupId: $backupId, secret: $secret)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$KeychainStateImpl &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.backupKey, backupKey) ||
                other.backupKey == backupKey) &&
            (identical(other.backupId, backupId) ||
                other.backupId == backupId) &&
            (identical(other.secret, secret) || other.secret == secret));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, error, backupKey, backupId, secret);

  /// Create a copy of KeychainState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$KeychainStateImplCopyWith<_$KeychainStateImpl> get copyWith =>
      __$$KeychainStateImplCopyWithImpl<_$KeychainStateImpl>(this, _$identity);
}

abstract class _KeychainState implements KeychainState {
  const factory _KeychainState(
      {final String error,
      final String backupKey,
      final String backupId,
      final String secret}) = _$KeychainStateImpl;

  @override
  String get error;
  @override
  String get backupKey;
  @override
  String get backupId;
  @override
  String get secret;

  /// Create a copy of KeychainState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$KeychainStateImplCopyWith<_$KeychainStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
