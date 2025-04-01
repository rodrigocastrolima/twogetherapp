import 'package:freezed_annotation/freezed_annotation.dart';

part 'client.freezed.dart';
part 'client.g.dart';

@freezed
class Client with _$Client {
  const factory Client({
    required String id,
    required String name,
    required String email,
    required String phone,
    required String address,
    required ClientStatus status,
    required DateTime createdAt,
    String? notes,
  }) = _Client;

  factory Client.fromJson(Map<String, dynamic> json) => _$ClientFromJson(json);
}

enum ClientStatus { active, inactive, pending, archived }
