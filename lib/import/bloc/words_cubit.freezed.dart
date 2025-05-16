// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'words_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$WordsState {
/**
     * 
     * SENSITIVE
     * 
     */
  List<String>? get words => throw _privateConstructorUsedError;
  /**
     * 
     * SENSITIVE
     * 
     */
  String get err => throw _privateConstructorUsedError;
  bool get loading => throw _privateConstructorUsedError;

  /// Create a copy of WordsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WordsStateCopyWith<WordsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WordsStateCopyWith<$Res> {
  factory $WordsStateCopyWith(
          WordsState value, $Res Function(WordsState) then) =
      _$WordsStateCopyWithImpl<$Res, WordsState>;
  @useResult
  $Res call({List<String>? words, String err, bool loading});
}

/// @nodoc
class _$WordsStateCopyWithImpl<$Res, $Val extends WordsState>
    implements $WordsStateCopyWith<$Res> {
  _$WordsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WordsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? words = freezed,
    Object? err = null,
    Object? loading = null,
  }) {
    return _then(_value.copyWith(
      words: freezed == words
          ? _value.words
          : words // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      err: null == err
          ? _value.err
          : err // ignore: cast_nullable_to_non_nullable
              as String,
      loading: null == loading
          ? _value.loading
          : loading // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WordsStateImplCopyWith<$Res>
    implements $WordsStateCopyWith<$Res> {
  factory _$$WordsStateImplCopyWith(
          _$WordsStateImpl value, $Res Function(_$WordsStateImpl) then) =
      __$$WordsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<String>? words, String err, bool loading});
}

/// @nodoc
class __$$WordsStateImplCopyWithImpl<$Res>
    extends _$WordsStateCopyWithImpl<$Res, _$WordsStateImpl>
    implements _$$WordsStateImplCopyWith<$Res> {
  __$$WordsStateImplCopyWithImpl(
      _$WordsStateImpl _value, $Res Function(_$WordsStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of WordsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? words = freezed,
    Object? err = null,
    Object? loading = null,
  }) {
    return _then(_$WordsStateImpl(
      words: freezed == words
          ? _value._words
          : words // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      err: null == err
          ? _value.err
          : err // ignore: cast_nullable_to_non_nullable
              as String,
      loading: null == loading
          ? _value.loading
          : loading // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$WordsStateImpl extends _WordsState {
  const _$WordsStateImpl(
      {final List<String>? words, this.err = '', this.loading = false})
      : _words = words,
        super._();

/**
     * 
     * SENSITIVE
     * 
     */
  final List<String>? _words;
/**
     * 
     * SENSITIVE
     * 
     */
  @override
  List<String>? get words {
    final value = _words;
    if (value == null) return null;
    if (_words is EqualUnmodifiableListView) return _words;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

/**
     * 
     * SENSITIVE
     * 
     */
  @override
  @JsonKey()
  final String err;
  @override
  @JsonKey()
  final bool loading;

  @override
  String toString() {
    return 'WordsState(words: $words, err: $err, loading: $loading)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WordsStateImpl &&
            const DeepCollectionEquality().equals(other._words, _words) &&
            (identical(other.err, err) || other.err == err) &&
            (identical(other.loading, loading) || other.loading == loading));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_words), err, loading);

  /// Create a copy of WordsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WordsStateImplCopyWith<_$WordsStateImpl> get copyWith =>
      __$$WordsStateImplCopyWithImpl<_$WordsStateImpl>(this, _$identity);
}

abstract class _WordsState extends WordsState {
  const factory _WordsState(
      {final List<String>? words,
      final String err,
      final bool loading}) = _$WordsStateImpl;
  const _WordsState._() : super._();

/**
     * 
     * SENSITIVE
     * 
     */
  @override
  List<String>? get words;
  /**
     * 
     * SENSITIVE
     * 
     */
  @override
  String get err;
  @override
  bool get loading;

  /// Create a copy of WordsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WordsStateImplCopyWith<_$WordsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
