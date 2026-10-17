import 'package:wanderplan/shared/application/unit_of_work.dart';
import 'package:wanderplan/shared/infrastructure/database/app_database.dart';

class DriftUnitOfWork implements UnitOfWork {
  const DriftUnitOfWork(this._db);
  final AppDatabase _db;

  @override
  Future<T> run<T>(Future<T> Function() work) => _db.transaction(work);
}
