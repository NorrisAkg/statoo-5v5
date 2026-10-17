import 'package:flutter_test/flutter_test.dart';
import 'package:statoo/features/shared/domain/registration_members.dart';

void main() {
  test('ENT11 copy roster IDs remain stable, separate and preserve source', () {
    final source = [
      {'id': 'alice', 'team_id': 'local', 'name': 'Alice', 'is_active': 1},
    ];
    final copied = registrationMembers('local', source);
    expect(copied.single['id'], isNot('alice'));
    expect(copied.single.containsKey('team_id'), false);
    expect(copied.single['name'], 'Alice');
    expect(registrationMembers('local', source), copied);
    expect(
      registrationMembers('another', source).single['id'],
      isNot(copied.single['id']),
    );
    expect(source.single['id'], 'alice');
    expect(source.single['team_id'], 'local');
    expect(registrationMembers('local', []), isEmpty);
  });
  test('ENT11 malformed member cannot produce a silent shared collision', () {
    expect(
      () => registrationMembers('local', [
        {'name': 'Invalid'},
      ]),
      throwsFormatException,
    );
  });
}
