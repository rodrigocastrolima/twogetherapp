// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Profile {

 String get name; String get email; String get phone; DateTime get registrationDate; int get totalClients; int get activeClients;
/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileCopyWith<Profile> get copyWith => _$ProfileCopyWithImpl<Profile>(this as Profile, _$identity);

  /// Serializes this Profile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Profile&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.registrationDate, registrationDate) || other.registrationDate == registrationDate)&&(identical(other.totalClients, totalClients) || other.totalClients == totalClients)&&(identical(other.activeClients, activeClients) || other.activeClients == activeClients));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,email,phone,registrationDate,totalClients,activeClients);

@override
String toString() {
  return 'Profile(name: $name, email: $email, phone: $phone, registrationDate: $registrationDate, totalClients: $totalClients, activeClients: $activeClients)';
}


}

/// @nodoc
abstract mixin class $ProfileCopyWith<$Res>  {
  factory $ProfileCopyWith(Profile value, $Res Function(Profile) _then) = _$ProfileCopyWithImpl;
@useResult
$Res call({
 String name, String email, String phone, DateTime registrationDate, int totalClients, int activeClients
});




}
/// @nodoc
class _$ProfileCopyWithImpl<$Res>
    implements $ProfileCopyWith<$Res> {
  _$ProfileCopyWithImpl(this._self, this._then);

  final Profile _self;
  final $Res Function(Profile) _then;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? email = null,Object? phone = null,Object? registrationDate = null,Object? totalClients = null,Object? activeClients = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,registrationDate: null == registrationDate ? _self.registrationDate : registrationDate // ignore: cast_nullable_to_non_nullable
as DateTime,totalClients: null == totalClients ? _self.totalClients : totalClients // ignore: cast_nullable_to_non_nullable
as int,activeClients: null == activeClients ? _self.activeClients : activeClients // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _Profile implements Profile {
  const _Profile({required this.name, required this.email, required this.phone, required this.registrationDate, required this.totalClients, required this.activeClients});
  factory _Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);

@override final  String name;
@override final  String email;
@override final  String phone;
@override final  DateTime registrationDate;
@override final  int totalClients;
@override final  int activeClients;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileCopyWith<_Profile> get copyWith => __$ProfileCopyWithImpl<_Profile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Profile&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.registrationDate, registrationDate) || other.registrationDate == registrationDate)&&(identical(other.totalClients, totalClients) || other.totalClients == totalClients)&&(identical(other.activeClients, activeClients) || other.activeClients == activeClients));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,email,phone,registrationDate,totalClients,activeClients);

@override
String toString() {
  return 'Profile(name: $name, email: $email, phone: $phone, registrationDate: $registrationDate, totalClients: $totalClients, activeClients: $activeClients)';
}


}

/// @nodoc
abstract mixin class _$ProfileCopyWith<$Res> implements $ProfileCopyWith<$Res> {
  factory _$ProfileCopyWith(_Profile value, $Res Function(_Profile) _then) = __$ProfileCopyWithImpl;
@override @useResult
$Res call({
 String name, String email, String phone, DateTime registrationDate, int totalClients, int activeClients
});




}
/// @nodoc
class __$ProfileCopyWithImpl<$Res>
    implements _$ProfileCopyWith<$Res> {
  __$ProfileCopyWithImpl(this._self, this._then);

  final _Profile _self;
  final $Res Function(_Profile) _then;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? email = null,Object? phone = null,Object? registrationDate = null,Object? totalClients = null,Object? activeClients = null,}) {
  return _then(_Profile(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,registrationDate: null == registrationDate ? _self.registrationDate : registrationDate // ignore: cast_nullable_to_non_nullable
as DateTime,totalClients: null == totalClients ? _self.totalClients : totalClients // ignore: cast_nullable_to_non_nullable
as int,activeClients: null == activeClients ? _self.activeClients : activeClients // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Revenue {

 String get cycle; String get type; String get cep; double get amount; String get clientName;
/// Create a copy of Revenue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RevenueCopyWith<Revenue> get copyWith => _$RevenueCopyWithImpl<Revenue>(this as Revenue, _$identity);

  /// Serializes this Revenue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Revenue&&(identical(other.cycle, cycle) || other.cycle == cycle)&&(identical(other.type, type) || other.type == type)&&(identical(other.cep, cep) || other.cep == cep)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.clientName, clientName) || other.clientName == clientName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cycle,type,cep,amount,clientName);

@override
String toString() {
  return 'Revenue(cycle: $cycle, type: $type, cep: $cep, amount: $amount, clientName: $clientName)';
}


}

/// @nodoc
abstract mixin class $RevenueCopyWith<$Res>  {
  factory $RevenueCopyWith(Revenue value, $Res Function(Revenue) _then) = _$RevenueCopyWithImpl;
@useResult
$Res call({
 String cycle, String type, String cep, double amount, String clientName
});




}
/// @nodoc
class _$RevenueCopyWithImpl<$Res>
    implements $RevenueCopyWith<$Res> {
  _$RevenueCopyWithImpl(this._self, this._then);

  final Revenue _self;
  final $Res Function(Revenue) _then;

/// Create a copy of Revenue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cycle = null,Object? type = null,Object? cep = null,Object? amount = null,Object? clientName = null,}) {
  return _then(_self.copyWith(
cycle: null == cycle ? _self.cycle : cycle // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,cep: null == cep ? _self.cep : cep // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,clientName: null == clientName ? _self.clientName : clientName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _Revenue implements Revenue {
  const _Revenue({required this.cycle, required this.type, required this.cep, required this.amount, required this.clientName});
  factory _Revenue.fromJson(Map<String, dynamic> json) => _$RevenueFromJson(json);

@override final  String cycle;
@override final  String type;
@override final  String cep;
@override final  double amount;
@override final  String clientName;

/// Create a copy of Revenue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RevenueCopyWith<_Revenue> get copyWith => __$RevenueCopyWithImpl<_Revenue>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RevenueToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Revenue&&(identical(other.cycle, cycle) || other.cycle == cycle)&&(identical(other.type, type) || other.type == type)&&(identical(other.cep, cep) || other.cep == cep)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.clientName, clientName) || other.clientName == clientName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cycle,type,cep,amount,clientName);

@override
String toString() {
  return 'Revenue(cycle: $cycle, type: $type, cep: $cep, amount: $amount, clientName: $clientName)';
}


}

/// @nodoc
abstract mixin class _$RevenueCopyWith<$Res> implements $RevenueCopyWith<$Res> {
  factory _$RevenueCopyWith(_Revenue value, $Res Function(_Revenue) _then) = __$RevenueCopyWithImpl;
@override @useResult
$Res call({
 String cycle, String type, String cep, double amount, String clientName
});




}
/// @nodoc
class __$RevenueCopyWithImpl<$Res>
    implements _$RevenueCopyWith<$Res> {
  __$RevenueCopyWithImpl(this._self, this._then);

  final _Revenue _self;
  final $Res Function(_Revenue) _then;

/// Create a copy of Revenue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cycle = null,Object? type = null,Object? cep = null,Object? amount = null,Object? clientName = null,}) {
  return _then(_Revenue(
cycle: null == cycle ? _self.cycle : cycle // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,cep: null == cep ? _self.cep : cep // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,clientName: null == clientName ? _self.clientName : clientName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
