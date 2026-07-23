class RecentSearch {
  const RecentSearch({required this.title, required this.address});

  final String title;
  final String address;

  Map<String, Object?> toJson() => {'title': title, 'address': address};

  static RecentSearch? fromJson(Object? value) {
    if (value case {
      'title': final String title,
      'address': final String address,
    } when title.trim().isNotEmpty) {
      return RecentSearch(title: title, address: address);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is RecentSearch && other.title == title && other.address == address;

  @override
  int get hashCode => Object.hash(title, address);
}
