// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProfileImpl _$$ProfileImplFromJson(Map<String, dynamic> json) =>
    _$ProfileImpl(
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      registrationDate: DateTime.parse(json['registrationDate'] as String),
      totalClients: json['totalClients'] as int,
      activeClients: json['activeClients'] as int,
    );

Map<String, dynamic> _$$ProfileImplToJson(_$ProfileImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'phone': instance.phone,
      'registrationDate': instance.registrationDate.toIso8601String(),
      'totalClients': instance.totalClients,
      'activeClients': instance.activeClients,
    };

_$RevenueImpl _$$RevenueImplFromJson(Map<String, dynamic> json) =>
    _$RevenueImpl(
      cycle: json['cycle'] as String,
      type: json['type'] as String,
      cep: json['cep'] as String,
      amount: (json['amount'] as num).toDouble(),
      clientName: json['clientName'] as String,
    );

Map<String, dynamic> _$$RevenueImplToJson(_$RevenueImpl instance) =>
    <String, dynamic>{
      'cycle': instance.cycle,
      'type': instance.type,
      'cep': instance.cep,
      'amount': instance.amount,
      'clientName': instance.clientName,
    };
