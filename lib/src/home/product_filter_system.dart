import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

// Single-file, fully self-contained demo with dummy data and real-world-like logic

enum Condition { newItem, likeNew, good, fair }
enum Category { electronics, home, vehicles, books }
enum PostedSince { allTime, today, last7Days, last30Days }

class Product {
  final String id;
  final String title;
  final double price;
  final double distanceKm;
  final Condition condition;
  final Category category;
  final DateTime postedDate;

  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.distanceKm,
    required this.condition,
    required this.category,
    required this.postedDate,
  });
}

class FilterState {
  final double minPrice;
  final double maxPrice;
  final double maxDistanceKm;
  final Set<Condition> selectedConditions;
  final Set<Category> selectedCategories;
  final PostedSince postedSince;

  const FilterState({
    this.minPrice = 0,
    this.maxPrice = 100000,
    this.maxDistanceKm = 100,
    this.selectedConditions = const {},
    this.selectedCategories = const {},
    this.postedSince = PostedSince.allTime,
  });

  FilterState copyWith({
    double? minPrice,
    double? maxPrice,
    double? maxDistanceKm,
    Set<Condition>? selectedConditions,
    Set<Category>? selectedCategories,
    PostedSince? postedSince,
  }) {
    return FilterState(
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      selectedConditions: selectedConditions ?? this.selectedConditions,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      postedSince: postedSince ?? this.postedSince,
    );
  }
}

class ProductFilterScreen extends StatefulWidget {
  const ProductFilterScreen({super.key});

  @override
  State<ProductFilterScreen> createState() => _ProductFilterScreenState();
}

class _ProductFilterScreenState extends State<ProductFilterScreen> {
  List<Product> _allProducts = <Product>[];
  FilterState _filters = const FilterState();
  bool _loading = true;
  String? _error;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Konum izni ve kullanıcı konumu
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      if (await Geolocator.isLocationServiceEnabled()) {
        _userPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      }

