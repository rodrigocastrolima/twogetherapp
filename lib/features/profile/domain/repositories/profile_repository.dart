import '../entities/profile.dart';

abstract class ProfileRepository {
  Future<Profile> getProfile();
  Future<List<Revenue>> getRevenue(
    String cycle,
    String? customerType,
    String? cep,
  );
}
