// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'backup_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$BackupState {
  bool get loading => throw _privateConstructorUsedError;
  List<Backup> get backups => throw _privateConstructorUsedError;
  String get backupId => throw _privateConstructorUsedError;
  String get backupKey => throw _privateConstructorUsedError;
  String get error => throw _privateConstructorUsedError;

  /// Create a copy of BackupState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BackupStateCopyWith<BackupState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BackupStateCopyWith<$Res> {
  factory $BackupStateCopyWith(
          BackupState value, $Res Function(BackupState) then) =
      _$BackupStateCopyWithImpl<$Res, BackupState>;
  @useResult
  $Res call(
      {bool loading,
      List<Backup> backups,
      String backupId,
      String backupKey,
      String error});
}

/// @nodoc
class _$BackupStateCopyWithImpl<$Res, $Val extends BackupState>
    implements $BackupStateCopyWith<$Res> {
  _$BackupStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BackupState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? loading = null,
    Object? backups = null,
    Object? backupId = null,
    Object? backupKey = null,
    Object? error = null,
  }) {
    return _then(_value.copyWith(
      loading: null == loading
          ? _value.loading
          : loading // ignore: cast_nullable_to_non_nullable
              as bool,
      backups: null == backups
          ? _value.backups
          : backups // ignore: cast_nullable_to_non_nullable
              as List<Backup>,
      backupId: null == backupId
          ? _value.backupId
          : backupId // ignore: cast_nullable_to_non_nullable
              as String,
      backupKey: null == backupKey
          ? _value.backupKey
          : backupKey // ignore: cast_nullable_to_non_nullable
              as String,
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BackupStateImplCopyWith<$Res>
    implements $BackupStateCopyWith<$Res> {
  factory _$$BackupStateImplCopyWith(
          _$BackupStateImpl value, $Res Function(_$BackupStateImpl) then) =
      __$$BackupStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool loading,
      List<Backup> backups,
      String backupId,
      String backupKey,
      String error});
}

/// @nodoc
class __$$BackupStateImplCopyWithImpl<$Res>
    extends _$BackupStateCopyWithImpl<$Res, _$BackupStateImpl>
    implements _$$BackupStateImplCopyWith<$Res> {
  __$$BackupStateImplCopyWithImpl(
      _$BackupStateImpl _value, $Res Function(_$BackupStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of BackupState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? loading = null,
    Object? backups = null,
    Object? backupId = null,
    Object? backupKey = null,
    Object? error = null,
  }) {
    return _then(_$BackupStateImpl(
      loading: null == loading
          ? _value.loading
          : loading // ignore: cast_nullable_to_non_nullable
              as bool,
      backups: null == backups
          ? _value._backups
          : backups // ignore: cast_nullable_to_non_nullable
              as List<Backup>,
      backupId: null == backupId
          ? _value.backupId
          : backupId // ignore: cast_nullable_to_non_nullable
              as String,
      backupKey: null == backupKey
          ? _value.backupKey
          : backupKey // ignore: cast_nullable_to_non_nullable
              as String,
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$BackupStateImpl implements _BackupState {
  const _$BackupStateImpl(
      {this.loading = true,
      final List<Backup> backups = const [],
      this.backupId = '',
      this.backupKey = '',
      this.error = ''})
      : _backups = backups;

  @override
  @JsonKey()
  final bool loading;
  final List<Backup> _backups;
  @override
  @JsonKey()
  List<Backup> get backups {
    if (_backups is EqualUnmodifiableListView) return _backups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_backups);
  }

  @override
  @JsonKey()
  final String backupId;
  @override
  @JsonKey()
  final String backupKey;
  @override
  @JsonKey()
  final String error;

  @override
  String toString() {
    return 'BackupState(loading: $loading, backups: $backups, backupId: $backupId, backupKey: $backupKey, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BackupStateImpl &&
            (identical(other.loading, loading) || other.loading == loading) &&
            const DeepCollectionEquality().equals(other._backups, _backups) &&
            (identical(other.backupId, backupId) ||
                other.backupId == backupId) &&
            (identical(other.backupKey, backupKey) ||
                other.backupKey == backupKey) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      loading,
      const DeepCollectionEquality().hash(_backups),
      backupId,
      backupKey,
      error);

  /// Create a copy of BackupState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BackupStateImplCopyWith<_$BackupStateImpl> get copyWith =>
      __$$BackupStateImplCopyWithImpl<_$BackupStateImpl>(this, _$identity);
}

abstract class _BackupState implements BackupState {
  const factory _BackupState(
      {final bool loading,
      final List<Backup> backups,
      final String backupId,
      final String backupKey,
      final String error}) = _$BackupStateImpl;

  @override
  bool get loading;
  @override
  List<Backup> get backups;
  @override
  String get backupId;
  @override
  String get backupKey;
  @override
  String get error;

  /// Create a copy of BackupState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BackupStateImplCopyWith<_$BackupStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
