import '../domain/models.dart';

/// Optional sections must not prevent the current ride from being recovered.
class LoadResult<T> {
  final T? value;
  final Object? error;
  const LoadResult.value(this.value) : error = null;
  const LoadResult.error(this.error) : value = null;
  T or(T fallback) => error == null ? value as T : fallback;

  static Future<LoadResult<T>> capture<T>(Future<T> Function() load) async {
    try {
      return LoadResult.value(await load());
    } catch (e) {
      if (e is Failure &&
          const ['SESSION_CHANGED', 'SESSION_EXPIRED'].contains(e.code)) {
        rethrow;
      }
      return LoadResult.error(e);
    }
  }
}

String? loadingWarning(Map<String, Object?> errors) {
  final sections = errors.entries
      .where((e) => e.value != null)
      .map((e) => e.key)
      .toList();
  return sections.isEmpty
      ? null
      : 'Chưa cập nhật được ${sections.join(', ')}. Kéo xuống để thử lại.';
}

String? combineWarnings(Iterable<String?> messages) {
  final text = messages
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join('\n');
  return text.isEmpty ? null : text;
}
