// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Profile _$ProfileFromJson(Map<String, dynamic> json) => _Profile(
  name: json['name'] as String,
  email: json['email'] as String,
  phone: json['phone'] as String,
  registrationDate: DateTime.parse(json['registrationDate'] as String),
  totalClients: (json['totalClients'] as num).toInt(),
  activeClients: (json['activeClients'] as num).toInt(),
);

Map<String, dynamic> _$ProfileToJson(_Profile instance) => <String, dynamic>{
  'name': instance.name,
  'email': instance.email,
  'phone': instance.phone,
  'registrationDate': instance.registrationDate.toIso8601String(),
  'totalClients': instance.totalClients,
  'activeClients': instance.activeClients,
};

_Revenue _$RevenueFromJson(Map<String, dynamic> json) => _Revenue(
  cycle: json['cycle'] as String,
  type: json['type'] as String,
  cep: json['cep'] as String,
  amount: (json['amount'] as num).toDouble(),
  clientName: json['clientName'] as String,
);

Map<String, dynamic> _$RevenueToJson(_Revenue instance) => <String, dynamic>{
  'cycle': instance.cycle,
  'type': instance.type,
  'cep': instance.cep,
  'amount': instance.amount,
  'clientName': instance.clientName,
};
