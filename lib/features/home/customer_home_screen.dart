import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/common_widgets.dart';
import '../../core/formatters.dart';
import '../../models/app_models.dart';
import '../../services/firestore_service.dart';
import '../content/content_screens.dart';
import '../emergency/emergency_screen.dart';
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
        const SizedBox(height: 20),
        // Service Menu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ServiceMenu(user: user),
        ),
        const SizedBox(height: 28),
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
                colors: [Color(0xFF00880F), Color(0xFF006B0C)],
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
                      image: user.photoUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(user.photoUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: user.photoUrl.isEmpty
                          ? const Color(0xFFE8F5E9)
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
                                color: Color(0xFF00880F),
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
                              Icons.location_on,
                              size: 12,
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
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Image.asset(
                        'web/icons/notification.png',
                        width: 18,
                        height: 18,
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // Hijau muda
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00880F).withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: const Color(0xFF00880F), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                children: [
                  TextSpan(text: _displayText),
                  const TextSpan(
                    text: '|',
                    style: TextStyle(
                      color: Color(0xFF00880F),
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

  final _banners = const ['web/bener.png', 'web/bener.png', 'web/bener.png'];

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
                    ? const Color(0xFF00880F)
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
            imagePath: 'web/icons/Express.png',
            label: 'Express',
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
            imagePath: 'web/icons/Food.png',
            label: 'Food',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FoodMarketplaceScreen(user: user),
              ),
            ),
          ),
        ),
        // Expanded(
        //   child: _ServiceIcon(
        //     icon: Icons.emergency,
        //     label: 'Darurat',
        //     iconColor: const Color(0xFFD92D20),
        //     onTap: () => Navigator.push(
        //       context,
        //       MaterialPageRoute(builder: (_) => const EmergencyScreen()),
        //     ),
        //   ),
        // ),
      ],
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({
    this.imagePath,
    this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });
  final String? imagePath;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Jika ada gambar: tampilkan langsung tanpa kotak putih
          if (imagePath != null)
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  imagePath!,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                ),
              ),
            )
          // Jika icon biasa (Darurat): tetap pakai kotak putih
          else
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: (iconColor ?? const Color(0xFF00880F)).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (iconColor ?? const Color(0xFF00880F)).withValues(
                    alpha: 0.25,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 38,
                color: iconColor ?? const Color(0xFF00880F),
              ),
            ),
          const SizedBox(height: 8),
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
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
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
              child: NetworkImageBox(
                url: product.imageUrl,
                height: 110,
                width: 160,
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
                  Text(
                    rupiah(product.price),
                    style: const TextStyle(
                      color: Color(0xFF00880F),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
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
            color: const Color(0xFF00880F).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.home_repair_service_outlined,
            color: Color(0xFF00880F),
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
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF00880F)),
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
