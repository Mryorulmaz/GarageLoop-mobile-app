import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_config.dart';

/// Premium aktif mi? Süre dolmuşsa false.
bool _isPremiumActive(Map<String, dynamic>? data) {
  if (data == null || data['isPremium'] != true) return false;
  final exp = data['premiumExpiresAt'];
  if (exp == null) return true;
  DateTime? dt;
  if (exp is Timestamp) {
    dt = exp.toDate();
  } else if (exp is DateTime) {
    dt = exp;
  }
  if (dt == null) return true;
  return dt.isAfter(DateTime.now());
}

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  int _retryCount = 0;
  static const int _maxRetries = 5;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadAd() {
    final adUnitId = _bannerAdUnitId();
    if (adUnitId.isEmpty) return;
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() => _isLoaded = false);
          // Simulator'da bazen ilk yükleme başarısız olur, retry
          if (_retryCount < _maxRetries) {
            _retryCount++;
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) _loadAd();
            });
          }
        },
      ),
    )..load();
  }

  String _bannerAdUnitId() => AdConfig.bannerAdUnitId();

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

class PremiumAwareBanner extends StatelessWidget {
  const PremiumAwareBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Giriş yapılmamışsa: banner göster.
    if (user == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(child: AdBanner()),
      );
    }

    // Giriş yapılmışsa: Firestore'dan premium durumuna bak.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final isPremium = _isPremiumActive(data);
        // Premium ise: hiçbir banner gösterme.
        if (isPremium) return const SizedBox.shrink();

        // Premium değilse: banner göster.
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Center(child: AdBanner()),
        );
      },
    );
  }
}

/// Ürün gridleri arasında veya içerik arasında kullanılan minimal banner (her 4 üründe bir)
/// Giriş yapmamış kullanıcılar + premium olmayan giriş yapmış kullanıcılar görür.
class InlineBanner extends StatelessWidget {
  const InlineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Giriş yapılmamışsa: banner göster.
    if (user == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: AdBanner()),
      );
    }

    // Giriş yapılmışsa: Firestore'dan premium durumuna bak.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final isPremium = _isPremiumActive(data);
        // Premium ise: banner gösterme.
        if (isPremium) return const SizedBox.shrink();

        // Premium değilse: banner göster.
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: AdBanner()),
        );
      },
    );
  }
}
