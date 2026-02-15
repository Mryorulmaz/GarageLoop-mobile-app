import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'favorites_view_model.dart';
import '../product/product_detail_screen.dart';
import '../core/widgets/ad_banner.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  static const Color primaryBlue = Color(0xFF1A237E);
  static const Color primaryNavy = Color(0xFF1A237E);
  static const Color accentOrange = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FavoritesViewModel>(
      create: (_) => FavoritesViewModel(),
      child: const _FavoritesContent(),
    );
  }
}

class _FavoritesContent extends StatelessWidget {
  const _FavoritesContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'My Favorites',
          style: GoogleFonts.openSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: FavoritesScreen.primaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Consumer<FavoritesViewModel>(
            builder: (context, vm, child) {
              if (vm.favorites.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: () => _showClearAllDialog(context, vm),
              );
            },
          ),
        ],
      ),
      body: const _FavoritesBody(),
    );
  }

  void _showClearAllDialog(BuildContext context, FavoritesViewModel vm) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Clear All Favorites',
            style: GoogleFonts.openSans(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to remove all items from your favorites?',
            style: GoogleFonts.openSans(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.openSans(color: Colors.grey.shade600),
              ),
            ),
            TextButton(
              onPressed: () {
                vm.clearAllFavorites();
                Navigator.of(context).pop();
              },
              child: Text(
                'Clear All',
                style: GoogleFonts.openSans(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FavoritesBody extends StatelessWidget {
  const _FavoritesBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesViewModel>(
      builder: (context, vm, child) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error loading favorites',
                  style: GoogleFonts.openSans(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  vm.error!,
                  style: GoogleFonts.openSans(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => vm.loadFavorites(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FavoritesScreen.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (vm.favorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
              Text(
                'No favorites yet',
                style: GoogleFonts.openSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go back'),
              ),
                const SizedBox(height: 8),
                Text(
                  'Items you favorite will appear here',
                  style: GoogleFonts.openSans(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FavoritesScreen.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.explore),
                  label: Text(
                    'Explore Products',
                    style: GoogleFonts.openSans(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header with count
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '${vm.favorites.length} item${vm.favorites.length == 1 ? '' : 's'}',
                    style: GoogleFonts.openSans(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Swipe to remove',
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Favorites list - her 4 üründe bir banner
            Expanded(
              child: RepaintBoundary(
                child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: vm.favorites.length + (vm.favorites.length / 4).floor(),
                itemBuilder: (context, index) {
                  // Banner slot: 4, 9, 14, ... (her 5. item, 0-based)
                  if (index >= 4 && (index - 4) % 5 == 0) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: InlineBanner(),
                    );
                  }
                  final productIndex = index - ((index + 1) ~/ 5);
                  final product = vm.favorites[productIndex];
                  return Selector<FavoritesViewModel, FavoriteProduct>(
                    selector: (_, m) => m.favorites[productIndex],
                    builder: (context, p, __) => _FavoriteProductCard(
                      product: p,
                      onRemove: () => context.read<FavoritesViewModel>().removeFavorite(p.id),
                    ),
                  );
                },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FavoriteProductCard extends StatelessWidget {
  const _FavoriteProductCard({
    required this.product,
    required this.onRemove,
  });

  final FavoriteProduct product;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 24,
        ),
      ),
      onDismissed: (direction) => onRemove(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProductDetailScreen(productId: product.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Product image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(product.imageUrl),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        // Handle error silently
                      },
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: GoogleFonts.openSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Free',
                        style: GoogleFonts.openSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.grey.shade600, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${product.distanceMiles.toStringAsFixed(0)} miles away',
                            style: GoogleFonts.openSans(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Favorite icon
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

