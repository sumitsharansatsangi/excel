part of '../../excel.dart';

Archive _cloneArchive(
  Archive archive,
  Map<String, ArchiveFile> replacements, {
  String? excludedFile,
}) {
  final clone = Archive()..comment = archive.comment;
  final originalNames = <String>{};
  bool excluded(String name) =>
      excludedFile != null && name.toLowerCase() == excludedFile.toLowerCase();

  for (final file in archive) {
    originalNames.add(file.name);
    if (!excluded(file.name)) {
      // Retain the raw compressed content and ZIP metadata. The encoder does
      // not close shared entries (autoClose defaults to false).
      clone.addFile(replacements[file.name] ?? file);
    }
  }
  for (final entry in replacements.entries) {
    if (!originalNames.contains(entry.key) && !excluded(entry.key)) {
      clone.addFile(entry.value);
    }
  }
  return clone;
}
