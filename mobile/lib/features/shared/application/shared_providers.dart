import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/app_database.dart';
import '../../team/application/team_provider.dart';
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

final Provider<bool> Function(String) canWriteProvider =
    Provider.family<bool, String>((ref, domain) {
      ref.watch(sharedStatusProvider);
      return ref
          .watch(sharedServiceProvider)
          .canWrite(ref.watch(activeTeamIdProvider), domain);
    });

/// La propriété d'une séance est relue en base, en plus du rôle de l'identité.
/// Pendant cette lecture l'interface reste en consultation.
final FutureProvider<bool> Function(({String domain, String sessionId}))
canWriteSessionProvider =
    FutureProvider.family<bool, ({String domain, String sessionId})>((
      ref,
      target,
    ) async {
      ref.watch(sharedStatusProvider);
      final group = ref.watch(activeTeamIdProvider);
      final service = ref.watch(sharedServiceProvider);
      if (!service.canWrite(group, target.domain) || group == null)
        return false;
      if (!service.connected || group != service.groupId) return true;
      try {
        await service.requireWrite(
          group,
          target.domain,
          sessionId: target.sessionId,
        );
        return true;
      } on Object {
        return false;
      }
    });
