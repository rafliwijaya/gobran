import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_theme.dart';
import '../../core/common_widgets.dart';
import '../../core/formatters.dart';
import '../../models/app_models.dart';
import '../../services/firestore_service.dart';
import '../content/content_screens.dart';
import '../food/food_screens.dart';
import '../order/order_flow_screen.dart';
import '../service/service_marketplace_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({required this.user, super.key});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Profile Header Stack
        _HeaderSection(user: user),
        const SizedBox(height: 12),
        // Promo Banner Slider — di atas search bar
        const _PromoBannerSlider(),
        const SizedBox(height: 14),
        // Animated Search/Typing Bar
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _AnimatedSearchBar(),
        ),
        const SizedBox(height: 14),
        // Service Menu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ServiceMenu(user: user),
        ),
        const SizedBox(height: 16),
        // Recommendation Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _RecommendationSection(user: user),
        ),
        const SizedBox(height: 20),
        // Service Promo Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ServicePromoCard(user: user),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Header Section (Gojek Green Banner + Overlapping Profile Card) ──────────
class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: statusBarHeight + 115,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Green background banner
          Container(
            height: statusBarHeight + 70,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),
          // Floating Card containing name/avatar/notification
          Positioned(
            top: statusBarHeight + 15,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1.5,
                      ),
                      image: switch (appImageProvider(user.photoUrl)) {
                        final provider? => DecorationImage(
                          image: provider,
                          fit: BoxFit.cover,
                        ),
                        null => null,
                      },
                      color: user.photoUrl.isEmpty
                          ? AppColors.primaryLight
                          : null,
                    ),
                    child: user.photoUrl.isEmpty
                        ? Center(
                            child: Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : 'G',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Greeting & Zone
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, ${user.name.split(' ').first} 👋',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Symbols.location_on_rounded,
                              fill: 1,
                              size: 13,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Zona ${user.zoneId}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Notification Bell
                  StreamBuilder<List<InboxMessage>>(
                    stream: FirestoreService().watchInbox(),
                    builder: (context, snapshot) {
                      final hasUnread = (snapshot.data ?? const [])
                          .any((item) => !item.isRead);
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: hasUnread
                                  ? AppColors.primaryLight
                                  : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                hasUnread
                                    ? Symbols.notifications_active_rounded
                                    : Symbols.notifications_rounded,
                                fill: hasUnread ? 1 : 0,
                                size: 21,
                                color: hasUnread
                                    ? AppColors.primaryDark
                                    : AppColors.ink,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const InboxScreen(),
                                  ),
                                );
                              },
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          if (hasUnread)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Search Bar with Typing Effect ─────────────────────
class _AnimatedSearchBar extends StatefulWidget {
  const _AnimatedSearchBar();
  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar> {
  static const _phrases = [
    'Mau kemana hari ini?',
    'Mau makan apa hari ini?',
    'Butuh bantuan apa hari ini?',
  ];

  int _phraseIndex = 0;
  int _charIndex = 0;
  bool _isDeleting = false;
  String _displayText = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _timer = Timer.periodic(Duration(milliseconds: _isDeleting ? 40 : 80), (_) {
      setState(() {
        final currentPhrase = _phrases[_phraseIndex];
        if (!_isDeleting) {
          if (_charIndex < currentPhrase.length) {
            _charIndex++;
            _displayText = currentPhrase.substring(0, _charIndex);
          } else {
            _timer?.cancel();
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _isDeleting = true;
                _startTyping();
              }
            });
          }
        } else {
          if (_charIndex > 0) {
            _charIndex--;
            _displayText = currentPhrase.substring(0, _charIndex);
          } else {
            _isDeleting = false;
            _phraseIndex = (_phraseIndex + 1) % _phrases.length;
            _timer?.cancel();
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _startTyping();
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primary,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Symbols.search_rounded,
            color: AppColors.primaryDark,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                children: [
                  TextSpan(text: _displayText),
                  const TextSpan(
                    text: '|',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Promo Banner Slider ────────────────────────────────────────
class _PromoBannerSlider extends StatefulWidget {
  const _PromoBannerSlider();
  @override
  State<_PromoBannerSlider> createState() => _PromoBannerSliderState();
}

class _PromoBannerSliderState extends State<_PromoBannerSlider> {
  // Infinite loop: kita gunakan itemCount = null (infinite)
  // dan inisialisasi halaman di tengah-tengah (misalnya 1000)
  static const _startPage = 1000;
  late final PageController _controller;
  int _realIndex = 0;
  Timer? _autoScroll;

  final _banners = const [
    'web/bener.jpeg',
    'web/bener.jpeg',
    'web/bener.jpeg',
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      viewportFraction: 0.92,
      initialPage: _startPage,
    );
    _realIndex = _startPage % _banners.length;
    _autoScroll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_controller.hasClients) {
        _controller.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 155,
          child: PageView.builder(
            controller: _controller,
            // itemCount: null = infinite scroll
            onPageChanged: (page) =>
                setState(() => _realIndex = page % _banners.length),
            itemBuilder: (_, page) {
              final i = page % _banners.length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    _banners[i],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _realIndex == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _realIndex == i
                    ? AppColors.primary
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Service Menu ───────────────────────────────────────────────
class _ServiceMenu extends StatelessWidget {
  const _ServiceMenu({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _ServiceIcon(
            imagePath: 'web/icons/Ojek.png',
            boxColor: const Color(0xFFD9F99D),
            label: 'Ojek',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    OrderFlowScreen(user: user, serviceType: 'ojek'),
              ),
            ),
          ),
        ),
        Expanded(
          child: _ServiceIcon(
            imagePath: 'web/icons/express-icon.png',
            boxColor: const Color(0xFFFEF08A),
            label: 'Express',
            isBustPortrait: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    OrderFlowScreen(user: user, serviceType: 'express'),
              ),
            ),
          ),
        ),
        Expanded(
          child: _ServiceIcon(
            imagePath: 'web/icons/food-icon.png',
            boxColor: const Color(0xFFFECACA),
            label: 'Food',
            isBustPortrait: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FoodMarketplaceScreen(user: user),
              ),
            ),
          ),
        ),
        Expanded(
          child: _ServiceIcon(
            imagePath: 'web/icons/jasa-icon.png',
            boxColor: const Color(0xFFE9D5FF),
            label: 'Jasa',
            isBustPortrait: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ServiceMarketplaceScreen(user: user),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({
    required this.imagePath,
    required this.boxColor,
    required this.label,
    required this.onTap,
    this.isBustPortrait = false,
  });

  final String imagePath;
  final Color boxColor;
  final String label;
  final VoidCallback onTap;
  final bool isBustPortrait;

  @override
  Widget build(BuildContext context) {
    const slotSize = 72.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: slotSize,
            height: slotSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 7,
                  right: 7,
                  bottom: 0,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                Positioned(
                  left: isBustPortrait ? -56 : -49,
                  bottom: isBustPortrait ? -15.5 : -8,
                  width: isBustPortrait ? 184 : 170,
                  height: isBustPortrait ? 100 : 93,
                  child: IgnorePointer(
                    child: Image.asset(imagePath, fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Recommendation Section ────────────────────────────────────
class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rekomendasi untuk kamu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<Product>>(
          stream: FirestoreService().watchProducts(limit: 8),
          builder: (context, snapshot) => AsyncView<List<Product>>(
            snapshot: snapshot,
            isEmpty: (items) => items.isEmpty,
            emptyMessage: 'Produk UMKM akan tampil di sini.',
            builder: (items) => SizedBox(
              height: 234,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final product = items[index];
                  return _ProductCard(product: product, user: user);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.user});
  final Product product;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FoodMarketplaceScreen(user: user)),
      ),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  NetworkImageBox(
                    url: product.imageUrl,
                    height: 110,
                    width: 160,
                  ),
                  if (product.hasDiscount)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: ProductDiscountBadge(
                        discountPercent: product.discountPercent,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.merchantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  ProductPriceText(
                    originalPriceText: rupiah(product.price),
                    finalPriceText: rupiah(product.discountedPrice),
                    hasDiscount: product.hasDiscount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Service Promo Card ─────────────────────────────────────────
class _ServicePromoCard extends StatelessWidget {
  const _ServicePromoCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Symbols.home_repair_service_rounded,
            fill: 1,
            color: AppColors.primaryDark,
            size: 24,
          ),
        ),
        title: const Text(
          'Butuh tukang atau servis?',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          'Temukan mitra jasa lokal di zona Anda.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: const Icon(
          Symbols.chevron_right_rounded,
          color: AppColors.primaryDark,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceMarketplaceScreen(user: user),
          ),
        ),
      ),
    );
  }
}
