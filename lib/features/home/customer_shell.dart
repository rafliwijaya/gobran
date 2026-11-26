import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_theme.dart';
import '../../models/app_models.dart';
import '../content/content_screens.dart';
import 'customer_home_screen.dart';
import 'customer_profile_screen.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({required this.user, super.key});
  final AppUser user;
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      CustomerHomeScreen(user: widget.user),
      const PromotionScreen(),
      const QrisMaintenanceScreen(),
      const HistoryScreen(),
      CustomerProfileScreen(user: widget.user),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: _GoBranNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

// ─── Custom Bottom Navigation Bar ──────────────────────────────
class _GoBranNavBar extends StatelessWidget {
  const _GoBranNavBar({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = const [
      _NavItem(icon: Symbols.home_rounded, label: 'Beranda'),
      _NavItem(assetPath: 'web/icons/promosi.png', label: 'Promo'),
      _NavItem(
        icon: Symbols.qr_code_scanner_rounded,
        label: 'QRIS',
        isCenterQris: true,
      ),
      _NavItem(icon: Symbols.overview_rounded, label: 'Aktifitas'),
      _NavItem(icon: Symbols.person_rounded, label: 'Akun'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = currentIndex == i;
              final activeColor = AppColors.primaryDark;

              if (item.isCenterQris) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 33,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.bottomCenter,
                            children: [
                              Positioned(
                                top: -24,
                                child: Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Symbols.qr_code_scanner_rounded,
                                    fill: 1,
                                    size: 28,
                                    color: isActive
                                        ? Colors.white
                                        : AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive ? activeColor : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 3,
                        width: isActive ? 24 : 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      if (item.assetPath != null)
                        ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            isActive ? activeColor : Colors.grey.shade400,
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(
                            item.assetPath!,
                            width: 24,
                            height: 24,
                          ),
                        )
                      else
                        Icon(
                          item.icon!,
                          fill: 1,
                          size: 24,
                          color: isActive ? activeColor : Colors.grey.shade400,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isActive ? activeColor : Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    this.icon,
    this.assetPath,
    required this.label,
    this.isCenterQris = false,
  });
  final IconData? icon;
  final String? assetPath;
  final String label;
  final bool isCenterQris;
}
