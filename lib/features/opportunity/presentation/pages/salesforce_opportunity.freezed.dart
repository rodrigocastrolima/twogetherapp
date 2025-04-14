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
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SalesforceOpportunity _$SalesforceOpportunityFromJson(
  Map<String, dynamic> json,
) {
  return _SalesforceOpportunity.fromJson(json);
}

/// @nodoc
mixin _$SalesforceOpportunity {
  String get Id => throw _privateConstructorUsedError;
  String get Name => throw _privateConstructorUsedError;
  String? get AccountId => throw _privateConstructorUsedError;
  AccountInfo? get Account =>
      throw _privateConstructorUsedError; // Nested object for Account details
  String? get Fase__c => throw _privateConstructorUsedError;
  String? get Solu_o__c => throw _privateConstructorUsedError;
  String? get Data_de_Previs_o_de_Fecho__c =>
      throw _privateConstructorUsedError; // Salesforce date (YYYY-MM-DD)
  String get CreatedDate => throw _privateConstructorUsedError;

  /// Serializes this SalesforceOpportunity to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SalesforceOpportunity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SalesforceOpportunityCopyWith<SalesforceOpportunity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SalesforceOpportunityCopyWith<$Res> {
  factory $SalesforceOpportunityCopyWith(
    SalesforceOpportunity value,
    $Res Function(SalesforceOpportunity) then,
  ) = _$SalesforceOpportunityCopyWithImpl<$Res, SalesforceOpportunity>;
  @useResult
  $Res call({
    String Id,
    String Name,
    String? AccountId,
    AccountInfo? Account,
    String? Fase__c,
    String? Solu_o__c,
    String? Data_de_Previs_o_de_Fecho__c,
    String CreatedDate,
  });

  $AccountInfoCopyWith<$Res>? get Account;
}

/// @nodoc
class _$SalesforceOpportunityCopyWithImpl<
  $Res,
  $Val extends SalesforceOpportunity
