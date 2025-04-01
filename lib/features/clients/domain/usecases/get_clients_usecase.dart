import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/error/failures.dart';
import '../entities/client.dart';
import '../repositories/client_repository.dart';

class GetClientsUseCase implements UseCase<List<Client>, NoParams> {
  final ClientRepository repository;

  GetClientsUseCase(this.repository);

  @override
  Future<Result<List<Client>>> call(NoParams params) async {
    try {
      final clients = await repository.getClients();
      return Success(clients);
    } on Exception catch (e) {
      return Result.fromException(e);
    } catch (e) {
      return Error<List<Client>>(UnknownFailure(e.toString()));
    }
  }
}
