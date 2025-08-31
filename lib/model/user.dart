class User {
  int? id;
  String username;
  String link;
  String date;
  bool isFavorite;
  String? source;

  User({
    this.id,
    required this.username,
    required this.link,
    required this.date,
    this.isFavorite = false,
    this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'link': link,
      'date': date,
      'isFavorite': isFavorite ? 1 : 0,
      'source': source,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'] ?? '',
      link: map['link'] ?? '',
      date: map['date'] ?? '',
      isFavorite: (map['isFavorite'] ?? 0) == 1,
      source: map['source'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.username == username;
  }

  @override
  int get hashCode => username.hashCode;

  @override
  String toString() {
    return 'User{id: $id, username: $username, link: $link, date: $date, isFavorite: $isFavorite, source: $source}';
  }
}