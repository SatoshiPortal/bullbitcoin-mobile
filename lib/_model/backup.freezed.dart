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
  String get name => throw _privateConstructorUsedError;
  String get layer => throw _privateConstructorUsedError;
  String get network => throw _privateConstructorUsedError;
  String get script => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  List<String> get mnemonic => throw _privateConstructorUsedError;
  String get passphrase => throw _privateConstructorUsedError;
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
      String name,
      String layer,
      String network,
      String script,
      String type,
      List<String> mnemonic,
      String passphrase,
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
    Object? name = null,
    Object? layer = null,
    Object? network = null,
    Object? script = null,
    Object? type = null,
    Object? mnemonic = null,
    Object? passphrase = null,
    Object? labels = null,
    Object? descriptors = null,
  }) {
    return _then(_value.copyWith(
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      layer: null == layer
          ? _value.layer
          : layer // ignore: cast_nullable_to_non_nullable
              as String,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as String,
      script: null == script
          ? _value.script
          : script // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      mnemonic: null == mnemonic
          ? _value.mnemonic
          : mnemonic // ignore: cast_nullable_to_non_nullable
              as List<String>,
      passphrase: null == passphrase
          ? _value.passphrase
          : passphrase // ignore: cast_nullable_to_non_nullable
              as String,
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
      String name,
      String layer,
      String network,
      String script,
      String type,
      List<String> mnemonic,
      String passphrase,
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
    Object? name = null,
    Object? layer = null,
    Object? network = null,
    Object? script = null,
    Object? type = null,
    Object? mnemonic = null,
    Object? passphrase = null,
    Object? labels = null,
    Object? descriptors = null,
  }) {
    return _then(_$BackupImpl(
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      layer: null == layer
          ? _value.layer
          : layer // ignore: cast_nullable_to_non_nullable
              as String,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as String,
      script: null == script
          ? _value.script
          : script // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      mnemonic: null == mnemonic
          ? _value._mnemonic
          : mnemonic // ignore: cast_nullable_to_non_nullable
              as List<String>,
      passphrase: null == passphrase
          ? _value.passphrase
          : passphrase // ignore: cast_nullable_to_non_nullable
              as String,
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
      this.name = '',
      this.layer = '',
      this.network = '',
      this.script = '',
      this.type = '',
      final List<String> mnemonic = const <String>[],
      this.passphrase = '',
      final List<Bip329Label> labels = const <Bip329Label>[],
      final List<String> descriptors = const <String>[]})
      : _mnemonic = mnemonic,
        _labels = labels,
        _descriptors = descriptors,
        super._();

  factory _$BackupImpl.fromJson(Map<String, dynamic> json) =>
      _$$BackupImplFromJson(json);

  @override
  @JsonKey()
  final int version;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String layer;
  @override
  @JsonKey()
  final String network;
  @override
  @JsonKey()
  final String script;
  @override
  @JsonKey()
  final String type;
  final List<String> _mnemonic;
  @override
  @JsonKey()
  List<String> get mnemonic {
    if (_mnemonic is EqualUnmodifiableListView) return _mnemonic;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mnemonic);
  }

  @override
  @JsonKey()
  final String passphrase;
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
    return 'Backup(version: $version, name: $name, layer: $layer, network: $network, script: $script, type: $type, mnemonic: $mnemonic, passphrase: $passphrase, labels: $labels, descriptors: $descriptors)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BackupImpl &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.layer, layer) || other.layer == layer) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.script, script) || other.script == script) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(other._mnemonic, _mnemonic) &&
            (identical(other.passphrase, passphrase) ||
                other.passphrase == passphrase) &&
            const DeepCollectionEquality().equals(other._labels, _labels) &&
            const DeepCollectionEquality()
                .equals(other._descriptors, _descriptors));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      version,
      name,
      layer,
      network,
      script,
      type,
      const DeepCollectionEquality().hash(_mnemonic),
      passphrase,
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
      final String name,
      final String layer,
      final String network,
      final String script,
      final String type,
      final List<String> mnemonic,
      final String passphrase,
      final List<Bip329Label> labels,
      final List<String> descriptors}) = _$BackupImpl;
  const _Backup._() : super._();

  factory _Backup.fromJson(Map<String, dynamic> json) = _$BackupImpl.fromJson;

  @override
  int get version;
  @override
  String get name;
  @override
  String get layer;
  @override
  String get network;
  @override
  String get script;
  @override
  String get type;
  @override
  List<String> get mnemonic;
  @override
  String get passphrase;
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
