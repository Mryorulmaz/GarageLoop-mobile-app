import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'view_models/search_view_model.dart';
import 'models/search_filters.dart';
import '../core/services/image_optimization_service.dart';
import '../product/product_detail_screen.dart';
import '../core/widgets/ad_banner.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _buildSearchBar(),
        actions: [
          Consumer<SearchViewModel>(
            builder: (context, vm, _) {
              return IconButton(
                icon: Icon(
                  Icons.filter_alt,
                  color: vm.hasActiveFilters ? Colors.blue : Colors.grey[700],
                ),
                onPressed: () => _showFiltersSheet(context),
                tooltip: 'Filters',
              );
            },
          ),
        ],
      ),
      body: Consumer<SearchViewModel>(
        builder: (context, searchVM, child) {
          if (searchVM.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (searchVM.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    searchVM.errorMessage!,
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => searchVM.clearError(),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          if (searchVM.isSearching || searchVM.searchResults.isNotEmpty) {
            return _buildSearchResults(searchVM);
          }

          return _buildSearchSuggestions(searchVM);
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Consumer<SearchViewModel>(
      builder: (context, searchVM, child) {
        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Search cars, phones, bikes…',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[500]),
                      onPressed: () {
                        _searchController.clear();
                        searchVM.clearSearch();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              searchVM.getSearchSuggestions(value);
            },
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                searchVM.search(value);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchSuggestions(SearchViewModel searchVM) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryStrip(searchVM),
          const SizedBox(height: 16),
          // Recent searches
          if (searchVM.recentSearches.isNotEmpty) ...[
            _buildSectionTitle('Recent Searches'),
            const SizedBox(height: 12),
            _buildRecentSearches(searchVM),
            const SizedBox(height: 24),
          ],

          // Trending searches
          if (searchVM.trendingSearches.isNotEmpty) ...[
            _buildSectionTitle('Trending'),
            const SizedBox(height: 12),
            _buildTrendingSearches(searchVM),
            const SizedBox(height: 24),
          ],

          // Search suggestions
          if (searchVM.searchSuggestions.isNotEmpty) ...[
            _buildSectionTitle('Suggestions'),
            const SizedBox(height: 12),
            _buildSearchSuggestionsList(searchVM),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryStrip(SearchViewModel searchVM) {
    const categories = [
      'All',
      'Electronics',
      'Home & Furniture',
      'Vehicles',
      'Vehicle Accessories',
      'Home Appliances',
      'Sports & Outdoors',
      'Fashion & Accessories',
      'Kids & Toys',
      'Books & Media',
      'Tools & DIY',
      'Garden & Patio',
    ];

    final selected = searchVM.currentFilters.category;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selected == cat;
          return ChoiceChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (_) {
              searchVM.setCategory(cat == 'All' ? 'All' : cat);
              if (searchVM.isSearching) {
                searchVM.searchWithFilters(searchVM.currentFilters.copyWith());
              }
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: categories.length,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildRecentSearches(SearchViewModel searchVM) {
    return Column(
      children: [
        ...searchVM.recentSearches.map((search) => _buildSearchChip(
          search,
          Icons.history,
          () => searchVM.search(search),
        )),
        if (searchVM.recentSearches.isNotEmpty)
          TextButton(
            onPressed: () => _showClearHistoryDialog(searchVM),
            child: const Text('Clear History'),
          ),
      ],
    );
  }

  Widget _buildTrendingSearches(SearchViewModel searchVM) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: searchVM.trendingSearches.map((search) => _buildSearchChip(
        search,
        Icons.trending_up,
        () => searchVM.search(search),
      )).toList(),
    );
  }

  Widget _buildSearchSuggestionsList(SearchViewModel searchVM) {
    return Column(
      children: searchVM.searchSuggestions.map((suggestion) => ListTile(
        leading: const Icon(Icons.search, color: Colors.grey),
        title: Text(suggestion),
        onTap: () => searchVM.search(suggestion),
      )).toList(),
    );
  }

  Widget _buildSearchChip(String text, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Colors.grey[600]),
      label: Text(text),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey[300]!),
    );
  }

  Widget _buildSearchResults(SearchViewModel searchVM) {
    return Column(
      children: [
        // Filter summary
        if (searchVM.hasActiveFilters)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    searchVM.filterSummary,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: () => _showFiltersSheet(context),
                  child: const Text('Edit'),
                ),
              ],
            ),
          ),

        // Results count
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                '${searchVM.totalResults} results',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (sortBy) => searchVM.sortResults(sortBy),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'relevance',
                    child: Text('Most Relevant'),
                  ),
                  const PopupMenuItem(
                    value: 'date_new',
                    child: Text('Newest First'),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sort',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Results list
        Expanded(
          child: searchVM.searchResults.isEmpty
              ? _buildEmptyResults()
              : _buildResultsList(searchVM),
        ),
      ],
    );
  }

  Widget _buildEmptyResults() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'We couldn’t find any matches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try broader keywords or update your filters.',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionChip(
                label: const Text('Show nearby areas'),
                avatar: const Icon(Icons.map),
                onPressed: () {
                  final vm = context.read<SearchViewModel>();
                  vm.setRadius((vm.currentFilters.radius + 10).clamp(5.0, 100.0));
                  vm.searchWithFilters(vm.currentFilters);
                },
              ),
              ActionChip(
                label: const Text('Create alert for this search'),
                avatar: const Icon(Icons.notifications_active),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Search alert created')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Suggested alternatives', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              Chip(label: Text('Wood Furniture')),
              Chip(label: Text('Coffee Tables')),
              Chip(label: Text('Living Room')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(SearchViewModel searchVM) {
    final results = searchVM.searchResults;
    final itemCount = results.length + (results.length / 4).floor();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= 4 && (index - 4) % 5 == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: InlineBanner(),
          );
        }
        final productIndex = index - ((index + 1) ~/ 5);
        final result = results[productIndex];
        return _buildSearchResultCard(result);
      },
    );
  }

  Widget _buildSearchResultCard(SearchResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(productId: result.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: OptimizedImage(
                  imageUrl: result.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'FREE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: result.isUsed ? Colors.orange[100] : Colors.green[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            result.conditionText,
                            style: TextStyle(
                              fontSize: 12,
                              color: result.isUsed ? Colors.orange[800] : Colors.green[800],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          result.formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (result.distanceText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            result.distanceText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFiltersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SearchFiltersSheet(),
    );
  }

  void _showClearHistoryDialog(SearchViewModel searchVM) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Search History'),
        content: const Text('Are you sure you want to clear your search history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              searchVM.clearSearchHistory();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class SearchFiltersSheet extends StatefulWidget {
  const SearchFiltersSheet({super.key});

  @override
  State<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<SearchFiltersSheet> {
  late SearchFilters _filters;
  // Removed unused fields

  @override
  void initState() {
    super.initState();
    _filters = context.read<SearchViewModel>().currentFilters;
    // no-op
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filters = SearchFilters();
                        // no-op
                      });
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'Filters'),
                Tab(text: 'Categories'),
              ],
              labelColor: Colors.black,
              indicatorColor: Colors.blue,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildFiltersTab(),
                  _buildCategoriesTab(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _filters = SearchFilters();
                            // no-op
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<SearchViewModel>().searchWithFilters(_filters);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    const categories = [
      'Electronics',
      'Furniture',
      'Clothing',
      'Books',
      'Sports',
      'Toys',
      'Home & Garden',
      'Automotive',
      'Other',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final isSelected = _filters.category == category;
            return FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _filters = _filters.copyWith(
                    category: selected ? category : null,
                  );
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }


  Widget _buildConditionFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Condition',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('New'),
              selected: _filters.isUsed == false,
              onSelected: (selected) {
                setState(() {
                  _filters = _filters.copyWith(isUsed: selected ? false : null);
                });
              },
            ),
            FilterChip(
              label: const Text('Used'),
              selected: _filters.isUsed == true,
              onSelected: (selected) {
                setState(() {
                  _filters = _filters.copyWith(isUsed: selected ? true : null);
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: 'City, State',
            hintText: 'e.g., New York, NY',
          ),
          onChanged: (value) {
            setState(() {
              _filters = _filters.copyWith(location: value.isEmpty ? null : value);
            });
          },
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () async {
            await context.read<SearchViewModel>().setUserLocation();
            setState(() {
              _filters = context.read<SearchViewModel>().currentFilters;
            });
          },
          icon: const Icon(Icons.my_location),
          label: const Text('Use Current Location'),
        ),
      ],
    );
  }

  Widget _buildDistanceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distance',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        StatefulBuilder(builder: (context, setSt) {
          final radius = _filters.radius;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Slider(
                min: 1,
                max: 100,
                divisions: 99,
                value: radius,
                label: '${radius.round()} miles',
                onChanged: (val) {
                  setSt(() {
                    _filters = _filters.copyWith(radius: val);
                  });
                },
              ),
              Text('${radius.round()} miles', style: TextStyle(color: Colors.grey[700])),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildDateFilter() {
    const options = [
      {'label': 'All time', 'value': 'all'},
      {'label': 'Today', 'value': 'today'},
      {'label': 'This week', 'value': 'thisWeek'},
      {'label': 'This month', 'value': 'thisMonth'},
      {'label': 'Last week', 'value': 'lastWeek'},
      {'label': 'Last month', 'value': 'lastMonth'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Posted',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...options.map((opt) => RadioListTile<String>(
              title: Text(opt['label']!),
              value: opt['value']!,
              groupValue: _filters.dateFilter.name,
              onChanged: (value) {
                setState(() {
                  _filters = _filters.copyWith(dateFilter: DateFilter.values.firstWhere((e) => e.name == value));
                });
              },
            )),
      ],
    );
  }

  Widget _buildSortFilter() {
    const sortOptions = [
      {'value': 'relevance', 'label': 'Most Relevant'},
      {'value': 'date_new', 'label': 'Newest First'},
      {'value': 'date_old', 'label': 'Oldest First'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sort By',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...sortOptions.map((option) => RadioListTile<String>(
          title: Text(option['label']!),
          value: option['value']!,
          groupValue: _filters.sortBy.name,
          onChanged: (value) {
            setState(() {
              _filters = _filters.copyWith(sortBy: SortBy.values.firstWhere((e) => e.name == value));
            });
          },
        )),
      ],
    );
  }

  Widget _buildFiltersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryFilter(),
          const SizedBox(height: 24),
          _buildConditionFilter(),
          const SizedBox(height: 24),
          _buildLocationFilter(),
          const SizedBox(height: 24),
          _buildDistanceFilter(),
          const SizedBox(height: 24),
          _buildDateFilter(),
          const SizedBox(height: 24),
          _buildSortFilter(),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    const mainCategories = [
      'Electronics',
      'Furniture',
      'Clothing',
      'Books',
      'Sports',
      'Toys',
      'Home & Garden',
      'Automotive',
      'Other',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Main Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mainCategories.map((category) {
              final isSelected = _filters.category == category;
              return FilterChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _filters = _filters.copyWith(
                      category: selected ? category : 'All',
                    );
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
