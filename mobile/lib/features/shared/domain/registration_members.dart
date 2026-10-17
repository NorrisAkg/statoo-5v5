/// Copy roster identity into a separate namespace, leaving local history intact.
/// Length-prefixed group names avoid ambiguity when IDs contain separators.
List<Map<String, dynamic>> registrationMembers(
  String sourceGroup,
  Iterable<Map<String, dynamic>> members,
) => [for (final member in members) _copyMember(sourceGroup, member)];

Map<String, dynamic> _copyMember(String group, Map<String, dynamic> member) {
  final id = member['id'];
  if (id is! String || id.isEmpty)
    throw const FormatException('Identifiant de membre manquant.');
  return {...member, 'id': 'copy_${group.length}_$group:$id'}
    ..remove('team_id');
}