      // Firestore'dan gerçek verileri çek
      _allProducts = await _fetchProductsFromFirestore(userPosition: _userPosition);
    } catch (e) {
      _error = 'Failed to load data: $e';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<List<Product>> _fetchProductsFromFirestore({Position? userPosition}) async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('listings').limit(200).get();

    final List<Product> items = <Product>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final String id = doc.id;
      final String title = (data['title'] ?? '').toString();
      final double price = _asDouble(data['price']);
      final String conditionStr = (data['condition'] ?? '').toString();
      final String categoryStr = (data['category'] ?? '').toString();
      final Timestamp? ts = data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null;
      final Timestamp? tsAlt = data['postedAt'] is Timestamp ? data['postedAt'] as Timestamp : null;
      final DateTime posted = (ts ?? tsAlt)?.toDate() ?? DateTime.now();

      // Mesafe (km) hesapla – varsa GeoPoint, yoksa 0
      double distanceKm = 0;
      final GeoPoint? loc = data['location'] is GeoPoint ? data['location'] as GeoPoint : null;
      if (loc != null && userPosition != null) {
        final meters = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          loc.latitude,
          loc.longitude,
        );
        distanceKm = meters / 1000.0;
      }

      final Condition? cond = _parseCondition(conditionStr);
      final Category? cat = _parseCategory(categoryStr);
      if (title.isEmpty || cond == null || cat == null) {
        // Uyuşmayan/eksik kayıtları atla
        continue;
      }

      items.add(Product(
        id: id,
        title: title,
        price: price,
        distanceKm: distanceKm,
        condition: cond,
        category: cat,
        postedDate: posted,
      ));
    }
    return items;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Condition? _parseCondition(String v) {
    final s = v.toLowerCase();
    if (s == 'new' || s == 'newitem' || s == 'brandnew') return Condition.newItem;
    if (s == 'likenew') return Condition.likeNew;
    if (s == 'good') return Condition.good;
    if (s == 'fair' || s == 'used') return Condition.fair;
    return null;
  }

  Category? _parseCategory(String v) {
    final s = v.toLowerCase();
    if (s.contains('elect')) return Category.electronics;
    if (s.contains('home') || s.contains('furniture')) return Category.home;
    if (s.contains('vehicle') || s.contains('car') || s.contains('auto')) return Category.vehicles;
    if (s.contains('book')) return Category.books;
    return null;
  }

  List<Product> applyFilters(List<Product> products, FilterState filters) {
    final now = DateTime.now();

    bool withinDate(DateTime d) {
      switch (filters.postedSince) {
        case PostedSince.allTime:
          return true;
        case PostedSince.today:
          final start = DateTime(now.year, now.month, now.day);
          return d.isAfter(start);
        case PostedSince.last7Days:
          return d.isAfter(now.subtract(const Duration(days: 7)));
        case PostedSince.last30Days:
          return d.isAfter(now.subtract(const Duration(days: 30)));
      }
    }

    return products.where((p) {
      final priceOk = p.price >= filters.minPrice && p.price <= filters.maxPrice;
      final distanceOk = p.distanceKm <= filters.maxDistanceKm;
      final conditionOk = filters.selectedConditions.isEmpty || filters.selectedConditions.contains(p.condition);
      final categoryOk = filters.selectedCategories.isEmpty || filters.selectedCategories.contains(p.category);
      final dateOk = withinDate(p.postedDate);
      return priceOk && distanceOk && conditionOk && categoryOk && dateOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = applyFilters(_allProducts, _filters);

    return Scaffold(
      appBar: AppBar(
        title: _loading
            ? const Text('Loading...')
            : Text(_error != null ? 'Error' : '${filtered.length} items found'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () async {
              final updated = await showModalBottomSheet<FilterState>(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => FilterSettingsScreen(initial: _filters),
              );
              if (updated != null) {
                setState(() => _filters = updated);
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _initialize, child: const Text('Try Again')),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return ListTile(
                      title: Text(p.title),
                      subtitle: Text('Free • ${p.distanceKm.toStringAsFixed(0)} km • ${p.category.name}'),
                      trailing: Text(_conditionLabel(p.condition)),
                    );
                  },
                ),
    );
  }

  String _conditionLabel(Condition c) {
    switch (c) {
      case Condition.newItem:
        return 'New';
      case Condition.likeNew:
        return 'Like New';
      case Condition.good:
        return 'Good';
      case Condition.fair:
        return 'Fair';
    }
  }
}

class FilterSettingsScreen extends StatefulWidget {
  const FilterSettingsScreen({super.key, required this.initial});
  final FilterState initial;

  @override
  State<FilterSettingsScreen> createState() => _FilterSettingsScreenState();
}

class _FilterSettingsScreenState extends State<FilterSettingsScreen> {
  late double _minPrice;
  late double _maxPrice;
  late double _maxDistance;
  late Set<Condition> _conditions;
  late Set<Category> _categories;
  late PostedSince _postedSince;

  @override
  void initState() {
    super.initState();
    _minPrice = widget.initial.minPrice;
    _maxPrice = widget.initial.maxPrice;
    _maxDistance = widget.initial.maxDistanceKm;
    _conditions = Set<Condition>.from(widget.initial.selectedConditions);
    _categories = Set<Category>.from(widget.initial.selectedCategories);
    _postedSince = widget.initial.postedSince;
  }

  void _reset() {
    setState(() {
      _minPrice = 0;
      _maxPrice = 100000;
      _maxDistance = 100;
      _conditions.clear();
      _categories.clear();
      _postedSince = PostedSince.allTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return Material(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  controller: controller,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Max Distance
                    const Text('Max Distance (km)', style: TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: _maxDistance,
                      min: 1,
                      max: 100,
                      divisions: 99,
                      label: '${_maxDistance.toStringAsFixed(0)} km',
                      onChanged: (v) => setState(() => _maxDistance = v),
                    ),

                    const SizedBox(height: 8),

                    // Conditions multi-select
                    const Text('Condition', style: TextStyle(fontWeight: FontWeight.w600)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: Condition.values.map((c) {
                        final selected = _conditions.contains(c);
                        return FilterChip(
                          label: Text(_conditionText(c)),
                          selected: selected,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _conditions.add(c);
                            } else {
                              _conditions.remove(c);
                            }
                          }),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 8),

                    // Categories multi-select
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: Category.values.map((cat) {
                        final selected = _categories.contains(cat);
                        return FilterChip(
                          label: Text(cat.name),
                          selected: selected,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _categories.add(cat);
                            } else {
                              _categories.remove(cat);
                            }
                          }),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 8),

                    // Posted Since single select
                    const Text('Date', style: TextStyle(fontWeight: FontWeight.w600)),
                    Wrap(
                      spacing: 8,
                      children: PostedSince.values.map((ps) {
                        final selected = _postedSince == ps;
                        return ChoiceChip(
                          label: Text(_postedSinceText(ps)),
                          selected: selected,
                          onSelected: (_) => setState(() => _postedSince = ps),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _reset,
                            child: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final result = FilterState(
                                minPrice: _minPrice,
                                maxPrice: _maxPrice,
                                maxDistanceKm: _maxDistance,
                                selectedConditions: _conditions,
                                selectedCategories: _categories,
                                postedSince: _postedSince,
                              );
                              Navigator.pop(context, result);
                            },
                            child: const Text('Apply Filters'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _conditionText(Condition c) {
    switch (c) {
      case Condition.newItem:
        return 'New';
      case Condition.likeNew:
        return 'Like New';
      case Condition.good:
        return 'Good';
      case Condition.fair:
        return 'Fair';
    }
  }

  String _postedSinceText(PostedSince p) {
    switch (p) {
      case PostedSince.allTime:
        return 'All';
      case PostedSince.today:
        return 'Today';
      case PostedSince.last7Days:
        return 'Last 7 Days';
      case PostedSince.last30Days:
        return 'Last 30 Days';
    }
  }
}