>
    implements $SalesforceOpportunityCopyWith<$Res> {
  _$SalesforceOpportunityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SalesforceOpportunity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? Id = null,
    Object? Name = null,
    Object? AccountId = freezed,
    Object? Account = freezed,
    Object? Fase__c = freezed,
    Object? Solu_o__c = freezed,
    Object? Data_de_Previs_o_de_Fecho__c = freezed,
    Object? CreatedDate = null,
  }) {
    return _then(
      _value.copyWith(
            Id:
                null == Id
                    ? _value.Id
                    : Id // ignore: cast_nullable_to_non_nullable
                        as String,
            Name:
                null == Name
                    ? _value.Name
                    : Name // ignore: cast_nullable_to_non_nullable
                        as String,
            AccountId:
                freezed == AccountId
                    ? _value.AccountId
                    : AccountId // ignore: cast_nullable_to_non_nullable
                        as String?,
            Account:
                freezed == Account
                    ? _value.Account
                    : Account // ignore: cast_nullable_to_non_nullable
                        as AccountInfo?,
            Fase__c:
                freezed == Fase__c
                    ? _value.Fase__c
                    : Fase__c // ignore: cast_nullable_to_non_nullable
                        as String?,
            Solu_o__c:
                freezed == Solu_o__c
                    ? _value.Solu_o__c
                    : Solu_o__c // ignore: cast_nullable_to_non_nullable
                        as String?,
            Data_de_Previs_o_de_Fecho__c:
                freezed == Data_de_Previs_o_de_Fecho__c
                    ? _value.Data_de_Previs_o_de_Fecho__c
                    : Data_de_Previs_o_de_Fecho__c // ignore: cast_nullable_to_non_nullable
                        as String?,
            CreatedDate:
                null == CreatedDate
                    ? _value.CreatedDate
                    : CreatedDate // ignore: cast_nullable_to_non_nullable
                        as String,
          )
          as $Val,
    );
  }

  /// Create a copy of SalesforceOpportunity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AccountInfoCopyWith<$Res>? get Account {
    if (_value.Account == null) {
      return null;
    }

    return $AccountInfoCopyWith<$Res>(_value.Account!, (value) {
      return _then(_value.copyWith(Account: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SalesforceOpportunityImplCopyWith<$Res>
    implements $SalesforceOpportunityCopyWith<$Res> {
  factory _$$SalesforceOpportunityImplCopyWith(
    _$SalesforceOpportunityImpl value,
    $Res Function(_$SalesforceOpportunityImpl) then,
  ) = __$$SalesforceOpportunityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String Id,
    String Name,
    String? AccountId,
    AccountInfo? Account,
    String? Fase__c,
    String? Solu_o__c,
    String? Data_de_Previs_o_de_Fecho__c,
    String CreatedDate,
  });

  @override
  $AccountInfoCopyWith<$Res>? get Account;
}

/// @nodoc
class __$$SalesforceOpportunityImplCopyWithImpl<$Res>
    extends
        _$SalesforceOpportunityCopyWithImpl<$Res, _$SalesforceOpportunityImpl>
    implements _$$SalesforceOpportunityImplCopyWith<$Res> {
  __$$SalesforceOpportunityImplCopyWithImpl(
    _$SalesforceOpportunityImpl _value,
    $Res Function(_$SalesforceOpportunityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SalesforceOpportunity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? Id = null,
    Object? Name = null,
    Object? AccountId = freezed,
    Object? Account = freezed,
    Object? Fase__c = freezed,
    Object? Solu_o__c = freezed,
    Object? Data_de_Previs_o_de_Fecho__c = freezed,
    Object? CreatedDate = null,
  }) {
    return _then(
      _$SalesforceOpportunityImpl(
        Id:
            null == Id
                ? _value.Id
                : Id // ignore: cast_nullable_to_non_nullable
                    as String,
        Name:
            null == Name
                ? _value.Name
                : Name // ignore: cast_nullable_to_non_nullable
                    as String,
        AccountId:
            freezed == AccountId
                ? _value.AccountId
                : AccountId // ignore: cast_nullable_to_non_nullable
                    as String?,
        Account:
            freezed == Account
                ? _value.Account
                : Account // ignore: cast_nullable_to_non_nullable
                    as AccountInfo?,
        Fase__c:
            freezed == Fase__c
                ? _value.Fase__c
                : Fase__c // ignore: cast_nullable_to_non_nullable
                    as String?,
        Solu_o__c:
            freezed == Solu_o__c
                ? _value.Solu_o__c
                : Solu_o__c // ignore: cast_nullable_to_non_nullable
                    as String?,
        Data_de_Previs_o_de_Fecho__c:
            freezed == Data_de_Previs_o_de_Fecho__c
                ? _value.Data_de_Previs_o_de_Fecho__c
                : Data_de_Previs_o_de_Fecho__c // ignore: cast_nullable_to_non_nullable
                    as String?,
        CreatedDate:
            null == CreatedDate
                ? _value.CreatedDate
                : CreatedDate // ignore: cast_nullable_to_non_nullable
                    as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SalesforceOpportunityImpl implements _SalesforceOpportunity {
  const _$SalesforceOpportunityImpl({
    required this.Id,
    required this.Name,
    this.AccountId,
    this.Account,
    this.Fase__c,
    this.Solu_o__c,
    this.Data_de_Previs_o_de_Fecho__c,
    required this.CreatedDate,
  });

  factory _$SalesforceOpportunityImpl.fromJson(Map<String, dynamic> json) =>
      _$$SalesforceOpportunityImplFromJson(json);

  @override
  final String Id;
  @override
  final String Name;
  @override
  final String? AccountId;
  @override
  final AccountInfo? Account;
  // Nested object for Account details
  @override
  final String? Fase__c;
  @override
  final String? Solu_o__c;
  @override
  final String? Data_de_Previs_o_de_Fecho__c;
  // Salesforce date (YYYY-MM-DD)
  @override
  final String CreatedDate;

  @override
  String toString() {
    return 'SalesforceOpportunity(Id: $Id, Name: $Name, AccountId: $AccountId, Account: $Account, Fase__c: $Fase__c, Solu_o__c: $Solu_o__c, Data_de_Previs_o_de_Fecho__c: $Data_de_Previs_o_de_Fecho__c, CreatedDate: $CreatedDate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SalesforceOpportunityImpl &&
            (identical(other.Id, Id) || other.Id == Id) &&
            (identical(other.Name, Name) || other.Name == Name) &&
            (identical(other.AccountId, AccountId) ||
                other.AccountId == AccountId) &&
            (identical(other.Account, Account) || other.Account == Account) &&
            (identical(other.Fase__c, Fase__c) || other.Fase__c == Fase__c) &&
            (identical(other.Solu_o__c, Solu_o__c) ||
                other.Solu_o__c == Solu_o__c) &&
            (identical(
                  other.Data_de_Previs_o_de_Fecho__c,
                  Data_de_Previs_o_de_Fecho__c,
                ) ||
                other.Data_de_Previs_o_de_Fecho__c ==
                    Data_de_Previs_o_de_Fecho__c) &&
            (identical(other.CreatedDate, CreatedDate) ||
                other.CreatedDate == CreatedDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    Id,
    Name,
    AccountId,
    Account,
    Fase__c,
    Solu_o__c,
    Data_de_Previs_o_de_Fecho__c,
    CreatedDate,
  );

  /// Create a copy of SalesforceOpportunity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SalesforceOpportunityImplCopyWith<_$SalesforceOpportunityImpl>
  get copyWith =>
      __$$SalesforceOpportunityImplCopyWithImpl<_$SalesforceOpportunityImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SalesforceOpportunityImplToJson(this);
  }
}

abstract class _SalesforceOpportunity implements SalesforceOpportunity {
  const factory _SalesforceOpportunity({
    required final String Id,
    required final String Name,
    final String? AccountId,
    final AccountInfo? Account,
    final String? Fase__c,
    final String? Solu_o__c,
    final String? Data_de_Previs_o_de_Fecho__c,
    required final String CreatedDate,
  }) = _$SalesforceOpportunityImpl;

  factory _SalesforceOpportunity.fromJson(Map<String, dynamic> json) =
      _$SalesforceOpportunityImpl.fromJson;

  @override
  String get Id;
  @override
  String get Name;
  @override
  String? get AccountId;
  @override
  AccountInfo? get Account; // Nested object for Account details
  @override
  String? get Fase__c;
  @override
  String? get Solu_o__c;
  @override
  String? get Data_de_Previs_o_de_Fecho__c; // Salesforce date (YYYY-MM-DD)
  @override
  String get CreatedDate;

  /// Create a copy of SalesforceOpportunity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SalesforceOpportunityImplCopyWith<_$SalesforceOpportunityImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AccountInfo _$AccountInfoFromJson(Map<String, dynamic> json) {
  return _AccountInfo.fromJson(json);
}

/// @nodoc
mixin _$AccountInfo {
  String? get Name => throw _privateConstructorUsedError;

  /// Serializes this AccountInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AccountInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AccountInfoCopyWith<AccountInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AccountInfoCopyWith<$Res> {
  factory $AccountInfoCopyWith(
    AccountInfo value,
    $Res Function(AccountInfo) then,
  ) = _$AccountInfoCopyWithImpl<$Res, AccountInfo>;
  @useResult
  $Res call({String? Name});
}

/// @nodoc
class _$AccountInfoCopyWithImpl<$Res, $Val extends AccountInfo>
    implements $AccountInfoCopyWith<$Res> {
  _$AccountInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AccountInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? Name = freezed}) {
    return _then(
      _value.copyWith(
            Name:
                freezed == Name
                    ? _value.Name
                    : Name // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AccountInfoImplCopyWith<$Res>
    implements $AccountInfoCopyWith<$Res> {
  factory _$$AccountInfoImplCopyWith(
    _$AccountInfoImpl value,
    $Res Function(_$AccountInfoImpl) then,
  ) = __$$AccountInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? Name});
}

/// @nodoc
class __$$AccountInfoImplCopyWithImpl<$Res>
    extends _$AccountInfoCopyWithImpl<$Res, _$AccountInfoImpl>
    implements _$$AccountInfoImplCopyWith<$Res> {
  __$$AccountInfoImplCopyWithImpl(
    _$AccountInfoImpl _value,
    $Res Function(_$AccountInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AccountInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? Name = freezed}) {
    return _then(
      _$AccountInfoImpl(
        Name:
            freezed == Name
                ? _value.Name
                : Name // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AccountInfoImpl implements _AccountInfo {
  const _$AccountInfoImpl({this.Name});

  factory _$AccountInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AccountInfoImplFromJson(json);

  @override
  final String? Name;

  @override
  String toString() {
    return 'AccountInfo(Name: $Name)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AccountInfoImpl &&
            (identical(other.Name, Name) || other.Name == Name));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, Name);

  /// Create a copy of AccountInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AccountInfoImplCopyWith<_$AccountInfoImpl> get copyWith =>
      __$$AccountInfoImplCopyWithImpl<_$AccountInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AccountInfoImplToJson(this);
  }
}

abstract class _AccountInfo implements AccountInfo {
  const factory _AccountInfo({final String? Name}) = _$AccountInfoImpl;

  factory _AccountInfo.fromJson(Map<String, dynamic> json) =
      _$AccountInfoImpl.fromJson;

  @override
  String? get Name;

  /// Create a copy of AccountInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AccountInfoImplCopyWith<_$AccountInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
