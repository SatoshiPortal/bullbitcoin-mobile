// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'social_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SocialState {
  String get toast => throw _privateConstructorUsedError;
  String get friendBackupKey => throw _privateConstructorUsedError;
  String get friendBackupKeySignature => throw _privateConstructorUsedError;
  List<Event> get messages => throw _privateConstructorUsedError;
  Map<String, Event> get filter => throw _privateConstructorUsedError;

  /// Create a copy of SocialState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SocialStateCopyWith<SocialState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SocialStateCopyWith<$Res> {
  factory $SocialStateCopyWith(
          SocialState value, $Res Function(SocialState) then) =
      _$SocialStateCopyWithImpl<$Res, SocialState>;
  @useResult
  $Res call(
      {String toast,
      String friendBackupKey,
      String friendBackupKeySignature,
      List<Event> messages,
      Map<String, Event> filter});
}

/// @nodoc
class _$SocialStateCopyWithImpl<$Res, $Val extends SocialState>
    implements $SocialStateCopyWith<$Res> {
  _$SocialStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SocialState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toast = null,
    Object? friendBackupKey = null,
    Object? friendBackupKeySignature = null,
    Object? messages = null,
    Object? filter = null,
  }) {
    return _then(_value.copyWith(
      toast: null == toast
          ? _value.toast
          : toast // ignore: cast_nullable_to_non_nullable
              as String,
      friendBackupKey: null == friendBackupKey
          ? _value.friendBackupKey
          : friendBackupKey // ignore: cast_nullable_to_non_nullable
              as String,
      friendBackupKeySignature: null == friendBackupKeySignature
          ? _value.friendBackupKeySignature
          : friendBackupKeySignature // ignore: cast_nullable_to_non_nullable
              as String,
      messages: null == messages
          ? _value.messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<Event>,
      filter: null == filter
          ? _value.filter
          : filter // ignore: cast_nullable_to_non_nullable
              as Map<String, Event>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SocialStateImplCopyWith<$Res>
    implements $SocialStateCopyWith<$Res> {
  factory _$$SocialStateImplCopyWith(
          _$SocialStateImpl value, $Res Function(_$SocialStateImpl) then) =
      __$$SocialStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String toast,
      String friendBackupKey,
      String friendBackupKeySignature,
      List<Event> messages,
      Map<String, Event> filter});
}

/// @nodoc
class __$$SocialStateImplCopyWithImpl<$Res>
    extends _$SocialStateCopyWithImpl<$Res, _$SocialStateImpl>
    implements _$$SocialStateImplCopyWith<$Res> {
  __$$SocialStateImplCopyWithImpl(
      _$SocialStateImpl _value, $Res Function(_$SocialStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SocialState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toast = null,
    Object? friendBackupKey = null,
    Object? friendBackupKeySignature = null,
    Object? messages = null,
    Object? filter = null,
  }) {
    return _then(_$SocialStateImpl(
      toast: null == toast
          ? _value.toast
          : toast // ignore: cast_nullable_to_non_nullable
              as String,
      friendBackupKey: null == friendBackupKey
          ? _value.friendBackupKey
          : friendBackupKey // ignore: cast_nullable_to_non_nullable
              as String,
      friendBackupKeySignature: null == friendBackupKeySignature
          ? _value.friendBackupKeySignature
          : friendBackupKeySignature // ignore: cast_nullable_to_non_nullable
              as String,
      messages: null == messages
          ? _value._messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<Event>,
      filter: null == filter
          ? _value._filter
          : filter // ignore: cast_nullable_to_non_nullable
              as Map<String, Event>,
    ));
  }
}

/// @nodoc

class _$SocialStateImpl implements _SocialState {
  const _$SocialStateImpl(
      {this.toast = '',
      this.friendBackupKey = '',
      this.friendBackupKeySignature = '',
      final List<Event> messages = const [],
      final Map<String, Event> filter = const {}})
      : _messages = messages,
        _filter = filter;

  @override
  @JsonKey()
  final String toast;
  @override
  @JsonKey()
  final String friendBackupKey;
  @override
  @JsonKey()
  final String friendBackupKeySignature;
  final List<Event> _messages;
  @override
  @JsonKey()
  List<Event> get messages {
    if (_messages is EqualUnmodifiableListView) return _messages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_messages);
  }

  final Map<String, Event> _filter;
  @override
  @JsonKey()
  Map<String, Event> get filter {
    if (_filter is EqualUnmodifiableMapView) return _filter;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_filter);
  }

  @override
  String toString() {
    return 'SocialState(toast: $toast, friendBackupKey: $friendBackupKey, friendBackupKeySignature: $friendBackupKeySignature, messages: $messages, filter: $filter)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SocialStateImpl &&
            (identical(other.toast, toast) || other.toast == toast) &&
            (identical(other.friendBackupKey, friendBackupKey) ||
                other.friendBackupKey == friendBackupKey) &&
            (identical(
                    other.friendBackupKeySignature, friendBackupKeySignature) ||
                other.friendBackupKeySignature == friendBackupKeySignature) &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            const DeepCollectionEquality().equals(other._filter, _filter));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      toast,
      friendBackupKey,
      friendBackupKeySignature,
      const DeepCollectionEquality().hash(_messages),
      const DeepCollectionEquality().hash(_filter));

  /// Create a copy of SocialState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SocialStateImplCopyWith<_$SocialStateImpl> get copyWith =>
      __$$SocialStateImplCopyWithImpl<_$SocialStateImpl>(this, _$identity);
}

abstract class _SocialState implements SocialState {
  const factory _SocialState(
      {final String toast,
      final String friendBackupKey,
      final String friendBackupKeySignature,
      final List<Event> messages,
      final Map<String, Event> filter}) = _$SocialStateImpl;

  @override
  String get toast;
  @override
  String get friendBackupKey;
  @override
  String get friendBackupKeySignature;
  @override
  List<Event> get messages;
  @override
  Map<String, Event> get filter;

  /// Create a copy of SocialState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SocialStateImplCopyWith<_$SocialStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
