class HistoriqueItem {
  int? id;
  String username;
  String link;
  String date;
  bool isFavorite;
  String type;

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

  factory HistoriqueItem.fromMap(Map<String, dynamic> map) {
    return HistoriqueItem(
      id: map['id'],
      username: map['username'] ?? '',
      link: map['link'] ?? '',
      date: map['date'] ?? '',
      isFavorite: (map['isFavorite'] ?? 0) == 1,
      type: map['type'] ?? 'pending',
    );
  }

  @override
  String toString() {
    return 'HistoriqueItem{id: $id, username: $username, type: $type, date: $date, isFavorite: $isFavorite}';
  }
}