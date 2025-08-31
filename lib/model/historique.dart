class HistoriqueItem {
  final int? id;
  final String username;
  final String link;
  final String date;
  bool isFavorite;
  final String type;

  HistoriqueItem({
    this.id,
    required this.username,
    required this.link,
    required this.date,
    this.isFavorite = false,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'link': link,
      'date': date,
      'isFavorite': isFavorite ? 1 : 0,
      'type': type,
    };
  }
}