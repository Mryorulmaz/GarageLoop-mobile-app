import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'product_detail_view_model.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_repository.dart';
import '../profile/credit_center_screen.dart';
import '../profile/profile_screen.dart';
import '../core/widgets/skeleton_loading.dart';
import '../core/widgets/location_map.dart';
import '../core/widgets/ad_banner.dart';
import '../../lib_navigation.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  static const Color primaryBlue = Color(0xFF1A237E);
  static const Color primaryNavy = Color(0xFF1A237E);
  static const Color accentOrange = Color(0xFFFF8C00);


  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProductDetailViewModel>(
      create: (_) => ProductDetailViewModel(productId: productId),
      child: Consumer<ProductDetailViewModel>(
        builder: (context, vm, child) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              title: Text(
                'Product Details',
                style: GoogleFonts.openSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              backgroundColor: ProductDetailScreen.primaryBlue,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [],
            ),
            body: Stack(
              children: [
                const _ProductDetailBody(),
                _BottomActions(productId: productId),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<void> _showSignInPrompt(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Please sign in'),
      content: const Text(
        'This action requires an account. You can browse as a guest, but to continue please create an account or sign in.'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            AppNavigator.toAuth(context);
          },
          child: const Text('Sign in'),
        ),
      ],
    ),
  );
}

