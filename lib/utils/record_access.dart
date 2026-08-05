import '../models/lead_model.dart';
import '../models/project_model.dart';

String _normalize(dynamic value) {
  return value?.toString().trim().toLowerCase() ?? '';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

Set<String> _actorTokens({
  required String userUid,
  required String userEmail,
  required String userName,
}) {
  final tokens = <String>{};

  void addToken(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return;
    tokens.add(normalized);
  }

  addToken(userUid);
  addToken(userEmail);
  addToken(userName);

  final emailHandle = _normalize(userEmail).split('@').first;
  if (emailHandle.isNotEmpty) {
    tokens.add(emailHandle);
  }

  return tokens;
}

bool _valueMatchesActor(dynamic value, Set<String> tokens) {
  final normalized = _normalize(value);
  if (normalized.isEmpty) return false;
  return tokens.contains(normalized);
}

bool _mapMatchesActor(Map<String, dynamic> map, Set<String> tokens) {
  return _valueMatchesActor(map['uid'], tokens) ||
      _valueMatchesActor(map['email'], tokens) ||
      _valueMatchesActor(map['name'], tokens);
}

bool leadOwnedByActor(
  LeadModel lead, {
  required String userUid,
  required String userEmail,
  required String userName,
}) {
  final tokens = _actorTokens(
    userUid: userUid,
    userEmail: userEmail,
    userName: userName,
  );
  if (tokens.isEmpty) return false;

  final data = lead.rawData;
  final createdBy = _asMap(data['createdBy']);
  final updatedBy = _asMap(data['updatedBy']);

  return _mapMatchesActor(createdBy, tokens) ||
      _mapMatchesActor(updatedBy, tokens) ||
      _valueMatchesActor(data['caller'], tokens) ||
      _valueMatchesActor(data['advisor'], tokens) ||
      _valueMatchesActor(data['reachedBy'], tokens);
}

bool projectOwnedByActor(
  ProjectModel project, {
  required String userUid,
  required String userEmail,
  required String userName,
}) {
  final tokens = _actorTokens(
    userUid: userUid,
    userEmail: userEmail,
    userName: userName,
  );
  if (tokens.isEmpty) return false;

  final data = project.rawData;
  final createdBy = _asMap(data['createdBy']);
  final updatedBy = _asMap(data['updatedBy']);

  return _mapMatchesActor(createdBy, tokens) ||
      _mapMatchesActor(updatedBy, tokens) ||
      _valueMatchesActor(project.contactPerson, tokens);
}

List<LeadModel> filterVisibleLeads({
  required List<LeadModel> leads,
  required bool canSeeAllLeads,
  required String userUid,
  required String userEmail,
  required String userName,
}) {
  if (canSeeAllLeads) return leads;
  return leads
      .where(
        (lead) => leadOwnedByActor(
          lead,
          userUid: userUid,
          userEmail: userEmail,
          userName: userName,
        ),
      )
      .toList();
}

List<ProjectModel> filterVisibleProjects({
  required List<ProjectModel> projects,
  required bool canSeeAllProjects,
  required String userUid,
  required String userEmail,
  required String userName,
}) {
  if (canSeeAllProjects) return projects;
  return projects
      .where(
        (project) => projectOwnedByActor(
          project,
          userUid: userUid,
          userEmail: userEmail,
          userName: userName,
        ),
      )
      .toList();
}

int countVisitedLeads(Iterable<LeadModel> leads) {
  return leads
      .where((lead) => _normalize(lead.rawData['demoDone']) == 'y')
      .length;
}

int countMatchingLeadStatuses(
  Iterable<LeadModel> leads,
  List<String> statuses,
) {
  final normalizedStatuses = statuses.map(_normalize).toSet();
  return leads
      .where((lead) => normalizedStatuses.contains(_normalize(lead.status)))
      .length;
}

String leadOwnerLabel(LeadModel lead) {
  final data = lead.rawData;
  final createdBy = _asMap(data['createdBy']);
  final updatedBy = _asMap(data['updatedBy']);

  for (final value in [
    createdBy['name'],
    createdBy['email'],
    updatedBy['name'],
    updatedBy['email'],
    data['caller'],
    data['advisor'],
  ]) {
    final label = value?.toString().trim() ?? '';
    if (label.isNotEmpty) return label;
  }
  return 'Unassigned';
}

String projectOwnerLabel(ProjectModel project) {
  final data = project.rawData;
  final createdBy = _asMap(data['createdBy']);
  final updatedBy = _asMap(data['updatedBy']);

  for (final value in [
    createdBy['name'],
    createdBy['email'],
    updatedBy['name'],
    updatedBy['email'],
    project.contactPerson,
  ]) {
    final label = value?.toString().trim() ?? '';
    if (label.isNotEmpty) return label;
  }
  return 'Unassigned';
}

Map<String, int> countLeadsByOwner(Iterable<LeadModel> leads) {
  final counts = <String, int>{};
  for (final lead in leads) {
    final owner = leadOwnerLabel(lead);
    counts.update(owner, (value) => value + 1, ifAbsent: () => 1);
  }
  return _sortCountMap(counts);
}

Map<String, int> countProjectsByOwner(Iterable<ProjectModel> projects) {
  final counts = <String, int>{};
  for (final project in projects) {
    final owner = projectOwnerLabel(project);
    counts.update(owner, (value) => value + 1, ifAbsent: () => 1);
  }
  return _sortCountMap(counts);
}

Map<String, int> _sortCountMap(Map<String, int> counts) {
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final countCompare = b.value.compareTo(a.value);
      if (countCompare != 0) return countCompare;
      return a.key.toLowerCase().compareTo(b.key.toLowerCase());
    });
  return Map<String, int>.fromEntries(entries);
}
