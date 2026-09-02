/// Domain errors for the `curriculo` module.
///
/// A `sealed class` that `implements Exception` — a generic exception (or a raw
/// `FormatException` / `TypeError`) must never cross the module boundary. Every
/// failure of [CurriculoRepository.load] is one of the three subtypes below.
library;

/// Base type for every recoverable failure of the curriculum catalog.
sealed class CurriculumError implements Exception {
  const CurriculumError();

  /// The catalog asset could not be read (missing key, unreadable bundle).
  const factory CurriculumError.assetNotFound(String assetKey) = AssetNotFound;

  /// The catalog is structurally invalid: bad root, wrong types, out-of-range
  /// values, a violated bicondicional, a duplicated id, etc. [path] points at
  /// the offending field/entry; [message] adds detail.
  const factory CurriculumError.malformedCatalog(
    String path, [
    String message,
  ]) = MalformedCatalog;

  /// A value outside the frozen taxonomy — an unknown `exerciseType`,
  /// `direction`, `timbreScaffold`, `errorTypes[i]`, or an exercise id that
  /// resolves against no `*Catalog` entry. Never falls back to a default.
  const factory CurriculumError.unknownValue(String field, String value) =
      UnknownValue;
}

/// The catalog asset is absent or unreadable.
final class AssetNotFound extends CurriculumError {
  const AssetNotFound(this.assetKey);

  final String assetKey;

  @override
  String toString() => 'CurriculumError.assetNotFound: $assetKey';

  @override
  bool operator ==(Object other) =>
      other is AssetNotFound && other.assetKey == assetKey;

  @override
  int get hashCode => Object.hash('AssetNotFound', assetKey);
}

/// The catalog is structurally invalid.
final class MalformedCatalog extends CurriculumError {
  const MalformedCatalog(this.path, [this.message = '']);

  /// Field path or catalog entry the violation is about, e.g.
  /// `schemaVersion`, `stages[s2-tercas]`, `intervalCatalog[3].nameUi`.
  final String path;

  /// Human-readable detail. May be empty.
  final String message;

  @override
  String toString() => message.isEmpty
      ? 'CurriculumError.malformedCatalog: $path'
      : 'CurriculumError.malformedCatalog: $path — $message';

  @override
  bool operator ==(Object other) =>
      other is MalformedCatalog &&
      other.path == path &&
      other.message == message;

  @override
  int get hashCode => Object.hash('MalformedCatalog', path, message);
}

/// A value outside the frozen taxonomy.
final class UnknownValue extends CurriculumError {
  const UnknownValue(this.field, this.value);

  /// Field path the unknown value came from.
  final String field;

  /// The offending value, verbatim.
  final String value;

  @override
  String toString() => 'CurriculumError.unknownValue: $field = "$value"';

  @override
  bool operator ==(Object other) =>
      other is UnknownValue && other.field == field && other.value == value;

  @override
  int get hashCode => Object.hash('UnknownValue', field, value);
}
