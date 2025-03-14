import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../data/repositories/profile_repository_impl.dart';

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<Profile>>((ref) {
      return ProfileController(ref.watch(profileRepositoryProvider));
    });

final revenueControllerProvider =
    StateNotifierProvider<RevenueController, AsyncValue<List<Revenue>>>((ref) {
      return RevenueController(ref.watch(profileRepositoryProvider));
    });

class ProfileController extends StateNotifier<AsyncValue<Profile>> {
  final ProfileRepository _repository;

  ProfileController(this._repository) : super(const AsyncValue.loading()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _repository.getProfile();
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

class RevenueController extends StateNotifier<AsyncValue<List<Revenue>>> {
  final ProfileRepository _repository;
  String _currentCycle = 'Cycle 1';
  String? _customerType;
  String? _cep;

  RevenueController(this._repository) : super(const AsyncValue.loading()) {
    loadRevenue();
  }

  Future<void> loadRevenue() async {
    state = const AsyncValue.loading();
    try {
      final revenue = await _repository.getRevenue(
        _currentCycle,
        _customerType,
        _cep,
      );
      state = AsyncValue.data(revenue);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void updateFilters({String? cycle, String? customerType, String? cep}) {
    if (cycle != null) _currentCycle = cycle;
    if (customerType != null) _customerType = customerType;
    if (cep != null) _cep = cep;
    loadRevenue();
  }
}
