// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Profile _$ProfileFromJson(Map<String, dynamic> json) {
  return _Profile.fromJson(json);
}

/// @nodoc
mixin _$Profile {
  String get name => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  DateTime get registrationDate => throw _privateConstructorUsedError;
  int get totalClients => throw _privateConstructorUsedError;
  int get activeClients => throw _privateConstructorUsedError;

  /// Serializes this Profile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProfileCopyWith<Profile> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfileCopyWith<$Res> {
  factory $ProfileCopyWith(Profile value, $Res Function(Profile) then) =
      _$ProfileCopyWithImpl<$Res, Profile>;
  @useResult
  $Res call({
    String name,
    String email,
    String phone,
    DateTime registrationDate,
    int totalClients,
    int activeClients,
  });
}

/// @nodoc
class _$ProfileCopyWithImpl<$Res, $Val extends Profile>
    implements $ProfileCopyWith<$Res> {
  _$ProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? email = null,
    Object? phone = null,
    Object? registrationDate = null,
    Object? totalClients = null,
    Object? activeClients = null,
  }) {
    return _then(
      _value.copyWith(
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            email:
                null == email
                    ? _value.email
                    : email // ignore: cast_nullable_to_non_nullable
                        as String,
            phone:
                null == phone
                    ? _value.phone
                    : phone // ignore: cast_nullable_to_non_nullable
                        as String,
            registrationDate:
                null == registrationDate
                    ? _value.registrationDate
                    : registrationDate // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            totalClients:
                null == totalClients
                    ? _value.totalClients
                    : totalClients // ignore: cast_nullable_to_non_nullable
                        as int,
            activeClients:
                null == activeClients
                    ? _value.activeClients
                    : activeClients // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProfileImplCopyWith<$Res> implements $ProfileCopyWith<$Res> {
  factory _$$ProfileImplCopyWith(
    _$ProfileImpl value,
    $Res Function(_$ProfileImpl) then,
  ) = __$$ProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String email,
    String phone,
    DateTime registrationDate,
    int totalClients,
    int activeClients,
  });
}

/// @nodoc
class __$$ProfileImplCopyWithImpl<$Res>
    extends _$ProfileCopyWithImpl<$Res, _$ProfileImpl>
    implements _$$ProfileImplCopyWith<$Res> {
  __$$ProfileImplCopyWithImpl(
    _$ProfileImpl _value,
    $Res Function(_$ProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? email = null,
    Object? phone = null,
    Object? registrationDate = null,
    Object? totalClients = null,
    Object? activeClients = null,
  }) {
    return _then(
      _$ProfileImpl(
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        email:
            null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                    as String,
        phone:
            null == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                    as String,
        registrationDate:
            null == registrationDate
                ? _value.registrationDate
                : registrationDate // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        totalClients:
            null == totalClients
                ? _value.totalClients
                : totalClients // ignore: cast_nullable_to_non_nullable
                    as int,
        activeClients:
            null == activeClients
                ? _value.activeClients
                : activeClients // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProfileImpl implements _Profile {
  const _$ProfileImpl({
    required this.name,
    required this.email,
    required this.phone,
    required this.registrationDate,
    required this.totalClients,
    required this.activeClients,
  });

  factory _$ProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProfileImplFromJson(json);

  @override
  final String name;
  @override
  final String email;
  @override
  final String phone;
  @override
  final DateTime registrationDate;
  @override
  final int totalClients;
  @override
  final int activeClients;

  @override
  String toString() {
    return 'Profile(name: $name, email: $email, phone: $phone, registrationDate: $registrationDate, totalClients: $totalClients, activeClients: $activeClients)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.registrationDate, registrationDate) ||
                other.registrationDate == registrationDate) &&
            (identical(other.totalClients, totalClients) ||
                other.totalClients == totalClients) &&
            (identical(other.activeClients, activeClients) ||
                other.activeClients == activeClients));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    email,
    phone,
    registrationDate,
    totalClients,
    activeClients,
  );

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfileImplCopyWith<_$ProfileImpl> get copyWith =>
      __$$ProfileImplCopyWithImpl<_$ProfileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProfileImplToJson(this);
  }
}

abstract class _Profile implements Profile {
  const factory _Profile({
    required final String name,
    required final String email,
    required final String phone,
    required final DateTime registrationDate,
    required final int totalClients,
    required final int activeClients,
  }) = _$ProfileImpl;

  factory _Profile.fromJson(Map<String, dynamic> json) = _$ProfileImpl.fromJson;

