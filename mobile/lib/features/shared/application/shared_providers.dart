import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_database.dart';
import '../data/shared_service.dart';

final sharedServiceProvider = Provider<SharedService>((ref) {
  final service = SharedService(AppDatabase.instance);
  return service;
});

/// Manual notifier to refresh permissions and cached remote views after sync.
class SharedRevision extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}

final sharedStatusProvider = NotifierProvider<SharedRevision, int>(
  SharedRevision.new,
);
