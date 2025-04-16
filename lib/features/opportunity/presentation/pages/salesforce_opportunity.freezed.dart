// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'salesforce_opportunity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SalesforceOpportunity _$SalesforceOpportunityFromJson(
    Map<String, dynamic> json) {
  return _SalesforceOpportunity.fromJson(json);
}

/// @nodoc
mixin _$SalesforceOpportunity {
  String get Id => throw _privateConstructorUsedError;
  String get Name => throw _privateConstructorUsedError;
  String? get NIF__c => throw _privateConstructorUsedError;
  String? get Fase__c => throw _privateConstructorUsedError;
  String get CreatedDate => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SalesforceOpportunityCopyWith<SalesforceOpportunity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SalesforceOpportunityCopyWith<$Res> {
  factory $SalesforceOpportunityCopyWith(SalesforceOpportunity value,
          $Res Function(SalesforceOpportunity) then) =
      _$SalesforceOpportunityCopyWithImpl<$Res, SalesforceOpportunity>;
  @useResult
  $Res call(
      {String Id,
      String Name,
      String? NIF__c,
      String? Fase__c,
      String CreatedDate});
}

/// @nodoc
class _$SalesforceOpportunityCopyWithImpl<$Res,
        $Val extends SalesforceOpportunity>
    implements $SalesforceOpportunityCopyWith<$Res> {
  _$SalesforceOpportunityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? Id = null,
    Object? Name = null,
    Object? NIF__c = freezed,
    Object? Fase__c = freezed,
    Object? CreatedDate = null,
  }) {
    return _then(_value.copyWith(
      Id: null == Id
          ? _value.Id
          : Id // ignore: cast_nullable_to_non_nullable
              as String,
      Name: null == Name
          ? _value.Name
          : Name // ignore: cast_nullable_to_non_nullable
              as String,
      NIF__c: freezed == NIF__c
          ? _value.NIF__c
          : NIF__c // ignore: cast_nullable_to_non_nullable
              as String?,
      Fase__c: freezed == Fase__c
          ? _value.Fase__c
          : Fase__c // ignore: cast_nullable_to_non_nullable
              as String?,
      CreatedDate: null == CreatedDate
          ? _value.CreatedDate
          : CreatedDate // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SalesforceOpportunityImplCopyWith<$Res>
    implements $SalesforceOpportunityCopyWith<$Res> {
  factory _$$SalesforceOpportunityImplCopyWith(
          _$SalesforceOpportunityImpl value,
          $Res Function(_$SalesforceOpportunityImpl) then) =
      __$$SalesforceOpportunityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String Id,
      String Name,
      String? NIF__c,
      String? Fase__c,
      String CreatedDate});
}

/// @nodoc
class __$$SalesforceOpportunityImplCopyWithImpl<$Res>
    extends _$SalesforceOpportunityCopyWithImpl<$Res,
        _$SalesforceOpportunityImpl>
    implements _$$SalesforceOpportunityImplCopyWith<$Res> {
  __$$SalesforceOpportunityImplCopyWithImpl(_$SalesforceOpportunityImpl _value,
      $Res Function(_$SalesforceOpportunityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? Id = null,
    Object? Name = null,
    Object? NIF__c = freezed,
    Object? Fase__c = freezed,
    Object? CreatedDate = null,
  }) {
    return _then(_$SalesforceOpportunityImpl(
      Id: null == Id
          ? _value.Id
          : Id // ignore: cast_nullable_to_non_nullable
              as String,
      Name: null == Name
          ? _value.Name
          : Name // ignore: cast_nullable_to_non_nullable
              as String,
      NIF__c: freezed == NIF__c
          ? _value.NIF__c
          : NIF__c // ignore: cast_nullable_to_non_nullable
              as String?,
      Fase__c: freezed == Fase__c
          ? _value.Fase__c
          : Fase__c // ignore: cast_nullable_to_non_nullable
              as String?,
      CreatedDate: null == CreatedDate
          ? _value.CreatedDate
          : CreatedDate // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SalesforceOpportunityImpl implements _SalesforceOpportunity {
  const _$SalesforceOpportunityImpl(
      {required this.Id,
      required this.Name,
      this.NIF__c,
      this.Fase__c,
      required this.CreatedDate});

  factory _$SalesforceOpportunityImpl.fromJson(Map<String, dynamic> json) =>
      _$$SalesforceOpportunityImplFromJson(json);

  @override
  final String Id;
  @override
  final String Name;
  @override
  final String? NIF__c;
  @override
  final String? Fase__c;
  @override
  final String CreatedDate;

  @override
  String toString() {
    return 'SalesforceOpportunity(Id: $Id, Name: $Name, NIF__c: $NIF__c, Fase__c: $Fase__c, CreatedDate: $CreatedDate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SalesforceOpportunityImpl &&
            (identical(other.Id, Id) || other.Id == Id) &&
            (identical(other.Name, Name) || other.Name == Name) &&
            (identical(other.NIF__c, NIF__c) || other.NIF__c == NIF__c) &&
            (identical(other.Fase__c, Fase__c) || other.Fase__c == Fase__c) &&
            (identical(other.CreatedDate, CreatedDate) ||
                other.CreatedDate == CreatedDate));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, Id, Name, NIF__c, Fase__c, CreatedDate);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SalesforceOpportunityImplCopyWith<_$SalesforceOpportunityImpl>
      get copyWith => __$$SalesforceOpportunityImplCopyWithImpl<
          _$SalesforceOpportunityImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SalesforceOpportunityImplToJson(
      this,
    );
  }
}

abstract class _SalesforceOpportunity implements SalesforceOpportunity {
  const factory _SalesforceOpportunity(
      {required final String Id,
      required final String Name,
      final String? NIF__c,
      final String? Fase__c,
      required final String CreatedDate}) = _$SalesforceOpportunityImpl;

  factory _SalesforceOpportunity.fromJson(Map<String, dynamic> json) =
      _$SalesforceOpportunityImpl.fromJson;

  @override
  String get Id;
  @override
  String get Name;
  @override
  String? get NIF__c;
  @override
  String? get Fase__c;
  @override
  String get CreatedDate;
  @override
  @JsonKey(ignore: true)
  _$$SalesforceOpportunityImplCopyWith<_$SalesforceOpportunityImpl>
      get copyWith => throw _privateConstructorUsedError;
}
