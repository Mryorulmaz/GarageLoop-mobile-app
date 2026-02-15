import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../core/data/us_locations.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

import 'home_view_model.dart';
import 'filters/filters_sheet.dart';
import 'models/search_filters.dart';
import 'models/listing.dart';
import 'models/sort_option.dart';
import 'models/home_product.dart';
import '../sell/sell_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/credit_center_screen.dart';
import '../auth/presentation/auth_screen.dart';
import '../product/product_detail_screen.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_list_view_model.dart';
import '../chat/chat_repository.dart';
import '../core/widgets/offline_banner.dart';
import '../core/widgets/optimized_image.dart';
import '../core/widgets/ad_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color primaryNavy = Color(0xFF1A237E);
  static const Color accentOrange = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (_) => HomeViewModel()..initialize(),
      child: const _HomeContent(),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Offline banner
            const OfflineBanner(),
            _Header(vm: vm),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _CategoryStrip(vm: vm),
                    const SizedBox(height: 16),
                    _ProductGrid(vm: vm),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
int getUnreadFor(ChatListViewModel vm, ChatConversation c) {
  // Helper to avoid import cycle; mirrors vm.getUnreadCount
  final uid = vm.currentUserId;
  if (uid == null) return 0;
  final raw = c.unreadCounts[uid];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return 0;
}

class _Header extends StatelessWidget {
  const _Header({required this.vm});
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top row: Logo and buttons
          Row(
            children: [
              // Logo
              Text(
                'GarageLoop',
                style: GoogleFonts.robotoSlab(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: HomeScreen.primaryNavy,
                ),
              ),
              const SizedBox(width: 8),
              const Spacer(),
              const _CreditsBadge(),
              const SizedBox(width: 0),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile button
                  IconButton(
                    onPressed: () {
                      _guardAuth(context, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen())));
                    },
                    icon: Icon(Icons.person_outline, color: Colors.grey.shade600, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    visualDensity: VisualDensity.compact,
                  ),
                  // Chat button with green dot for unread
                  Transform.translate(
                    offset: const Offset(-6, 0),
                    child: ChangeNotifierProvider<ChatListViewModel>(
                      create: (_) => ChatListViewModel(),
                      child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                      IconButton(
                        onPressed: () {
                          _guardAuth(
                            context,
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const ChatListScreen()),
                            ),
                          );
                        },
                        icon: Icon(Icons.chat_bubble_outline, color: Colors.grey.shade600, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        visualDensity: VisualDensity.compact,
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Consumer<ChatListViewModel>(
                          builder: (context, chatVm, _) {
                            final totalUnread = chatVm.conversations.fold<int>(0, (sum, c) => sum + getUnreadFor(chatVm, c));
                            if (totalUnread <= 0) return const SizedBox.shrink();
                            return Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            );
                          },
                        ),
                      ),
                      ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 0),
                  // Share button
                  ElevatedButton.icon(
                    onPressed: () {
                      _guardAuth(context, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SellScreen())));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HomeScreen.primaryNavy,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      minimumSize: const Size(64, 36),
                    ),
                    icon: const Icon(Icons.camera_alt, size: 14),
                    label: const Text('Share', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.search, color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: vm.updateSearch,
                    decoration: InputDecoration(
                      hintText: 'Search free items...',
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showSortOptions(context, vm),
                  icon: Icon(Icons.sort, color: Colors.grey.shade600, size: 20),
                ),
                IconButton(
                  onPressed: () => _showFilters(context, vm),
                  icon: Icon(Icons.tune, color: Colors.grey.shade600, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Location selector
          GestureDetector(
            onTap: () => _showLocationPicker(context),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey.shade600, size: 16),
                const SizedBox(width: 4),
                Text(
                  vm.currentLocationLabel,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600, size: 16),
              ],
            ),
          ),
          // USA action kaldırıldı; Location Picker içine taşınacak
        ],
      ),
    );
  }

  void _guardAuth(BuildContext context, VoidCallback onAuthed) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      onAuthed();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Please sign in'),
        content: const Text('This action requires an account. You can browse as guest, but to continue please create an account or sign in.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  void _showFilters(BuildContext context, HomeViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => FiltersSheet(
        currentFilters: SearchFilters(
          query: vm.searchQuery,
          category: vm.selectedCategory,
          condition: vm.condition == 'used'
              ? ProductCondition.used
              : (vm.condition == 'new'
                  ? ProductCondition.newItem
                  : (vm.condition == 'likeNew'
                      ? ProductCondition.likeNew
                      : null)),
          radius: vm.maxDistanceMiles,
          dateFilter: _mapDateFilter(vm.dateFilter),
          sortBy: _mapSortOption(vm.sort),
        ),
        onApplyFilters: (filters) {
          vm.setSearchQuery(filters.query);
          vm.setCategory(filters.category);
          vm.setMaxDistance(filters.radius);
          
          // Condition filter mapping
          switch (filters.condition) {
            case ProductCondition.newItem:
              vm.setCondition('new');
              break;
            case ProductCondition.likeNew:
              vm.setCondition('likeNew');
              break;
            case ProductCondition.used:
              vm.setCondition('used');
              break;
            case null:
              vm.setCondition('all');
              break;
          }
        },
      ),
    );
  }

  DateFilter _mapDateFilter(String dateFilter) {
    switch (dateFilter) {
      case 'today':
        return DateFilter.today;
      case 'week':
        return DateFilter.thisWeek;
      case 'month':
        return DateFilter.thisMonth;
      default:
        return DateFilter.all;
    }
  }

  SortBy _mapSortOption(SortOption sort) {
    switch (sort) {
      case SortOption.newest:
        return SortBy.newest;
      case SortOption.nearest:
        return SortBy.nearest;
      default:
        return SortBy.relevance;
    }
  }

  void _showSortOptions(BuildContext context, HomeViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SortOptionsSheet(vm: vm),
    );
  }

  void _showLocationPicker(BuildContext context) {
    final vm = context.read<HomeViewModel>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _LocationPickerSheet(vm: vm),
    );
  }
}

