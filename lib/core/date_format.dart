part of '../main.dart';

class DateFormat {
  static String format(DateTime date, String pattern) {
    if (pattern == 'D') {
      final firstDay = DateTime(date.year, 1, 1);
      return date.difference(firstDay).inDays.toString();
    }
    return '';
  }
}

///
/// MAIN APP
