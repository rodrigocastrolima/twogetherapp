import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl();
});

class ProfileRepositoryImpl implements ProfileRepository {
  @override
  Future<Profile> getProfile() async {
    // TODO: Implement actual API call
    return Profile(
      name: 'John Doe',
      email: 'john@example.com',
      phone: '+1 234 567 890',
      registrationDate: DateTime(2024, 1, 1),
      totalClients: 10,
      activeClients: 8,
    );
  }

  @override
  Future<List<Revenue>> getRevenue(
    String cycle,
    String? customerType,
    String? cep,
  ) async {
    // TODO: Implement actual API call
    return [
      Revenue(
        cycle: 'Cycle 1',
        type: 'Type A',
        cep: '12345-678',
        amount: 1000.0,
        clientName: 'Client A',
      ),
      Revenue(
        cycle: 'Cycle 1',
        type: 'Type B',
        cep: '87654-321',
        amount: 2000.0,
        clientName: 'Client B',
      ),
    ];
  }
}