  @override
  String get name;
  @override
  String get email;
  @override
  String get phone;
  @override
  DateTime get registrationDate;
  @override
  int get totalClients;
  @override
  int get activeClients;

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProfileImplCopyWith<_$ProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Revenue _$RevenueFromJson(Map<String, dynamic> json) {
  return _Revenue.fromJson(json);
}

/// @nodoc
mixin _$Revenue {
  String get cycle => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String get cep => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  String get clientName => throw _privateConstructorUsedError;

  /// Serializes this Revenue to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Revenue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RevenueCopyWith<Revenue> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RevenueCopyWith<$Res> {
  factory $RevenueCopyWith(Revenue value, $Res Function(Revenue) then) =
      _$RevenueCopyWithImpl<$Res, Revenue>;
  @useResult
  $Res call({
    String cycle,
    String type,
    String cep,
    double amount,
    String clientName,
  });
}

/// @nodoc
class _$RevenueCopyWithImpl<$Res, $Val extends Revenue>
    implements $RevenueCopyWith<$Res> {
  _$RevenueCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Revenue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cycle = null,
    Object? type = null,
    Object? cep = null,
    Object? amount = null,
    Object? clientName = null,
  }) {
    return _then(
      _value.copyWith(
            cycle:
                null == cycle
                    ? _value.cycle
                    : cycle // ignore: cast_nullable_to_non_nullable
                        as String,
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as String,
            cep:
                null == cep
                    ? _value.cep
                    : cep // ignore: cast_nullable_to_non_nullable
                        as String,
            amount:
                null == amount
                    ? _value.amount
                    : amount // ignore: cast_nullable_to_non_nullable
                        as double,
            clientName:
                null == clientName
                    ? _value.clientName
                    : clientName // ignore: cast_nullable_to_non_nullable
                        as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RevenueImplCopyWith<$Res> implements $RevenueCopyWith<$Res> {
  factory _$$RevenueImplCopyWith(
    _$RevenueImpl value,
    $Res Function(_$RevenueImpl) then,
  ) = __$$RevenueImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String cycle,
    String type,
    String cep,
    double amount,
    String clientName,
  });
}

/// @nodoc
class __$$RevenueImplCopyWithImpl<$Res>
    extends _$RevenueCopyWithImpl<$Res, _$RevenueImpl>
    implements _$$RevenueImplCopyWith<$Res> {
  __$$RevenueImplCopyWithImpl(
    _$RevenueImpl _value,
    $Res Function(_$RevenueImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Revenue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cycle = null,
    Object? type = null,
    Object? cep = null,
    Object? amount = null,
    Object? clientName = null,
  }) {
    return _then(
      _$RevenueImpl(
        cycle:
            null == cycle
                ? _value.cycle
                : cycle // ignore: cast_nullable_to_non_nullable
                    as String,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as String,
        cep:
            null == cep
                ? _value.cep
                : cep // ignore: cast_nullable_to_non_nullable
                    as String,
        amount:
            null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                    as double,
        clientName:
            null == clientName
                ? _value.clientName
                : clientName // ignore: cast_nullable_to_non_nullable
                    as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RevenueImpl implements _Revenue {
  const _$RevenueImpl({
    required this.cycle,
    required this.type,
    required this.cep,
    required this.amount,
    required this.clientName,
  });

  factory _$RevenueImpl.fromJson(Map<String, dynamic> json) =>
      _$$RevenueImplFromJson(json);

  @override
  final String cycle;
  @override
  final String type;
  @override
  final String cep;
  @override
  final double amount;
  @override
  final String clientName;

  @override
  String toString() {
    return 'Revenue(cycle: $cycle, type: $type, cep: $cep, amount: $amount, clientName: $clientName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevenueImpl &&
            (identical(other.cycle, cycle) || other.cycle == cycle) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.cep, cep) || other.cep == cep) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.clientName, clientName) ||
                other.clientName == clientName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, cycle, type, cep, amount, clientName);

  /// Create a copy of Revenue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevenueImplCopyWith<_$RevenueImpl> get copyWith =>
      __$$RevenueImplCopyWithImpl<_$RevenueImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RevenueImplToJson(this);
  }
}

abstract class _Revenue implements Revenue {
  const factory _Revenue({
    required final String cycle,
    required final String type,
    required final String cep,
    required final double amount,
    required final String clientName,
  }) = _$RevenueImpl;

  factory _Revenue.fromJson(Map<String, dynamic> json) = _$RevenueImpl.fromJson;

  @override
  String get cycle;
  @override
  String get type;
  @override
  String get cep;
  @override
  double get amount;
  @override
  String get clientName;

  /// Create a copy of Revenue
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevenueImplCopyWith<_$RevenueImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
