// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppUser {

 String get uid; String get email; UserRole get role; String? get displayName; String? get photoURL; String? get salesforceId; bool get isFirstLogin; bool get isEmailVerified; Map<String, dynamic> get additionalData;
/// Create a copy of AppUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppUserCopyWith<AppUser> get copyWith => _$AppUserCopyWithImpl<AppUser>(this as AppUser, _$identity);

  /// Serializes this AppUser to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppUser&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.email, email) || other.email == email)&&(identical(other.role, role) || other.role == role)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.photoURL, photoURL) || other.photoURL == photoURL)&&(identical(other.salesforceId, salesforceId) || other.salesforceId == salesforceId)&&(identical(other.isFirstLogin, isFirstLogin) || other.isFirstLogin == isFirstLogin)&&(identical(other.isEmailVerified, isEmailVerified) || other.isEmailVerified == isEmailVerified)&&const DeepCollectionEquality().equals(other.additionalData, additionalData));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uid,email,role,displayName,photoURL,salesforceId,isFirstLogin,isEmailVerified,const DeepCollectionEquality().hash(additionalData));

@override
String toString() {
  return 'AppUser(uid: $uid, email: $email, role: $role, displayName: $displayName, photoURL: $photoURL, salesforceId: $salesforceId, isFirstLogin: $isFirstLogin, isEmailVerified: $isEmailVerified, additionalData: $additionalData)';
}


}

/// @nodoc
abstract mixin class $AppUserCopyWith<$Res>  {
  factory $AppUserCopyWith(AppUser value, $Res Function(AppUser) _then) = _$AppUserCopyWithImpl;
@useResult
$Res call({
 String uid, String email, UserRole role, String? displayName, String? photoURL, String? salesforceId, bool isFirstLogin, bool isEmailVerified, Map<String, dynamic> additionalData
});




}
/// @nodoc
class _$AppUserCopyWithImpl<$Res>
    implements $AppUserCopyWith<$Res> {
  _$AppUserCopyWithImpl(this._self, this._then);

  final AppUser _self;
  final $Res Function(AppUser) _then;

/// Create a copy of AppUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? email = null,Object? role = null,Object? displayName = freezed,Object? photoURL = freezed,Object? salesforceId = freezed,Object? isFirstLogin = null,Object? isEmailVerified = null,Object? additionalData = null,}) {
  return _then(_self.copyWith(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,photoURL: freezed == photoURL ? _self.photoURL : photoURL // ignore: cast_nullable_to_non_nullable
as String?,salesforceId: freezed == salesforceId ? _self.salesforceId : salesforceId // ignore: cast_nullable_to_non_nullable
as String?,isFirstLogin: null == isFirstLogin ? _self.isFirstLogin : isFirstLogin // ignore: cast_nullable_to_non_nullable
as bool,isEmailVerified: null == isEmailVerified ? _self.isEmailVerified : isEmailVerified // ignore: cast_nullable_to_non_nullable
as bool,additionalData: null == additionalData ? _self.additionalData : additionalData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _AppUser implements AppUser {
  const _AppUser({required this.uid, required this.email, required this.role, this.displayName, this.photoURL, this.salesforceId, this.isFirstLogin = false, this.isEmailVerified = false, final  Map<String, dynamic> additionalData = const {}}): _additionalData = additionalData;
  factory _AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);

@override final  String uid;
@override final  String email;
@override final  UserRole role;
@override final  String? displayName;
@override final  String? photoURL;
@override final  String? salesforceId;
@override@JsonKey() final  bool isFirstLogin;
@override@JsonKey() final  bool isEmailVerified;
 final  Map<String, dynamic> _additionalData;
@override@JsonKey() Map<String, dynamic> get additionalData {
  if (_additionalData is EqualUnmodifiableMapView) return _additionalData;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_additionalData);
}


/// Create a copy of AppUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppUserCopyWith<_AppUser> get copyWith => __$AppUserCopyWithImpl<_AppUser>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppUserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppUser&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.email, email) || other.email == email)&&(identical(other.role, role) || other.role == role)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.photoURL, photoURL) || other.photoURL == photoURL)&&(identical(other.salesforceId, salesforceId) || other.salesforceId == salesforceId)&&(identical(other.isFirstLogin, isFirstLogin) || other.isFirstLogin == isFirstLogin)&&(identical(other.isEmailVerified, isEmailVerified) || other.isEmailVerified == isEmailVerified)&&const DeepCollectionEquality().equals(other._additionalData, _additionalData));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uid,email,role,displayName,photoURL,salesforceId,isFirstLogin,isEmailVerified,const DeepCollectionEquality().hash(_additionalData));

@override
String toString() {
  return 'AppUser(uid: $uid, email: $email, role: $role, displayName: $displayName, photoURL: $photoURL, salesforceId: $salesforceId, isFirstLogin: $isFirstLogin, isEmailVerified: $isEmailVerified, additionalData: $additionalData)';
}


}

/// @nodoc
abstract mixin class _$AppUserCopyWith<$Res> implements $AppUserCopyWith<$Res> {
  factory _$AppUserCopyWith(_AppUser value, $Res Function(_AppUser) _then) = __$AppUserCopyWithImpl;
@override @useResult
$Res call({
 String uid, String email, UserRole role, String? displayName, String? photoURL, String? salesforceId, bool isFirstLogin, bool isEmailVerified, Map<String, dynamic> additionalData
});




}
/// @nodoc
class __$AppUserCopyWithImpl<$Res>
    implements _$AppUserCopyWith<$Res> {
  __$AppUserCopyWithImpl(this._self, this._then);

  final _AppUser _self;
  final $Res Function(_AppUser) _then;

/// Create a copy of AppUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? email = null,Object? role = null,Object? displayName = freezed,Object? photoURL = freezed,Object? salesforceId = freezed,Object? isFirstLogin = null,Object? isEmailVerified = null,Object? additionalData = null,}) {
  return _then(_AppUser(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,photoURL: freezed == photoURL ? _self.photoURL : photoURL // ignore: cast_nullable_to_non_nullable
as String?,salesforceId: freezed == salesforceId ? _self.salesforceId : salesforceId // ignore: cast_nullable_to_non_nullable
as String?,isFirstLogin: null == isFirstLogin ? _self.isFirstLogin : isFirstLogin // ignore: cast_nullable_to_non_nullable
as bool,isEmailVerified: null == isEmailVerified ? _self.isEmailVerified : isEmailVerified // ignore: cast_nullable_to_non_nullable
as bool,additionalData: null == additionalData ? _self._additionalData : additionalData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
