import 'package:caldav_free/core/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int year, int month, int day, [int hour = 0]) =>
      DateTime(year, month, day, hour);

  group('occurrencesBetween', () {
    test('daily covers the window on both ends', () {
      expect(
        occurrencesBetween(
          'FREQ=DAILY',
          at(2026, 10, 28),
          at(2026, 10, 28),
          at(2026, 10, 31),
        ),
        [at(2026, 10, 28), at(2026, 10, 29), at(2026, 10, 30), at(2026, 10, 31)],
      );
    });

    test('interval skips days', () {
      expect(
        occurrencesBetween(
          'FREQ=DAILY;INTERVAL=2',
          at(2026, 10, 28),
          at(2026, 10, 28),
          at(2026, 11, 3),
        ),
        [at(2026, 10, 28), at(2026, 10, 30), at(2026, 11, 1), at(2026, 11, 3)],
      );
    });

    test('weekly repeats on the anchor weekday', () {
      expect(
        occurrencesBetween(
          'FREQ=WEEKLY',
          at(2026, 10, 28),
          at(2026, 10, 28),
          at(2026, 11, 15),
        ),
        [at(2026, 10, 28), at(2026, 11, 4), at(2026, 11, 11)],
      );
    });

    test('the workday preset expands to every weekday', () {
      expect(
        occurrencesBetween(
          'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
          at(2026, 10, 28),
          at(2026, 10, 28),
          at(2026, 11, 6),
        ),
        [
          at(2026, 10, 28),
          at(2026, 10, 29),
          at(2026, 10, 30),
          at(2026, 11, 2),
          at(2026, 11, 3),
          at(2026, 11, 4),
          at(2026, 11, 5),
          at(2026, 11, 6),
        ],
      );
    });

    test('weekdays earlier in the anchor week are dropped', () {
      expect(
        occurrencesBetween(
          'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
          at(2026, 10, 28),
          at(2026, 10, 26),
          at(2026, 10, 30),
        ),
        [at(2026, 10, 28), at(2026, 10, 29), at(2026, 10, 30)],
      );
    });

    test('monthly skips months without that day', () {
      expect(
        occurrencesBetween(
          'FREQ=MONTHLY',
          at(2026, 1, 31),
          at(2026, 1, 1),
          at(2026, 7, 1),
        ),
        [at(2026, 1, 31), at(2026, 3, 31), at(2026, 5, 31)],
      );
    });

    test('yearly skips non-leap years', () {
      expect(
        occurrencesBetween(
          'FREQ=YEARLY',
          at(2024, 2, 29),
          at(2024, 1, 1),
          at(2029, 1, 1),
        ),
        [at(2024, 2, 29), at(2028, 2, 29)],
      );
    });

    test('count caps the series', () {
      expect(
        occurrencesBetween(
          'FREQ=DAILY;COUNT=3',
          at(2026, 10, 28),
          at(2026, 10, 28),
          at(2026, 11, 30),
        ),
        [at(2026, 10, 28), at(2026, 10, 29), at(2026, 10, 30)],
      );
    });

    test('until caps the series', () {
      expect(
        occurrencesBetween(
          'FREQ=DAILY;UNTIL=20261030',
          at(2026, 10, 28),
          at(2026, 10, 28),
          at(2026, 11, 30),
        ),
        [at(2026, 10, 28), at(2026, 10, 29), at(2026, 10, 30)],
      );
    });

    test('occurrences keep the anchor time of day', () {
      expect(
        occurrencesBetween(
          'FREQ=DAILY',
          at(2026, 10, 28, 22),
          at(2026, 10, 28),
          at(2026, 10, 31),
        ),
        [at(2026, 10, 28, 22), at(2026, 10, 29, 22), at(2026, 10, 30, 22)],
      );
    });

    test('a series anchored after the window yields nothing', () {
      expect(
        occurrencesBetween(
          'FREQ=DAILY',
          at(2026, 11, 30),
          at(2026, 10, 28),
          at(2026, 10, 31),
        ),
        isEmpty,
      );
    });

    test('rules with unsupported parts fall back to the anchor', () {
      expect(
        occurrencesBetween(
          'FREQ=MONTHLY;BYMONTHDAY=15',
          at(2026, 10, 28),
          at(2026, 10, 1),
          at(2026, 11, 30),
        ),
        [at(2026, 10, 28)],
      );
    });

    test('limit caps how many dates come back', () {
      expect(
        occurrencesBetween(
          'FREQ=DAILY',
          at(2026, 1, 1),
          at(2026, 1, 1),
          at(2026, 12, 31),
          limit: 5,
        ).length,
        5,
      );
    });
  });

  group('recurrenceLabel', () {
    test('names the editor presets', () {
      expect(recurrenceLabel('FREQ=DAILY'), '每天');
      expect(recurrenceLabel('FREQ=WEEKLY'), '每周');
      expect(recurrenceLabel('FREQ=MONTHLY'), '每月');
      expect(recurrenceLabel('FREQ=YEARLY'), '每年');
      expect(recurrenceLabel('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'), '每周 周一、周二、周三、周四、周五');
    });

    test('keeps the interval and falls back to the raw rule', () {
      expect(recurrenceLabel('FREQ=DAILY;INTERVAL=2'), '每 2 天');
      expect(recurrenceLabel('FREQ=MONTHLY;BYMONTHDAY=15'), 'FREQ=MONTHLY;BYMONTHDAY=15');
    });
  });
}