class _CreditsBadge extends StatelessWidget {
  const _CreditsBadge();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final credits = (data?['credits'] as num?)?.toInt() ?? 0;

        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CreditCenterScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: HomeScreen.primaryNavy,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _MiniGlossyCoinIcon(size: 18),
                const SizedBox(width: 6),
                Text(
                  credits.toString(),
                  style: GoogleFonts.openSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniGlossyCoinIcon extends StatelessWidget {
  const _MiniGlossyCoinIcon({required this.size, this.useNavyBase = false});
  final double size;
  final bool useNavyBase;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: useNavyBase ? HomeScreen.primaryNavy : null,
              gradient: useNavyBase
                  ? null
                  : const RadialGradient(
                      colors: [
                        Color(0xFFFFF1D6),
                        Color(0xFFFFC46B),
                        Color(0xFFFF9B2A),
                        Color(0xFFFF7A00),
                      ],
                      stops: [0.0, 0.45, 0.75, 1.0],
                    ),
            ),
          ),
          Positioned.fill(
            child: Container(
              margin: EdgeInsets.all(size * 0.12),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFE2B2), Color(0xFFFFB348)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: size * 0.16,
            left: size * 0.18,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ),
          Center(
            child: Text(
              'C',
              style: GoogleFonts.openSans(
                fontSize: size * 0.55,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF6B3A00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.vm});
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) {
          final category = vm.categories[i];
          final isSelected = vm.selectedCategory == category;
          return GestureDetector(
            onTap: () => vm.setCategory(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? HomeScreen.primaryNavy : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? HomeScreen.primaryNavy : Colors.grey.shade300,
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: vm.categories.length,
      ),
    );
  }
}