class _ProductDetailBody extends StatelessWidget {
  const _ProductDetailBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductDetailViewModel>(
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
                  'Error loading product',
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
              ],
            ),
          );
        }

        return RepaintBoundary(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100), // Space for bottom button
            child: Column(
              children: [
              // Product images
              _ProductImageGallery(images: vm.product?.images ?? []),
              
              // Product info card
              _ProductInfoCard(product: vm.product),
              
              // Banner: kullanıcı adı ile açıklama arasında (göze çarpmayan)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: InlineBanner(),
              ),
              
            // Giver info card
              _SellerInfoCard(seller: vm.product?.seller),
              
              // Location map card
              if (vm.product?.latitude != null && vm.product?.longitude != null)
                LocationMapCard(
                  latitude: vm.product!.latitude!,
                  longitude: vm.product!.longitude!,
                  locationName: vm.product!.title,
                  address: vm.product!.address,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductImageGallery extends StatefulWidget {
  const _ProductImageGallery({required this.images});

  final List<String> images;

  @override
  State<_ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<_ProductImageGallery> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
        color: Colors.grey.shade200,
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 64,
            color: Colors.grey.shade400,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Main image viewer (tabletlerde daha büyük)
        SizedBox(
          height: MediaQuery.sizeOf(context).width > 600 ? 420 : 300,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemCount: widget.images.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _FullscreenGallery(
                            images: widget.images,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.images[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SkeletonLoading(
                            borderRadius: BorderRadius.circular(12),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    ),
                  );
                },
              ),
              // Image counter
              if (widget.images.length > 1)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      // 0.6 opacity -> alpha 153
                      color: Colors.black.withAlpha((0.6 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Thumbnail strip
        if (widget.images.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: MediaQuery.sizeOf(context).width > 600 ? 80 : 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                final isSelected = index == _currentIndex;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? ProductDetailScreen.primaryBlue : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(
                        widget.images[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SkeletonLoading(
                            borderRadius: BorderRadius.circular(7),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.error_outline,
                              size: 20,
                              color: Colors.grey.shade400,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}


class _FullscreenGallery extends StatefulWidget {
  const _FullscreenGallery({required this.images, this.initialIndex = 0});
  final List<String> images;
  final int initialIndex;

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, (widget.images.length - 1).clamp(0, 9999));
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_index + 1}/${widget.images.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        onPageChanged: (i) => setState(() => _index = i),
        itemCount: widget.images.length,
        itemBuilder: (context, i) {
          final url = widget.images[i];
          return InteractiveViewer(
            maxScale: 4,
            child: SizedBox.expand(
              child: Image.network(
                url,
                fit: BoxFit.contain, // oranı koru ve ekranı doldur
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductInfoCard extends StatelessWidget {
  const _ProductInfoCard({this.product});

  final ProductDetail? product;

  String _getConditionText(ProductDetail product) {
    if (product.condition != null && product.condition!.isNotEmpty) {
      return product.condition!;
    }
    return 'New';
  }

  Color _getConditionColor(ProductDetail product) {
    if (product.condition != null && product.condition!.isNotEmpty) {
      switch (product.condition!.toLowerCase()) {
        case 'new':
          return Colors.green.shade700;
        case 'like new':
          return Colors.blue.shade700;
        case 'good':
          return Colors.orange.shade700;
        default:
          return Colors.grey.shade700;
      }
    }
    return Colors.green.shade700;
  }

  Color _getConditionBackgroundColor(ProductDetail product) {
    if (product.condition != null && product.condition!.isNotEmpty) {
      switch (product.condition!.toLowerCase()) {
        case 'new':
          return Colors.green.shade100;
        case 'like new':
          return Colors.blue.shade100;
        case 'good':
          return Colors.orange.shade100;
        default:
          return Colors.grey.shade100;
      }
    }
    return Colors.green.shade100;
  }

  @override
  Widget build(BuildContext context) {
    if (product == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with action buttons
          Row(
            children: [
              Expanded(
                child: Text(
                  product!.title,
                  style: GoogleFonts.openSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Action buttons
              Consumer<ProductDetailViewModel>(
                builder: (context, vm, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Butonlar yan yana
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Share button
                          IconButton(
                            onPressed: () {
                              final id = vm.product?.id ?? '';
                              final link = 'https://garageloop.app/item/$id';
                              Clipboard.setData(ClipboardData(text: link));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Share link copied')),
                              );
                            },
                            icon: Icon(Icons.share, color: Colors.grey.shade600, size: 28),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Favorite button
                          IconButton(
                            onPressed: () {
                              final currentUser = FirebaseAuth.instance.currentUser;
                              if (currentUser == null) {
                                _showSignInPrompt(context);
                              } else {
                                vm.toggleFavorite();
                              }
                            },
                            icon: Icon(
                              vm.isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: vm.isFavorite ? Colors.red : Colors.grey.shade600,
                              size: 28,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Beğeni sayısı kalbin altında
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const SizedBox(width: 55), // 5px daha sağa kaydır
                          Text(
                            '${vm.product?.favoritesCount ?? 0}',
                            style: GoogleFonts.openSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Free badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'FREE',
              style: GoogleFonts.openSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          
          // Location + condition badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.location_on, color: Colors.grey.shade600, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  product!.distanceMiles == 0.0
                    ? (product!.address?.isNotEmpty == true ? product!.address! : 'Location unknown')
                    : product!.distanceMiles < 0.1
                      ? '${(product!.distanceMiles * 10).toStringAsFixed(1)} miles away'
                      : product!.distanceMiles < 1.0
                        ? '${product!.distanceMiles.toStringAsFixed(2)} miles away'
                        : '${product!.distanceMiles.toStringAsFixed(1)} miles away',
                  style: GoogleFonts.openSans(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getConditionBackgroundColor(product!),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _getConditionText(product!),
                  style: GoogleFonts.openSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getConditionColor(product!),
                  ),
                ),
              ),
            ],
          ),

          // Published date (separate row between location and description)
          const SizedBox(height: 8),
          Text(
            _dateTag(product!.createdAt),
            style: GoogleFonts.openSans(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),

          // More space before description for clean layout
          const SizedBox(height: 24),
          
          // Description
          Text(
            'Description',
            style: GoogleFonts.openSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product!.description,
            style: GoogleFonts.openSans(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
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

class _SellerInfoCard extends StatelessWidget {
  const _SellerInfoCard({this.seller});

  final SellerInfo? seller;

  @override
  Widget build(BuildContext context) {
    if (seller == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () {
        final sellerId = seller!.id;
        if (sellerId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfileScreenForUser(userId: sellerId, userName: seller!.name)),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              // 0.05 opacity -> alpha 13
              color: Colors.black.withAlpha((0.05 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Giver avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: ProductDetailScreen.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getInitials(seller!.name),
                  style: GoogleFonts.openSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Giver info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seller!.name,
                    style: GoogleFonts.openSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Member since ${seller!.memberSince}',
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Shares count only
            Text(
              seller!.salesCount == 0 
                ? 'New giver' 
                : '${seller!.salesCount} ${seller!.salesCount == 1 ? 'share' : 'shares'}',
              style: GoogleFonts.openSans(
                fontSize: 12,
                color: seller!.salesCount == 0 ? Colors.orange : Colors.grey.shade600,
                fontWeight: seller!.salesCount == 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'G';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              // 0.1 opacity -> alpha 26
              color: Colors.black.withAlpha((0.1 * 255).round()),
               blurRadius: 10,
               offset: const Offset(0, -2),
             ),
           ],
         ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async => _handleChatTap(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Send Message',
                    style: GoogleFonts.openSans(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleChatTap(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await _showSignInPrompt(context);
      return;
    }

    final vm = context.read<ProductDetailViewModel>();
    final seller = vm.product?.seller;
    final otherUserId = seller?.id;
    if (otherUserId == null || otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller not found.')),
      );
      return;
    }

    if (otherUserId == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot message yourself.')),
      );
      return;
    }

    final chatRepo = ChatRepository();
    final existingConversationId = await chatRepo.findExistingConversation(otherUserId);

    if (existingConversationId == null) {
      final confirmed = await _confirmUnlockChat(context);
      if (confirmed != true) return;
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: otherUserId,
          otherUserName: seller?.name ?? 'Unknown Giver',
        ),
      ),
    );
  }

  Future<void> _showInsufficientCredits(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Not enough credits'),
        content: const Text('You need 5 credits to unlock this chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CreditCenterScreen()),
              );
            },
            child: const Text('Get credits'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmUnlockChat(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlock chat?'),
        content: const Text('Your first message to this seller costs 5 credits. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

}

