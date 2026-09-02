/// Shared test helpers for the curriculum catalog: load the committed
/// `catalog_v1.json`, deep-copy it, and apply a mutation to build a fixture.
library;

import 'dart:convert';
import 'dart:io';

/// The committed catalog, decoded once.
final Map<String, dynamic> realCatalogJson = json.decode(
  File('assets/curriculum/catalog_v1.json').readAsStringSync(),
) as Map<String, dynamic>;

/// A deep copy of the real catalog with [mutate] applied. Each call is
/// independent — mutations never leak between fixtures.
Map<String, dynamic> catalogFixture(
  void Function(Map<String, dynamic> json) mutate,
) {
  final copy =
      json.decode(json.encode(realCatalogJson)) as Map<String, dynamic>;
  mutate(copy);
  return copy;
}

/// [catalogFixture] serialised back to a JSON string.
String catalogFixtureString(void Function(Map<String, dynamic> json) mutate) =>
    json.encode(catalogFixture(mutate));

List<Map<String, dynamic>> stagesOf(Map<String, dynamic> j) =>
    (j['stages'] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> stageById(Map<String, dynamic> j, String id) =>
    stagesOf(j).firstWhere((s) => s['stageId'] == id);

List<Map<String, dynamic>> exercisesOf(Map<String, dynamic> stage) =>
    (stage['exercises'] as List).cast<Map<String, dynamic>>();
