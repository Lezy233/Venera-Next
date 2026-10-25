import 'package:venera_next/foundation/translations.dart';

class FavoriteSeries {
  const FavoriteSeries({
    required this.id,
    required this.name,
    required this.displayOrder,
  });

  final String id;
  final String name;
  final int displayOrder;
}

String favoriteSeriesErrorMessage(Object error) {
  final message = error is FormatException ? error.message.toString() : 'Error';
  return message.tl;
}
