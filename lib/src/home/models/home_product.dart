class HomeProduct {
  final String id;
  final String title;
  final double price;
  final String priceText;
  final String imageUrl;
  final double distanceMiles;
  final bool isUsed;
  final String category;
  final DateTime createdAt;
  final String? sellerName;
  final String? condition;
  final String? locality;

  HomeProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.priceText,
    required this.imageUrl,
    required this.distanceMiles,
    required this.isUsed,
    required this.category,
    required this.createdAt,
    this.sellerName,
    this.condition,
    this.locality,
  });

  factory HomeProduct.fromJson(Map<String, dynamic> json) {
    return HomeProduct(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      priceText: 'Free',
      imageUrl: json['imageUrl'] ?? '',
      distanceMiles: (json['distanceMiles'] ?? 0).toDouble(),
      isUsed: json['isUsed'] ?? false,
      category: json['category'] ?? '',
      createdAt: json['createdAt']?.toDate() ?? DateTime.now(),
      sellerName: json['sellerName'],
      condition: json['condition'],
      locality: json['locality'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'priceText': priceText,
      'imageUrl': imageUrl,
      'distanceMiles': distanceMiles,
      'isUsed': isUsed,
      'category': category,
      'createdAt': createdAt,
      'sellerName': sellerName,
      'condition': condition,
      'locality': locality,
    };
  }
}
