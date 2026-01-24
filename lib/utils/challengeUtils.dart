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