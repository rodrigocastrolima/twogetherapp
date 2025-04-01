import 'package:equatable/equatable.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/error/failures.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class GetRevenueParams extends Equatable {
  final String cycle;
  final String? customerType;
  final String? cep;

  const GetRevenueParams({required this.cycle, this.customerType, this.cep});

  @override
  List<Object?> get props => [cycle, customerType, cep];
}

class GetRevenueUseCase implements UseCase<List<Revenue>, GetRevenueParams> {
  final ProfileRepository repository;

  GetRevenueUseCase(this.repository);

  @override
  Future<Result<List<Revenue>>> call(GetRevenueParams params) async {
    try {
      final revenue = await repository.getRevenue(
        params.cycle,
        params.customerType,
        params.cep,
      );
      return Success(revenue);
    } on Exception catch (e) {
      return Result.fromException(e);
    } catch (e) {
      return Error<List<Revenue>>(UnknownFailure(e.toString()));
    }
  }
}
