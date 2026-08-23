import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/auth_service.dart';
import '../content/content_screens.dart';
import 'customer_home_screen.dart';

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
      const OrdersScreen(),
      const PromotionScreen(),
      const HistoryScreen(),
      const InboxScreen(),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: _GoBranNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        user: widget.user,
      ),
    );
  }

  void _showAccount(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200),
                      image: widget.user.photoUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(widget.user.photoUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: widget.user.photoUrl.isEmpty
                          ? const Color(0xFFE8F5E9)
                          : null,
                    ),
                    child: widget.user.photoUrl.isEmpty
                        ? Center(
                            child: Text(
                              widget.user.name.isNotEmpty
                                  ? widget.user.name[0].toUpperCase()
                                  : 'G',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00880F),
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.user.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Zona: ${widget.user.zoneId}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Keluar dari akun?'),
                      content: const Text(
                        'Anda perlu masuk kembali untuk menggunakan akun ini.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD92D20),
                          ),
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Keluar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    Navigator.pop(context);
                    await AuthService().signOut();
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Keluar dari akun'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD92D20),
                  side: const BorderSide(color: Color(0xFFD92D20)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom Bottom Navigation Bar ──────────────────────────────
class _GoBranNavBar extends StatelessWidget {
  const _GoBranNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.user,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(assetPath: 'web/icons/beranda.png', label: 'Beranda'),
      _NavItem(assetPath: 'web/icons/berita.png', label: 'Pesanan'),
      _NavItem(assetPath: 'web/icons/promosi.png', label: 'Promo'),
      _NavItem(assetPath: 'web/icons/history.png', label: 'Riwayat'),
      _NavItem(assetPath: 'web/icons/user.png', label: 'Akun'),
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
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (i == 4) {
                      // Show account modal for last tab
                      final shell = context
                          .findAncestorStateOfType<_CustomerShellState>();
                      shell?._showAccount(context);
                    } else {
                      onTap(i);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Green line indicator on top
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 3,
                        width: isActive ? 24 : 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00880F),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Icon with color filter
                      ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          isActive
                              ? const Color(0xFF00880F)
                              : Colors.grey.shade400,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          item.assetPath,
                          width: 24,
                          height: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isActive
                              ? const Color(0xFF00880F)
                              : Colors.grey.shade500,
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
  const _NavItem({required this.assetPath, required this.label});
  final String assetPath;
  final String label;
}
