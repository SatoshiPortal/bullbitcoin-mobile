// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'swap_history_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SwapHistoryState {
  List<SwapTx> get swaps => throw _privateConstructorUsedError;
  List<Transaction> get completeSwaps => throw _privateConstructorUsedError;
  List<String> get refreshing => throw _privateConstructorUsedError;
  String get errRefreshing => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $SwapHistoryStateCopyWith<SwapHistoryState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SwapHistoryStateCopyWith<$Res> {
  factory $SwapHistoryStateCopyWith(
          SwapHistoryState value, $Res Function(SwapHistoryState) then) =
      _$SwapHistoryStateCopyWithImpl<$Res, SwapHistoryState>;
  @useResult
  $Res call(
      {List<SwapTx> swaps,
      List<Transaction> completeSwaps,
      List<String> refreshing,
      String errRefreshing});
}

/// @nodoc
class _$SwapHistoryStateCopyWithImpl<$Res, $Val extends SwapHistoryState>
    implements $SwapHistoryStateCopyWith<$Res> {
  _$SwapHistoryStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? swaps = null,
    Object? completeSwaps = null,
    Object? refreshing = null,
    Object? errRefreshing = null,
  }) {
    return _then(_value.copyWith(
      swaps: null == swaps
          ? _value.swaps
          : swaps // ignore: cast_nullable_to_non_nullable
              as List<SwapTx>,
      completeSwaps: null == completeSwaps
          ? _value.completeSwaps
          : completeSwaps // ignore: cast_nullable_to_non_nullable
              as List<Transaction>,
      refreshing: null == refreshing
          ? _value.refreshing
          : refreshing // ignore: cast_nullable_to_non_nullable
              as List<String>,
      errRefreshing: null == errRefreshing
          ? _value.errRefreshing
          : errRefreshing // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SwapHistoryStateImplCopyWith<$Res>
    implements $SwapHistoryStateCopyWith<$Res> {
  factory _$$SwapHistoryStateImplCopyWith(_$SwapHistoryStateImpl value,
          $Res Function(_$SwapHistoryStateImpl) then) =
      __$$SwapHistoryStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<SwapTx> swaps,
      List<Transaction> completeSwaps,
      List<String> refreshing,
      String errRefreshing});
}

/// @nodoc
class __$$SwapHistoryStateImplCopyWithImpl<$Res>
    extends _$SwapHistoryStateCopyWithImpl<$Res, _$SwapHistoryStateImpl>
    implements _$$SwapHistoryStateImplCopyWith<$Res> {
  __$$SwapHistoryStateImplCopyWithImpl(_$SwapHistoryStateImpl _value,
      $Res Function(_$SwapHistoryStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? swaps = null,
    Object? completeSwaps = null,
    Object? refreshing = null,
    Object? errRefreshing = null,
  }) {
    return _then(_$SwapHistoryStateImpl(
      swaps: null == swaps
          ? _value._swaps
          : swaps // ignore: cast_nullable_to_non_nullable
              as List<SwapTx>,
      completeSwaps: null == completeSwaps
          ? _value._completeSwaps
          : completeSwaps // ignore: cast_nullable_to_non_nullable
              as List<Transaction>,
      refreshing: null == refreshing
          ? _value._refreshing
          : refreshing // ignore: cast_nullable_to_non_nullable
              as List<String>,
      errRefreshing: null == errRefreshing
          ? _value.errRefreshing
          : errRefreshing // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$SwapHistoryStateImpl extends _SwapHistoryState {
  const _$SwapHistoryStateImpl(
      {final List<SwapTx> swaps = const [],
      final List<Transaction> completeSwaps = const [],
      final List<String> refreshing = const [],
      this.errRefreshing = ''})
      : _swaps = swaps,
        _completeSwaps = completeSwaps,
        _refreshing = refreshing,
        super._();

  final List<SwapTx> _swaps;
  @override
  @JsonKey()
  List<SwapTx> get swaps {
    if (_swaps is EqualUnmodifiableListView) return _swaps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_swaps);
  }

  final List<Transaction> _completeSwaps;
  @override
  @JsonKey()
  List<Transaction> get completeSwaps {
    if (_completeSwaps is EqualUnmodifiableListView) return _completeSwaps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_completeSwaps);
  }

  final List<String> _refreshing;
  @override
  @JsonKey()
  List<String> get refreshing {
    if (_refreshing is EqualUnmodifiableListView) return _refreshing;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_refreshing);
  }

  @override
  @JsonKey()
  final String errRefreshing;

  @override
  String toString() {
    return 'SwapHistoryState(swaps: $swaps, completeSwaps: $completeSwaps, refreshing: $refreshing, errRefreshing: $errRefreshing)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SwapHistoryStateImpl &&
            const DeepCollectionEquality().equals(other._swaps, _swaps) &&
            const DeepCollectionEquality()
                .equals(other._completeSwaps, _completeSwaps) &&
            const DeepCollectionEquality()
                .equals(other._refreshing, _refreshing) &&
            (identical(other.errRefreshing, errRefreshing) ||
                other.errRefreshing == errRefreshing));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_swaps),
      const DeepCollectionEquality().hash(_completeSwaps),
      const DeepCollectionEquality().hash(_refreshing),
      errRefreshing);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SwapHistoryStateImplCopyWith<_$SwapHistoryStateImpl> get copyWith =>
      __$$SwapHistoryStateImplCopyWithImpl<_$SwapHistoryStateImpl>(
          this, _$identity);
}

abstract class _SwapHistoryState extends SwapHistoryState {
  const factory _SwapHistoryState(
      {final List<SwapTx> swaps,
      final List<Transaction> completeSwaps,
      final List<String> refreshing,
      final String errRefreshing}) = _$SwapHistoryStateImpl;
  const _SwapHistoryState._() : super._();

  @override
  List<SwapTx> get swaps;
  @override
  List<Transaction> get completeSwaps;
  @override
  List<String> get refreshing;
  @override
  String get errRefreshing;
  @override
  @JsonKey(ignore: true)
  _$$SwapHistoryStateImplCopyWith<_$SwapHistoryStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
