import 'package:flutter/material.dart';

int calculateDayNumber({
      required DateTime joinedAt,
      required int totalDays,
    }) {
    final now = DateTime.now();

    final start = DateTime(
    joinedAt.year,
    joinedAt.month,
    joinedAt.day,
    );

    final today = DateTime(
    now.year,
    now.month,
    now.day,
    );

    final day = today.difference(start).inDays + 1;

    return day.clamp(1, totalDays);
}

Color getColorForUser(String userId) {
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.pink,
    ];
    final index = userId.codeUnits.fold(0, (prev, c) => prev + c) % colors.length;
    return colors[index];
}