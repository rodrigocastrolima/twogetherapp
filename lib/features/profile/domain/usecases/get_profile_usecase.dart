import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/error/failures.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class GetProfileUseCase implements UseCase<Profile, NoParams> {
  final ProfileRepository repository;

  GetProfileUseCase(this.repository);

  @override
  Future<Result<Profile>> call(NoParams params) async {
    try {
      final profile = await repository.getProfile();
      return Success(profile);
    } on Exception catch (e) {
      return Result.fromException(e);
    } catch (e) {
      return Error<Profile>(UnknownFailure(e.toString()));
    }
  }
}
