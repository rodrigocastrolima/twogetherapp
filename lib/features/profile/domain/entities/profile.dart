import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String name,
    required String email,
    required String phone,
    required DateTime registrationDate,
    required int totalClients,
    required int activeClients,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}

@freezed
class Revenue with _$Revenue {
  const factory Revenue({
    required String cycle,
    required String type,
    required String cep,
    required double amount,
    required String clientName,
  }) = _Revenue;

  factory Revenue.fromJson(Map<String, dynamic> json) =>
      _$RevenueFromJson(json);
}
