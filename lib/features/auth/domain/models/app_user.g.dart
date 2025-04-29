// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppUser _$AppUserFromJson(Map<String, dynamic> json) => _AppUser(
  uid: json['uid'] as String,
  email: json['email'] as String,
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  displayName: json['displayName'] as String?,
  photoURL: json['photoURL'] as String?,
  salesforceId: json['salesforceId'] as String?,
  isFirstLogin: json['isFirstLogin'] as bool? ?? false,
  isEmailVerified: json['isEmailVerified'] as bool? ?? false,
  additionalData: json['additionalData'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$AppUserToJson(_AppUser instance) => <String, dynamic>{
  'uid': instance.uid,
  'email': instance.email,
  'role': _$UserRoleEnumMap[instance.role]!,
  'displayName': instance.displayName,
  'photoURL': instance.photoURL,
  'salesforceId': instance.salesforceId,
  'isFirstLogin': instance.isFirstLogin,
  'isEmailVerified': instance.isEmailVerified,
  'additionalData': instance.additionalData,
};

const _$UserRoleEnumMap = {
  UserRole.admin: 'admin',
  UserRole.reseller: 'reseller',
  UserRole.unknown: 'unknown',
};
