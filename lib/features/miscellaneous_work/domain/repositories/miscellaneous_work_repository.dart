import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work.dart';

/// Contract for the miscellaneous-work data source. The concrete impl
/// (`MiscellaneousWorkRepositoryImpl`) handles wire-DTO ↔ domain
/// mapping and — once the backend lands — drift persistence + outbox
/// enqueue. Tests substitute fakes via the Riverpod override.
abstract class MiscellaneousWorkRepository {
  Future<List<MiscellaneousWork>> getAll();

  Future<MiscellaneousWork> addWork(MiscellaneousWork draft);

  Future<MiscellaneousWork> updateWork(MiscellaneousWork work);
}
