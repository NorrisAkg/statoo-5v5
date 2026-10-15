import 'package:statoo/core/data/app_database.dart';
import 'package:statoo/features/shared/data/shared_service.dart';

/// Dépendance explicite des tests de coordination avec faux repositories.
/// Ne pas l'utiliser pour tester les droits : ces tests utilisent SharedService
/// réel avec SQLite en mémoire (write_capabilities_test/shared_service_test).
class LocalTestSharedService extends SharedService {
  LocalTestSharedService() : super(AppDatabase.instance);
  @override
  Future<void> requireWrite(
    String group,
    String domain, {
    String? sessionId,
  }) async {}
}
