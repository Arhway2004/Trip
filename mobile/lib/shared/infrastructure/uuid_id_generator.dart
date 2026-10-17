import 'package:uuid/uuid.dart';
import 'package:wanderplan/shared/domain/id_generator.dart';

class UuidIdGenerator implements IdGenerator {
  const UuidIdGenerator();
  static const _uuid = Uuid();

  @override
  String newId() => _uuid.v4();
}
