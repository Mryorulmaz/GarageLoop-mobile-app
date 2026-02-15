import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../sell/sell_screen.dart';
import 'credit_center_view_model.dart';

class CreditCenterScreen extends StatelessWidget {
  const CreditCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Credit Center'),
          backgroundColor: AppTheme.primaryNavy,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: const Center(child: Text('Please sign in to view credits.')),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => CreditCenterViewModel(userId: user.uid),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Credit Center'),
          backgroundColor: AppTheme.primaryNavy,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final credits = (data?['credits'] as num?)?.toInt() ?? 0;
            final premiumExpiresAt = (data?['premiumExpiresAt'] as Timestamp?)?.toDate();
            final isPremium = data?['isPremium'] == true &&
                (premiumExpiresAt == null || premiumExpiresAt.isAfter(DateTime.now()));

            return Consumer<CreditCenterViewModel>(
              builder: (context, vm, _) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Hata/info banner'ları kaldırıldı - gerçek app'te teknik uyarılar gösterilmez
                    _BalanceCard(
                      credits: credits,
                      isPremium: isPremium,
                      premiumExpiresAt: premiumExpiresAt,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const _WalletBalanceScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _CreditActionCard(
                      title: 'Earn Credits',
                      subtitle: 'Watch ads to earn credits',
                      icon: Icons.play_circle_fill,
                      onTap: () {
                        final vm = context.read<CreditCenterViewModel>();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: vm,
                              child: const _EarnCreditsScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _CreditActionCard(
                      title: 'Buy Credits',
                      subtitle: 'Choose a credit pack',
                      icon: Icons.shopping_bag,
                      onTap: () {
                        final vm = context.read<CreditCenterViewModel>();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: vm,
                              child: const _BuyCreditsScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _CreditActionCard(
                      title: 'Premium',
                      subtitle: 'Weekly, monthly, or yearly plans',
                      icon: Icons.workspace_premium,
                      onTap: () {
                        final vm = context.read<CreditCenterViewModel>();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: vm,
                              child: const _PremiumPlansScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.isError,
    required this.onClose,
  });

  final String message;
  final bool isError;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.info_outline, color: color.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.openSans(fontSize: 12, color: color.shade800),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Icon(Icons.close, color: color.shade700, size: 16),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.credits,
    required this.isPremium,
    required this.premiumExpiresAt,
    required this.onTap,
  });

  final int credits;
  final bool isPremium;
  final DateTime? premiumExpiresAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const _GlossyCoinIcon(size: 52),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Credits Balance',
                    style: GoogleFonts.openSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    credits.toString(),
                    style: GoogleFonts.openSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentOrange,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Premium',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentOrange,
                        ),
                      ),
                      if (premiumExpiresAt != null)
                        Text(
                          'Renews ${_formatDate(premiumExpiresAt!)}',
                          style: GoogleFonts.openSans(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                          ),
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

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.openSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade700,
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final Widget title;
  final Widget subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryNavy),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: GoogleFonts.openSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      child: title,
                    ),
                    const SizedBox(height: 4),
                    subtitle,
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditActionCard extends StatelessWidget {
  const _CreditActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryNavy, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.openSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B1E2B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.openSans(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
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
}

class _EarnCreditsScreen extends StatelessWidget {
  const _EarnCreditsScreen();

  static const List<_EarnTask> _tasks = [
    _EarnTask(
      title: 'Watch Video',
      subtitle: 'Earn 1 credit per video',
      credits: 1,
    ),
    _EarnTask(
      title: 'Share an Item',
      subtitle: 'Post a new share to earn 5 credits',
      credits: 5,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Earn Credits'),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Consumer<CreditCenterViewModel>(
        builder: (context, vm, _) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return Padding(
                padding: EdgeInsets.only(bottom: index == _tasks.length - 1 ? 0 : 14),
                child: _EarnTaskCard(
                  task: task,
                  onTap: () async {
                    if (task.title == 'Share an Item') {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const SellScreen()),
                      );
                      return;
                    }
                    await vm.showRewardedAd();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EarnTask {
  const _EarnTask({
    required this.title,
    required this.subtitle,
    required this.credits,
  });
  final String title;
  final String subtitle;
  final int credits;
}

class _EarnTaskCard extends StatelessWidget {
  const _EarnTaskCard({required this.task, required this.onTap});
  final _EarnTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _EarnCreditsInline(credits: task.credits),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: GoogleFonts.openSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1B1E2B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.subtitle,
                          style: GoogleFonts.openSans(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarnCreditsInline extends StatelessWidget {
  const _EarnCreditsInline({required this.credits});
  final int credits;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _GlossyCoinIcon(size: 22),
        const SizedBox(width: 6),
        Text(
          '+$credits credits',
          style: GoogleFonts.openSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1B1E2B),
          ),
        ),
      ],
    );
  }
}

class _WalletBalanceScreen extends StatelessWidget {
  const _WalletBalanceScreen();

  static const List<_WalletTransaction> _transactions = [
    _WalletTransaction(title: 'Buy Credits', subtitle: 'Card payment', amount: '+100'),
    _WalletTransaction(title: 'Shared Item', subtitle: 'Reward', amount: '+10'),
    _WalletTransaction(title: 'Boost Listing', subtitle: 'Spend credits', amount: '-5'),
    _WalletTransaction(title: 'Daily Bonus', subtitle: 'Reward', amount: '+5'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Wallet'),
          backgroundColor: AppTheme.primaryNavy,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: const Center(child: Text('Please sign in to view wallet.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final credits = (data?['credits'] as num?)?.toInt() ?? 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              _WalletHeader(credits: credits),
              const SizedBox(height: 20),
              Text(
                'Recent Transactions',
                style: GoogleFonts.openSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              ..._transactions.map((tx) => _WalletTransactionRow(tx: tx)),
            ],
          );
        },
      ),
    );
  }
}

class _WalletHeader extends StatelessWidget {
  const _WalletHeader({required this.credits});
  final int credits;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF0F2FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const _GlossyCoinIcon(size: 64),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Balance',
                style: GoogleFonts.openSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                credits.toString(),
                style: GoogleFonts.openSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1B1E2B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletTransaction {
  const _WalletTransaction({
    required this.title,
    required this.subtitle,
    required this.amount,
  });
  final String title;
  final String subtitle;
  final String amount;
}

class _WalletTransactionRow extends StatelessWidget {
  const _WalletTransactionRow({required this.tx});
  final _WalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const _GlossyCoinIcon(size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: GoogleFonts.openSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B1E2B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tx.subtitle,
                  style: GoogleFonts.openSans(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            tx.amount,
            style: GoogleFonts.openSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: tx.amount.startsWith('-') ? Colors.redAccent : AppTheme.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyCreditsScreen extends StatelessWidget {
  const _BuyCreditsScreen();

  static const List<_CreditPack> _packs = [
    _CreditPack(productId: 'credits_5', credits: 5, price: '\$0.99'),
    _CreditPack(productId: 'credits_20', credits: 20, price: '\$2.99'),
    _CreditPack(productId: 'credits_100', credits: 100, price: '\$9.99'),
    _CreditPack(productId: 'credits_250', credits: 250, price: '\$19.99'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Buy Credits'),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Consumer<CreditCenterViewModel>(
        builder: (context, vm, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              if (vm.errorMessage != null) ...[
                _StatusBanner(
                  message: vm.errorMessage!,
                  isError: true,
                  onClose: () => vm.clearError(),
                ),
                const SizedBox(height: 16),
              ],
              if (vm.isLoadingProducts)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading packs...'),
                      ],
                    ),
                  ),
                )
              else if (vm.products.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Credit packs could not be loaded.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => vm.loadProducts(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else
                ...List.generate(_packs.length, (index) {
                  final pack = _packs[index];
                  final price = vm.priceForProduct(pack.productId, pack.price);
                  final productAvailable = vm.products[pack.productId] != null;
                  return Padding(
                    padding: EdgeInsets.only(bottom: index == _packs.length - 1 ? 0 : 14),
                    child: _CreditPackCard(
                      pack: pack.copyWith(price: price),
                      isLoading: vm.isProcessingPurchase,
                      onTap: productAvailable && !vm.isProcessingPurchase
                          ? () async {
                              vm.clearError();
                              await vm.purchaseCreditPack(pack.productId);
                            }
                          : null,
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _CreditPack {
  const _CreditPack({
    required this.productId,
    required this.credits,
    required this.price,
  });
  final String productId;
  final int credits;
  final String price;

  _CreditPack copyWith({String? price}) {
    return _CreditPack(
      productId: productId,
      credits: credits,
      price: price ?? this.price,
    );
  }
}

class _CreditPackCard extends StatelessWidget {
  const _CreditPackCard({
    required this.pack,
    required this.onTap,
    this.isLoading = false,
  });

  final _CreditPack pack;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const _GlossyCoinIcon(size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${pack.credits} credits',
                    style: GoogleFonts.openSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1B1E2B),
                    ),
                  ),
                ),
                _PricePill(text: pack.price, isLoading: isLoading, enabled: enabled),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({
    required this.text,
    this.isLoading = false,
    this.enabled = true,
  });
  final String text;
  final bool isLoading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: enabled ? AppTheme.primaryNavy : Colors.grey,
        borderRadius: BorderRadius.circular(999),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        width: 70,
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: GoogleFonts.openSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GlossyCoinIcon extends StatelessWidget {
  const _GlossyCoinIcon({required this.size});
  final double size;

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
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFFFF1D6),
                  Color(0xFFFFC46B),
                  Color(0xFFFF9B2A),
                  Color(0xFFFF7A00),
                ],
                stops: [0.0, 0.45, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8A00).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Container(
              margin: EdgeInsets.all(size * 0.12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
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
                fontSize: size * 0.48,
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

class _PremiumPlansScreen extends StatelessWidget {
  const _PremiumPlansScreen();

  static const List<_PremiumPlan> _plans = [
    _PremiumPlan(
      productId: 'premium_weekly_v2',
      title: 'Weekly',
      subtitle: 'No ads • Bonus credits',
      credits: 5,
      price: '\$1.99 / week',
      buttonLabel: 'Weekly \$1.99',
    ),
    _PremiumPlan(
      productId: 'premium_monthly_v2',
      title: 'Monthly',
      subtitle: 'No ads • Bonus credits',
      credits: 40,
      price: '\$4.99 / month',
      buttonLabel: 'Month \$4.99',
    ),
    _PremiumPlan(
      productId: 'premium_yearly_v2',
      title: 'Yearly',
      subtitle: 'No ads • Bonus credits',
      credits: 200,
      price: '\$49.99 / year',
      buttonLabel: 'Year \$49.99',
    ),
  ];

  static const _privacyUrl = 'https://mryorulmaz.github.io/privacy.html';
  static const _termsUrl = 'https://mryorulmaz.github.io/terms.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Premium'),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Consumer<CreditCenterViewModel>(
        builder: (context, vm, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              if (vm.errorMessage != null) ...[
                _StatusBanner(
                  message: vm.errorMessage!,
                  isError: true,
                  onClose: () => vm.clearError(),
                ),
                const SizedBox(height: 16),
              ],
              if (vm.isLoadingProducts)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading plans...'),
                      ],
                    ),
                  ),
                )
              else ...[
                ...List.generate(_plans.length, (index) {
                  final plan = _plans[index];
                  final price = vm.priceForProduct(plan.productId, plan.price);
                  final productAvailable = vm.products[plan.productId] != null;
                  return Padding(
                    padding: EdgeInsets.only(bottom: index == _plans.length - 1 ? 0 : 14),
                    child: _PremiumPlanCard(
                      plan: plan.copyWith(
                        price: price,
                        buttonLabel: _buttonLabel(plan.title, price),
                      ),
                      isLoading: vm.isProcessingPurchase,
                      onTap: productAvailable && !vm.isProcessingPurchase
                          ? () async {
                              vm.clearError();
                              await vm.purchasePremium(plan.productId);
                            }
                          : null,
                    ),
                  );
                }),
                const SizedBox(height: 24),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => _openUrl(_privacyUrl),
                        child: const Text('Privacy Policy', style: TextStyle(fontSize: 12)),
                      ),
                      Text('·', style: TextStyle(color: Colors.grey.shade600)),
                      TextButton(
                        onPressed: () => _openUrl(_termsUrl),
                        child: const Text('Terms of Use', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
              if (!vm.isLoadingProducts && vm.products.isEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Plans could not be loaded.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => vm.loadProducts(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _buttonLabel(String title, String price) {
    if (price.contains('/')) return price;
    if (title == 'Weekly') return 'Weekly $price';
    if (title == 'Monthly') return 'Month $price';
    return 'Year $price';
  }
}

class _PremiumPlan {
  const _PremiumPlan({
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.credits,
    required this.price,
    required this.buttonLabel,
  });

  final String productId;
  final String title;
  final String subtitle;
  final int credits;
  final String price;
  final String buttonLabel;

  _PremiumPlan copyWith({String? price, String? buttonLabel}) {
    return _PremiumPlan(
      productId: productId,
      title: title,
      subtitle: subtitle,
      credits: credits,
      price: price ?? this.price,
      buttonLabel: buttonLabel ?? this.buttonLabel,
    );
  }
}

class _PremiumPlanCard extends StatelessWidget {
  const _PremiumPlanCard({
    required this.plan,
    required this.onTap,
    this.isLoading = false,
  });

  final _PremiumPlan plan;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: GoogleFonts.openSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D1221),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.subtitle,
                      style: GoogleFonts.openSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1B1E2B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '+${plan.credits} credits',
                      style: GoogleFonts.openSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentOrange,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: AppTheme.accentOrange.withValues(alpha: 0.35),
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _SelectButton(
                text: plan.buttonLabel,
                isLoading: isLoading,
                enabled: onTap != null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectButton extends StatelessWidget {
  const _SelectButton({
    required this.text,
    this.isLoading = false,
    this.enabled = true,
  });
  final String text;
  final bool isLoading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: enabled ? AppTheme.primaryNavy : Colors.grey,
        borderRadius: BorderRadius.circular(999),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        width: 90,
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: GoogleFonts.openSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
class _CreditCoinIcon extends StatelessWidget {
  const _CreditCoinIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Text(
        'C',
        style: GoogleFonts.openSans(
          fontSize: size * 0.6,
          fontWeight: FontWeight.w800,
          color: AppTheme.accentOrange,
        ),
      ),
    );
  }
}

// Removed small C markers from list rows per design.
