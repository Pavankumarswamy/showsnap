import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension DateTimeExt on DateTime {
  String get dateLabel => DateFormat('dd MMM yyyy').format(this);
  String get timeLabel => DateFormat('hh:mm a').format(this);
  String get dateTimeLabel => DateFormat('dd MMM, hh:mm a').format(this);
  String get dayShort => DateFormat('EEE').format(this);
  String get dayNum => DateFormat('d').format(this);
  String get monthShort => DateFormat('MMM').format(this);
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }
}

extension IntEpochExt on int {
  DateTime get toDateTime =>
      DateTime.fromMillisecondsSinceEpoch(this);

  String get epochToDateLabel => toDateTime.dateLabel;
  String get epochToTimeLabel => toDateTime.timeLabel;
  String get epochToDateTimeLabel => toDateTime.dateTimeLabel;

  String get toRupees => '₹${NumberFormat('#,##,###').format(this)}';
}

extension StringExt on String {
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  String get titleCase => split(' ').map((w) => w.capitalize).join(' ');

  bool get isValidEmail =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(this);

  bool get isValidPhone => RegExp(r'^\+?[0-9]{10,13}$').hasMatch(this);
}

extension ContextExt on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  void showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(this).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void showErrorSnackbar(String message) => showSnackbar(message, isError: true);
}

extension ListExt<T> on List<T> {
  List<T> separatedBy(T separator) {
    if (length <= 1) return this;
    final result = <T>[];
    for (var i = 0; i < length; i++) {
      result.add(this[i]);
      if (i < length - 1) result.add(separator);
    }
    return result;
  }
}
