class User {
  final int? id;
  final String username;
  final String link;
  final String date;
  bool isFavorite;

  User({
    this.id,
    required this.username,
    required this.link,
    required this.date,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'link': link,
      'date': date,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }
}
