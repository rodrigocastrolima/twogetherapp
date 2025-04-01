// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ClientImpl _$$ClientImplFromJson(Map<String, dynamic> json) => _$ClientImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
  phone: json['phone'] as String,
  address: json['address'] as String,
  status: $enumDecode(_$ClientStatusEnumMap, json['status']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$$ClientImplToJson(_$ClientImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'phone': instance.phone,
      'address': instance.address,
      'status': _$ClientStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'notes': instance.notes,
    };

const _$ClientStatusEnumMap = {
  ClientStatus.active: 'active',
  ClientStatus.inactive: 'inactive',
  ClientStatus.pending: 'pending',
  ClientStatus.archived: 'archived',
};
