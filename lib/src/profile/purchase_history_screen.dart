import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../product/product_detail_screen.dart';
import '../chat/chat_screen.dart';
import '../rating/rating_screen.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Sharing History',
          style: GoogleFonts.openSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryNavy,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filter options coming soon')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryNavy,
              labelColor: AppTheme.primaryNavy,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: GoogleFonts.openSans(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Claims'),
                Tab(text: 'Gives'),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PurchasesTab(),
                _SalesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchasesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // No dummy data - only real transactions from Firestore
    final purchases = <_TransactionItem>[];

    return _buildTransactionList(purchases, context);
  }
}

class _SalesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // No dummy data - only real transactions from Firestore
    final sales = <_TransactionItem>[];

    return _buildTransactionList(sales, context);
  }
}

Widget _buildTransactionList(List<_TransactionItem> transactions, BuildContext context) {
  if (transactions.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.volunteer_activism_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
            Text(
              'No activity yet',
              style: GoogleFonts.openSans(
                fontSize: 16,
                color: Colors.grey.shade600,
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
            'Your sharing history will appear here',
            style: GoogleFonts.openSans(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  return ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: transactions.length,
    separatorBuilder: (context, index) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      final transaction = transactions[index];
      return _TransactionCard(transaction: transaction);
    },
  );
}

class _TransactionItem {
  final String id;
  final String title;
  final String price;
  final String date;
  final String status;
  final String imageUrl;
  final String? sellerName = null;
  final String? buyerName = null;
  final bool isPurchase;

  _TransactionItem({
    required this.id,
    required this.title,
    required this.price,
    required this.date,
    required this.status,
    required this.imageUrl,
    required this.isPurchase,
  });
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});
  final _TransactionItem transaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(transaction.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: GoogleFonts.openSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.isPurchase 
                          ? 'From: ${transaction.sellerName ?? 'Giver'}'
                          : 'To: ${transaction.buyerName ?? 'Claimer'}',
                        style: GoogleFonts.openSans(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.date,
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Price and status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      transaction.price,
                      style: GoogleFonts.openSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: transaction.isPurchase 
                          ? Colors.green.shade600 
                          : Colors.blue.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        transaction.status,
                        style: GoogleFonts.openSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(productId: transaction.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryNavy,
                      side: const BorderSide(color: AppTheme.primaryNavy),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final contactName = transaction.isPurchase 
                          ? transaction.sellerName 
                          : transaction.buyerName;
                      if (contactName != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              otherUserId: 'user_${transaction.id}', // Mock user ID
                              otherUserName: contactName,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.chat_outlined, size: 16),
                    label: const Text('Contact'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final targetName = transaction.isPurchase 
                          ? transaction.sellerName 
                          : transaction.buyerName;
                      final targetId = 'user_${transaction.id}'; // Mock user ID
                      
                      if (targetName != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RatingScreen(
                              targetUserId: targetId,
                              targetUserName: targetName,
                              listingId: transaction.id,
                              listingTitle: transaction.title,
                              isBuyerRating: transaction.isPurchase,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.star_outline, size: 16),
                    label: const Text('Rate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
