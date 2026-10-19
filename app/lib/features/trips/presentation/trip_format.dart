String formatDay(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String formatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';

String formatWhen(DateTime date) => '${formatDay(date)} · ${formatTime(date)}';

String formatPrice(double? price) =>
    price == null ? 'Prix non indiqué' : '${price.toStringAsFixed(0)} DT';
