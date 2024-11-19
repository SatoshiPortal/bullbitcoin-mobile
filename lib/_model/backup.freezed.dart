// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'backup.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Backup _$BackupFromJson(Map<String, dynamic> json) {
  return _Backup.fromJson(json);
}

/// @nodoc
mixin _$Backup {
  int get version => throw _privateConstructorUsedError;
  List<String> get mnemonic => throw _privateConstructorUsedError;
  List<String> get passphrases => throw _privateConstructorUsedError;
  List<Bip329Label> get labels => throw _privateConstructorUsedError;
  List<String> get descriptors => throw _privateConstructorUsedError;

  /// Serializes this Backup to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Backup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BackupCopyWith<Backup> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BackupCopyWith<$Res> {
  factory $BackupCopyWith(Backup value, $Res Function(Backup) then) =
      _$BackupCopyWithImpl<$Res, Backup>;
  @useResult
  $Res call(
      {int version,
      List<String> mnemonic,
      List<String> passphrases,
      List<Bip329Label> labels,
      List<String> descriptors});
}

/// @nodoc
class _$BackupCopyWithImpl<$Res, $Val extends Backup>
    implements $BackupCopyWith<$Res> {
  _$BackupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Backup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? mnemonic = null,
    Object? passphrases = null,
    Object? labels = null,
    Object? descriptors = null,
  }) {
    return _then(_value.copyWith(
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      mnemonic: null == mnemonic
          ? _value.mnemonic
          : mnemonic // ignore: cast_nullable_to_non_nullable
              as List<String>,
      passphrases: null == passphrases
          ? _value.passphrases
          : passphrases // ignore: cast_nullable_to_non_nullable
              as List<String>,
      labels: null == labels
          ? _value.labels
          : labels // ignore: cast_nullable_to_non_nullable
              as List<Bip329Label>,
      descriptors: null == descriptors
          ? _value.descriptors
          : descriptors // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BackupImplCopyWith<$Res> implements $BackupCopyWith<$Res> {
  factory _$$BackupImplCopyWith(
          _$BackupImpl value, $Res Function(_$BackupImpl) then) =
      __$$BackupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int version,
      List<String> mnemonic,
      List<String> passphrases,
      List<Bip329Label> labels,
      List<String> descriptors});
}

/// @nodoc
class __$$BackupImplCopyWithImpl<$Res>
    extends _$BackupCopyWithImpl<$Res, _$BackupImpl>
    implements _$$BackupImplCopyWith<$Res> {
  __$$BackupImplCopyWithImpl(
      _$BackupImpl _value, $Res Function(_$BackupImpl) _then)
      : super(_value, _then);

  /// Create a copy of Backup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? mnemonic = null,
    Object? passphrases = null,
    Object? labels = null,
    Object? descriptors = null,
  }) {
    return _then(_$BackupImpl(
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      mnemonic: null == mnemonic
          ? _value._mnemonic
          : mnemonic // ignore: cast_nullable_to_non_nullable
              as List<String>,
      passphrases: null == passphrases
          ? _value._passphrases
          : passphrases // ignore: cast_nullable_to_non_nullable
              as List<String>,
      labels: null == labels
          ? _value._labels
          : labels // ignore: cast_nullable_to_non_nullable
              as List<Bip329Label>,
      descriptors: null == descriptors
          ? _value._descriptors
          : descriptors // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BackupImpl extends _Backup {
  const _$BackupImpl(
      {this.version = 1,
      final List<String> mnemonic = const <String>[],
      final List<String> passphrases = const <String>[],
      final List<Bip329Label> labels = const <Bip329Label>[],
      final List<String> descriptors = const <String>[]})
      : _mnemonic = mnemonic,
        _passphrases = passphrases,
        _labels = labels,
        _descriptors = descriptors,
        super._();

  factory _$BackupImpl.fromJson(Map<String, dynamic> json) =>
      _$$BackupImplFromJson(json);

  @override
  @JsonKey()
  final int version;
  final List<String> _mnemonic;
  @override
  @JsonKey()
  List<String> get mnemonic {
    if (_mnemonic is EqualUnmodifiableListView) return _mnemonic;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mnemonic);
  }

  final List<String> _passphrases;
  @override
  @JsonKey()
  List<String> get passphrases {
    if (_passphrases is EqualUnmodifiableListView) return _passphrases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_passphrases);
  }

  final List<Bip329Label> _labels;
  @override
  @JsonKey()
  List<Bip329Label> get labels {
    if (_labels is EqualUnmodifiableListView) return _labels;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_labels);
  }

  final List<String> _descriptors;
  @override
  @JsonKey()
  List<String> get descriptors {
    if (_descriptors is EqualUnmodifiableListView) return _descriptors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_descriptors);
  }

  @override
  String toString() {
    return 'Backup(version: $version, mnemonic: $mnemonic, passphrases: $passphrases, labels: $labels, descriptors: $descriptors)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BackupImpl &&
            (identical(other.version, version) || other.version == version) &&
            const DeepCollectionEquality().equals(other._mnemonic, _mnemonic) &&
            const DeepCollectionEquality()
                .equals(other._passphrases, _passphrases) &&
            const DeepCollectionEquality().equals(other._labels, _labels) &&
            const DeepCollectionEquality()
                .equals(other._descriptors, _descriptors));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      version,
      const DeepCollectionEquality().hash(_mnemonic),
      const DeepCollectionEquality().hash(_passphrases),
      const DeepCollectionEquality().hash(_labels),
      const DeepCollectionEquality().hash(_descriptors));

  /// Create a copy of Backup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BackupImplCopyWith<_$BackupImpl> get copyWith =>
      __$$BackupImplCopyWithImpl<_$BackupImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BackupImplToJson(
      this,
    );
  }
}

abstract class _Backup extends Backup {
  const factory _Backup(
      {final int version,
      final List<String> mnemonic,
      final List<String> passphrases,
      final List<Bip329Label> labels,
      final List<String> descriptors}) = _$BackupImpl;
  const _Backup._() : super._();

  factory _Backup.fromJson(Map<String, dynamic> json) = _$BackupImpl.fromJson;

  @override
  int get version;
  @override
  List<String> get mnemonic;
  @override
  List<String> get passphrases;
  @override
  List<Bip329Label> get labels;
  @override
  List<String> get descriptors;

  /// Create a copy of Backup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BackupImplCopyWith<_$BackupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
