import 'package:caldav_free/core/merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeTaskMaps', () {
    test('local touched fields win, other fields follow the server', () {
      final merged = mergeTaskMaps(
        local: {
          'title': '本地标题',
          'notes': '本地备注',
          'priority': 3,
        },
        remote: {
          'title': '服务端标题',
          'notes': '服务端备注',
          'priority': 1,
          'due': '2026-10-26T09:00:00Z',
        },
        localFields: {'title'},
      );

      expect(merged['title'], '本地标题');
      expect(merged['notes'], '服务端备注');
      expect(merged['priority'], 1);
      expect(merged['due'], '2026-10-26T09:00:00Z');
    });

    test('earliest completion wins when completion itself is untouched', () {
      final merged = mergeTaskMaps(
        local: {
          'completed': true,
          'completedAt': '2026-10-25T10:00:00Z',
        },
        remote: {
          'completed': true,
          'completedAt': '2026-10-24T10:00:00Z',
        },
        localFields: {'title'},
      );

      expect(merged['completed'], true);
      expect(merged['completedAt'], '2026-10-24T10:00:00.000Z');
    });

    test('uncompleting locally is preserved', () {
      final merged = mergeTaskMaps(
        local: {'completed': false, 'completedAt': null},
        remote: {
          'completed': true,
          'completedAt': '2026-10-24T10:00:00Z',
        },
        localFields: {'completed', 'completedAt'},
      );

      expect(merged['completed'], false);
      expect(merged['completedAt'], isNull);
    });

    test('deletion always wins', () {
      final remoteDeleted = mergeTaskMaps(
        local: {'title': '本地', 'deleted': false},
        remote: {
          'title': '服务端',
          'deleted': true,
          'deletedAt': '2026-10-25T10:00:00Z',
        },
        localFields: {'title'},
      );
      expect(remoteDeleted['deleted'], true);

      final localDeleted = mergeTaskMaps(
        local: {
          'title': '本地',
          'deleted': true,
          'deletedAt': '2026-10-25T10:00:00Z',
        },
        remote: {'title': '服务端', 'deleted': false},
        localFields: {'title'},
        localDeleted: true,
      );
      expect(localDeleted['deleted'], true);
    });
  });
}