Widget _buildProductCell(BuildContext context, HomeViewModel vm, HomeProduct product, double crossSpacing, double mainSpacing, double aspectRatio) {
  return GestureDetector(
    onTap: () {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(productId: product.id),
        ),
      );
    },
    child: AspectRatio(
      aspectRatio: aspectRatio,
      child: _ProductCard(product: product),
    ),
  );
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.vm});
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (vm.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                vm.error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => vm.initialize(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    final products = vm.filteredProducts;
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No products found',
                style: GoogleFonts.openSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters or check back later for new listings',
                style: GoogleFonts.openSans(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Reset filters
                  vm.setSearchQuery('');
                  vm.setCategory('All');
                  // Price filters removed (free-only marketplace)
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeScreen.primaryNavy,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final crossSpacing = 12.0;
    const mainSpacing = 16.0;
    const childAspectRatio = 0.60;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int blockStart = 0; blockStart < products.length; blockStart += 4) ...[
            // İlk iki ürün (üst satır)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: blockStart < products.length ? _buildProductCell(context, vm, products[blockStart], crossSpacing, mainSpacing, childAspectRatio) : const SizedBox.shrink()),
                  SizedBox(width: crossSpacing),
                  Expanded(child: blockStart + 1 < products.length ? _buildProductCell(context, vm, products[blockStart + 1], crossSpacing, mainSpacing, childAspectRatio) : AspectRatio(aspectRatio: childAspectRatio, child: const SizedBox.shrink())),
                ],
              ),
            ),
            SizedBox(height: mainSpacing),
            // İkinci iki ürün (alt satır)
            if (blockStart + 2 < products.length)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildProductCell(context, vm, products[blockStart + 2], crossSpacing, mainSpacing, childAspectRatio)),
                    SizedBox(width: crossSpacing),
                    Expanded(child: blockStart + 3 < products.length ? _buildProductCell(context, vm, products[blockStart + 3], crossSpacing, mainSpacing, childAspectRatio) : AspectRatio(aspectRatio: childAspectRatio, child: const SizedBox.shrink())),
                  ],
                ),
              ),
            if (blockStart + 2 < products.length) SizedBox(height: mainSpacing),
            // Her 4 üründe bir banner (blok sonunda)
            if (blockStart + 4 <= products.length) const InlineBanner(),
            if (blockStart + 4 <= products.length) SizedBox(height: mainSpacing),
          ],
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final HomeProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Image (fills remaining space so text sits at the bottom edge)
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                color: Colors.white,
                width: double.infinity,
                alignment: Alignment.center,
                child: product.imageUrl.isNotEmpty
                    ? OptimizedImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorWidget: Container(
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                        placeholder: Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : Container(color: Colors.grey.shade100),
              ),
            ),
          ),

          // Product info
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                  // Free badge (highlight)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'FREE',
                      style: GoogleFonts.openSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                  
                  // Title
                  Text(
                    product.title.length > 25 
                      ? '${product.title.substring(0, 25)}...'
                      : product.title,
                    style: GoogleFonts.openSans(
                    fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withValues(alpha: 0.82),
                    height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 6),
                  
                  // Location and time
                  Row(
                  mainAxisSize: MainAxisSize.min,
                    children: [
                    Icon(Icons.location_on, color: Colors.grey.shade600, size: 11),
                      const SizedBox(width: 2),
                    Flexible(
                      flex: 2,
                        child: Text(
                          product.distanceMiles == 0.0 
                            ? (product.locality ?? 'Location unknown')
                            : '${product.distanceMiles.toStringAsFixed(1)} miles away',
                          style: TextStyle(
                          fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        ),
                      ),
                    const SizedBox(width: 3),
                    Text('·', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                    const SizedBox(width: 3),
                    Flexible(
                      flex: 1,
                      child: Text(
                        _dateTag(product.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateTag(DateTime createdAt) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime thatDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final int days = today.difference(thatDay).inDays;

    if (days <= 0) return 'TODAY';
    if (days == 1) return 'YESTERDAY';
    if (days < 7) return '$days days ago';

    final int weeks = days ~/ 7;
    if (days < 30) {
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    }

    final int months = days ~/ 30;
    if (days < 365) {
      return months == 1 ? '1 month ago' : '$months months ago';
    }

    final int years = days ~/ 365;
    return years == 1 ? '1 year ago' : '$years years ago';
  }
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({required this.vm});
  final HomeViewModel vm;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  String? _selectedState;
  String? _selectedCity;
  bool _isLoading = false;

  List<String> get _states => USLocations.states;
  List<String> get _cities => _selectedState == null
      ? <String>[]
      : USLocations.getCitiesForState(_selectedState!);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Location',
            style: GoogleFonts.openSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          
          // Use Current Location Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _useCurrentLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeScreen.accentOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
              label: Text(
                _isLoading ? 'Getting location...' : 'Use Current Location',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Manual Selection
          Text(
            'Or select manually:',
            style: GoogleFonts.openSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          
          // State Dropdown
          DropdownButtonFormField<String>(
            value: _selectedState,
            decoration: InputDecoration(
              labelText: 'State',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            items: _states.map((state) {
              return DropdownMenuItem(value: state, child: Text(state));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedState = value;
                _selectedCity = null; // Reset city when state changes
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // City Dropdown
          DropdownButtonFormField<String>(
            value: _selectedCity,
            decoration: InputDecoration(
              labelText: 'City',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            items: _selectedState != null 
              ? _cities.map((city) {
                  return DropdownMenuItem(value: city, child: Text(city));
                }).toList()
              : [],
          onChanged: _selectedState != null ? (value) {
              setState(() {
                _selectedCity = value;
              });
            } : null,
          ),
          
          const SizedBox(height: 24),
          
          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // State veya City seçiliyse yeterli
              onPressed: (_selectedState != null || _selectedCity != null) ? _applyLocation : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeScreen.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: const Text(
                'Apply Location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          
          const SizedBox(height: 20),

      // Show all USA (clear location)
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            widget.vm.clearStateCityFilter();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Showing all USA listings')),
            );
          },
          icon: const Icon(Icons.public),
          label: const Text('Show All USA'),
        ),
      ),
        ],
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);
    
    try {
      await widget.vm.initialize(); // This will get current location
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated to current location'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyLocation() {
    // 3 senaryo: sadece state, sadece city, ikisi birden
    if (_selectedState == null && _selectedCity == null) return;

    final String? cityOnly = _selectedCity?.split(',').first.trim();
    final String label = (_selectedState != null && cityOnly != null && cityOnly.isNotEmpty)
        ? '$cityOnly, $_selectedState'
        : (cityOnly != null && cityOnly.isNotEmpty)
            ? cityOnly
            : _selectedState!;

    () async {
      try {
        // Geocoding hedefi oluştur
        final String query = (_selectedState != null && cityOnly != null && cityOnly.isNotEmpty)
            ? '$cityOnly, ${_selectedState!}, USA'
            : (cityOnly != null && cityOnly.isNotEmpty)
                ? '$cityOnly, USA'
                : '${_selectedState!}, USA';
        final List<geocoding.Location> res = await geocoding.locationFromAddress(query);
        if (res.isNotEmpty) {
          final loc = res.first;
          widget.vm.setManualLocation(label, loc.latitude, loc.longitude);
        } else {
          widget.vm.setLocationFilter(label);
        }
      } catch (_) {
        widget.vm.setLocationFilter(label);
      }

      // Server-side: yalnız state varsa state’e göre; city varsa city adı client-side eşleşecek
      widget.vm.applyStateCityFilter(state: _selectedState ?? '', city: cityOnly);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location set to $label'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }();
  }
  
}

class _SortOptionsSheet extends StatelessWidget {
  const _SortOptionsSheet({required this.vm});
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sort By',
            style: GoogleFonts.openSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),

          ),
          const SizedBox(height: 16),
          ...<SortOption>[
            SortOption.newest,
            SortOption.nearest,
          ].map((option) => _SortOptionTile(
            option: option,
            isSelected: vm.sort == option,
            onTap: () {
              vm.setSort(option);
              Navigator.pop(context);
            },
          )),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final SortOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? HomeScreen.primaryNavy : Colors.grey,
      ),
      title: Text(
        _getSortOptionText(option),
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? HomeScreen.primaryNavy : Colors.black87,
        ),
      ),
      onTap: onTap,
    );
  }

  String _getSortOptionText(SortOption option) {
    switch (option) {
      case SortOption.nearest:
        return 'Nearest First';
      case SortOption.newest:
        return 'Newest First';
      case SortOption.lowestPrice:
      case SortOption.highestPrice:
        return 'Newest First';
    }
  }
}