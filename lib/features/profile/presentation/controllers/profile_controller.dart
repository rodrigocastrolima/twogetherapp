import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/profile.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/get_revenue_usecase.dart';
import '../../../../core/usecase/usecase.dart';

// Providers for use cases
final getProfileUseCaseProvider = Provider<GetProfileUseCase>((ref) {
  return GetProfileUseCase(ref.watch(profileRepositoryProvider));
});

final getRevenueUseCaseProvider = Provider<GetRevenueUseCase>((ref) {
  return GetRevenueUseCase(ref.watch(profileRepositoryProvider));
});

// Providers for controllers
final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<Profile>>((ref) {
      return ProfileController(ref.watch(getProfileUseCaseProvider));
    });

// Using .autoDispose to free up memory when the provider is no longer in use
final revenueControllerProvider = StateNotifierProvider.autoDispose<
  RevenueController,
  AsyncValue<List<Revenue>>
>((ref) {
  // Keep alive if users navigate away temporarily
  final link = ref.keepAlive();

  // Cancel the auto dispose with a timeout
  ref.onDispose(() {
    // This would close the controller after a certain time
    Future.delayed(const Duration(minutes: 5), () {
      link.close();
    });
  });

  return RevenueController(ref.watch(getRevenueUseCaseProvider));
});

class ProfileController extends StateNotifier<AsyncValue<Profile>> {
  final GetProfileUseCase _getProfileUseCase;
  // Cache the last loaded profile
  Profile? _cachedProfile;

  ProfileController(this._getProfileUseCase)
    : super(const AsyncValue.loading()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    // Don't show loading state if we have cached data
    if (_cachedProfile == null) {
      state = const AsyncValue.loading();
    }

    try {
      final result = await _getProfileUseCase(const NoParams());
      result.fold((profile) {
        _cachedProfile = profile; // Cache the profile
        state = AsyncValue.data(profile);
      }, (failure) => state = AsyncValue.error(failure, StackTrace.current));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

class RevenueController extends StateNotifier<AsyncValue<List<Revenue>>> {
  final GetRevenueUseCase _getRevenueUseCase;
  String _currentCycle = 'Cycle 1';
  String? _customerType;
  String? _cep;

  // Cache results for different filter combinations
  final Map<String, List<Revenue>> _cachedResults = {};

  RevenueController(this._getRevenueUseCase)
    : super(const AsyncValue.loading()) {
    loadRevenue();
  }

  String get _cacheKey =>
      '$_currentCycle-${_customerType ?? "all"}-${_cep ?? "all"}';

  Future<void> loadRevenue() async {
    // Check if we have cached results for this filter combination
    final cacheKey = _cacheKey;
    if (_cachedResults.containsKey(cacheKey)) {
      state = AsyncValue.data(_cachedResults[cacheKey]!);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final params = GetRevenueParams(
        cycle: _currentCycle,
        customerType: _customerType,
        cep: _cep,
      );

      final result = await _getRevenueUseCase(params);
      result.fold((revenue) {
        // Cache the results
        _cachedResults[cacheKey] = revenue;
        state = AsyncValue.data(revenue);
      }, (failure) => state = AsyncValue.error(failure, StackTrace.current));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void updateFilters({String? cycle, String? customerType, String? cep}) {
    bool shouldReload = false;

    if (cycle != null && cycle != _currentCycle) {
      _currentCycle = cycle;
      shouldReload = true;
    }

    if (customerType != null && customerType != _customerType) {
      _customerType = customerType;
      shouldReload = true;
    }

    if (cep != null && cep != _cep) {
      _cep = cep;
      shouldReload = true;
    }

    if (shouldReload) {
      loadRevenue();
    }
  }

  @override
  void dispose() {
    _cachedResults.clear();
    super.dispose();
  }
}
