// test/date_utils_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
// Assuming NotificationService is in lib/notification_service.dart
import 'package:bello/notification_service.dart';
// For _getDateFromYearAndWeek, if we made it a top-level function or static in a class:
// import 'package:bello/utils/date_helpers.dart'; // Example path

// Helper function for _getDateFromYearAndWeek (mimicking from HomeScreenState for testability)
// In a real scenario, this would be imported from its actual location if refactored.
DateTime testGetDateFromYearAndWeek(int year, int week) {
  final jan4 = DateTime(year, 1, 4);
  final dayOfWeekJan4 = jan4.weekday;
  final firstMondayOfWeek1 = jan4.subtract(Duration(days: dayOfWeekJan4 - 1));
  return firstMondayOfWeek1.add(Duration(days: (week - 1) * 7));
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    // Set a known timezone for consistent testing of _nextInstanceOf8PM
    // Use a timezone that doesn't have DST changes around 8 PM if possible, or be mindful of DST.
    // For simplicity, let's use UTC for testing this specific logic part,
    // assuming the _nextInstanceOf8PM logic is robust enough for tz.local.
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  group('Date Utility Tests', () {
    test('_getDateFromYearAndWeek returns correct Monday', () {
      // Example: Week 1 of 2023 (Jan 2, 2023 was Monday)
      expect(testGetDateFromYearAndWeek(2023, 1), DateTime(2023, 1, 2));
      // Example: Week 40 of 2023 (Oct 2, 2023 was Monday)
      expect(testGetDateFromYearAndWeek(2023, 40), DateTime(2023, 10, 2));
      // Example: Week 1 of 2024 (Jan 1, 2024 was Monday)
      expect(testGetDateFromYearAndWeek(2024, 1), DateTime(2024, 1, 1));
    });
  });

  group('NotificationService Tests', () {
    test('_nextInstanceOf8PM returns correct upcoming 8 PM', () {
      // Test case 1: Current time is before 8 PM
      final nowBefore8PM = tz.TZDateTime(tz.local, 2023, 10, 26, 10, 0); // Oct 26, 2023, 10:00 AM
      final scheduledTime1 = NotificationService.testNextInstanceOf8PM(nowBefore8PM);
      expect(scheduledTime1.year, 2023);
      expect(scheduledTime1.month, 10);
      expect(scheduledTime1.day, 26);
      expect(scheduledTime1.hour, 20);
      expect(scheduledTime1.minute, 0);

      // Test case 2: Current time is after 8 PM
      final nowAfter8PM = tz.TZDateTime(tz.local, 2023, 10, 26, 22, 0); // Oct 26, 2023, 10:00 PM
      final scheduledTime2 = NotificationService.testNextInstanceOf8PM(nowAfter8PM);
      expect(scheduledTime2.year, 2023);
      expect(scheduledTime2.month, 10);
      expect(scheduledTime2.day, 27); // Should be next day
      expect(scheduledTime2.hour, 20);
      expect(scheduledTime2.minute, 0);

      // Test case 3: Current time is exactly 8 PM
      final nowAt8PM = tz.TZDateTime(tz.local, 2023, 10, 26, 20, 0); // Oct 26, 2023, 8:00 PM
      final scheduledTime3 = NotificationService.testNextInstanceOf8PM(nowAt8PM);
      // Current logic `if (scheduledDate.isBefore(now))` means if now IS 8PM, it schedules for next day's 8PM.
      expect(scheduledTime3.year, 2023);
      expect(scheduledTime3.month, 10);
      expect(scheduledTime3.day, 27); // Next day due to strict isBefore
      expect(scheduledTime3.hour, 20);
      expect(scheduledTime3.minute, 0);
    });
  });
}
