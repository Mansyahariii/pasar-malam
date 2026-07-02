import 'package:flutter/material.dart';
import 'package:pasar_malam/core/providers/theme_provider.dart';
import 'package:pasar_malam/core/routes/app_router.dart';
import 'package:pasar_malam/features/auth/presentation/providers/auth_provider.dart';
import 'package:pasar_malam/features/cart/presentation/providers/cart_provider.dart';
import 'package:pasar_malam/features/dashboard/data/models/product_model.dart';
import 'package:pasar_malam/features/dashboard/presentation/providers/product_provider.dart';
import 'package:pasar_malam/features/order/presentation/providers/order_provider.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedNav = 0;
  String _selectedCategory = 'All';
  final _searchCtrl = TextEditingController();

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all': return Icons.apps;
      case 'sofa':
      case 'furniture': return Icons.chair;
      case 'lighting':
      case 'lampu': return Icons.light;
      case 'table':
      case 'meja': return Icons.table_restaurant;
      case 'decor':
      case 'dekorasi': return Icons.home_max;
      case 'storage':
      case 'lemari': return Icons.door_sliding;
      case 'kitchen':
      case 'dapur': return Icons.kitchen_outlined;
      default: return Icons.home;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchProducts();
      context.read<CartProvider>().fetchCart();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ProductModel> _filteredProducts(List<ProductModel> products) {
    final query = _searchCtrl.text.toLowerCase();
    return products.where((p) {
      final matchCategory = _selectedCategory == 'All' ||
          p.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchSearch = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query);
      return matchCategory && matchSearch;
    }).toList();
  }

  String _formatPrice(double price) {
    final str = price.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      count++;
    }
    return 'Rp. ${buffer.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final productProv = context.watch<ProductProvider>();

    // ignore: unused_local_variable
    final _ = context.watch<OrderProvider>();

    final uniqueCategories = productProv.products
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    uniqueCategories.sort();

    final dynamicCategories = [
      const _CategoryItem(label: 'All', icon: Icons.apps),
      ...uniqueCategories.map((catName) => _CategoryItem(
            label: catName,
            icon: _getCategoryIcon(catName),
          )),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Body scroll ─────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => productProv.fetchProducts(),
                child: CustomScrollView(
                  slivers: [
                    // ── Search Bar ─────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: _SearchBar(controller: _searchCtrl, onChanged: (_) => setState(() {})),
                      ),
                    ),

                    // ── Banner ─────────────────────────────
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _BannerCard(),
                      ),
                    ),

                    // ── Categories ─────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: Text(
                                'See All',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: dynamicCategories.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final cat = dynamicCategories[i];
                            final selected = _selectedCategory == cat.label;
                            return _CategoryChip(
                              item: cat,
                              selected: selected,
                              onTap: () => setState(() => _selectedCategory = cat.label),
                            );
                          },
                        ),
                      ),
                    ),

                    // ── For You label ─────────────────────
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: Text(
                          'For you',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // ── Product Grid ──────────────────────
                    switch (productProv.status) {
                      ProductStatus.loading || ProductStatus.initial =>
                        const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ProductStatus.error => SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text(productProv.error ?? 'Terjadi kesalahan'),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Coba Lagi'),
                                  onPressed: () => productProv.fetchProducts(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ProductStatus.loaded => () {
                          final items = _filteredProducts(productProv.products);
                          if (items.isEmpty) {
                            return const SliverFillRemaining(
                              child: Center(
                                child: Text('Tidak ada produk ditemukan'),
                              ),
                            );
                          }
                          return SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _ProductCard(
                                  product: items[i],
                                  formatPrice: _formatPrice,
                                ),
                                childCount: items.length,
                              ),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.62,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                            ),
                          );
                        }(),
                    },
                  ],
                ),
              ),
            ),

            // ── Bottom Navigation Bar ────────────────────
            _BottomNav(
              selectedIndex: _selectedNav,
              onTap: (i) {
                if (i == 1) {
                  // Cart → navigate to CartPage
                  Navigator.pushNamed(context, AppRouter.cart).then((_) {
                    if (context.mounted) {
                      context.read<CartProvider>().fetchCart();
                    }
                  });
                } else if (i == 3) {
                  // Account → logout dialog
                  _showLogoutDialog(context, auth);
                } else {
                  setState(() => _selectedNav = i);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _AccountDialog(auth: auth);
      },
    );
  }
}

// ── Search Bar Widget ──────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final hintColor = Theme.of(context).hintColor;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Sofa, Lampu, Meja, Dekorasi...',
          hintStyle: TextStyle(color: hintColor, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: hintColor, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

// ── Banner Card Widget ─────────────────────────────────────
class _BannerCard extends StatelessWidget {
  const _BannerCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.colorScheme.secondary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          // Lingkaran dekorasi background
          Positioned(
            right: 130,
            top: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Teks dan tombol
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Modern Sanctuary',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Curated premium furniture\nand home decor collections.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'EXPLORE NOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Gambar kursi placeholder
          Positioned(
            right: 0,
            bottom: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Container(
                width: 160,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.chair,
                  size: 80,
                  color: Colors.white24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Chip Widget ───────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final _CategoryItem item;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).primaryColor
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 16,
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product Card Widget ────────────────────────────────────
class _ProductCard extends StatefulWidget {
  final ProductModel product;
  final String Function(double) formatPrice;

  const _ProductCard({required this.product, required this.formatPrice});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _isFavorite = false;

  void _showProductDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProductDetailSheet(
        product: widget.product,
        formatPrice: widget.formatPrice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: () => _showProductDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gambar produk ───────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: p.imageUrl.isNotEmpty
                        ? Image.network(
                            p.imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                  ),
                  // Heart button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _isFavorite = !_isFavorite),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: _isFavorite ? Colors.red : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Info produk ────────────────────────────
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kategori
                    Text(
                      p.category,
                      style: TextStyle(
                        fontSize: 11,
                        color: onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Nama produk
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Rating
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < 4 ? Icons.star : Icons.star_half,
                            size: 12,
                            color: const Color(0xFFFFC107),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '4.6',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Harga
                    Text(
                      widget.formatPrice(p.price),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Builder(
        builder: (context) => Container(
          width: double.infinity,
          height: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.image_outlined,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
            size: 40,
          ),
        ),
      );
}

// ── Product Detail Bottom Sheet ────────────────────────────
class _ProductDetailSheet extends StatefulWidget {
  final ProductModel product;
  final String Function(double) formatPrice;

  const _ProductDetailSheet({
    required this.product,
    required this.formatPrice,
  });

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    final cartProv = context.watch<CartProvider>();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // Gambar produk
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: p.imageUrl.isNotEmpty
                        ? Image.network(
                            p.imageUrl,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              height: 200,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: Icon(
                                Icons.image_outlined,
                                color: onSurface.withValues(alpha: 0.2),
                                size: 48,
                              ),
                            ),
                          )
                        : Container(
                            height: 200,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: Icon(
                              Icons.image_outlined,
                              color: onSurface.withValues(alpha: 0.2),
                              size: 48,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Kategori
                  Text(
                    p.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Nama
                  Text(
                    p.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Harga
                  Text(
                    widget.formatPrice(p.price),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Deskripsi
                  Text(
                    p.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Quantity stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_qty > 1) setState(() => _qty--);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.remove, size: 18, color: primary),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          '$_qty',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _qty++),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.add, size: 18, color: primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Tombol Tambah ke Keranjang
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: cartProv.isAdding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.shopping_cart_outlined),
                  label: Text(
                    cartProv.isAdding ? 'Menambahkan...' : 'Tambah ke Keranjang',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: cartProv.isAdding
                      ? null
                      : () async {
                          final success = await context
                              .read<CartProvider>()
                              .addToCart(p.id, _qty);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? '${p.name} ditambahkan ke keranjang'
                                    : 'Gagal menambahkan ke keranjang',
                              ),
                              backgroundColor: success ? Colors.green : Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Navigation Bar ──────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.shopping_bag_outlined, label: 'Cart'),
      _NavItem(icon: Icons.favorite_border, label: 'Favorite'),
      _NavItem(icon: Icons.person_outline, label: 'Account'),
    ];

    final surface = Theme.of(context).colorScheme.surface;
    final primary = Theme.of(context).colorScheme.primary;
    final unselectedColor = Theme.of(context).unselectedWidgetColor;
    final cartItemCount = context.watch<CartProvider>().itemCount;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
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
              final selected = selectedIndex == i;
              final isCart = i == 1;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            items[i].icon,
                            size: 24,
                            color: selected ? primary : unselectedColor,
                          ),
                          if (isCart && cartItemCount > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  cartItemCount > 99
                                      ? '99+'
                                      : '$cartItemCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? primary : unselectedColor,
                        ),
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

// ── Data classes ───────────────────────────────────────────
class _CategoryItem {
  final String label;
  final IconData icon;
  const _CategoryItem({required this.label, required this.icon});
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ── Account Dialog (dengan Dark Mode Switch) ──────────────
class _AccountDialog extends StatelessWidget {
  final AuthProvider auth;

  const _AccountDialog({required this.auth});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    return AlertDialog(
      title: const Text('Akun'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          CircleAvatar(
            radius: 30,
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              (auth.firebaseUser?.displayName ?? 'U')[0].toUpperCase(),
              style: const TextStyle(fontSize: 24, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            auth.firebaseUser?.displayName ?? 'User',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            auth.firebaseUser?.email ?? '',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 4),

          // Dark mode toggle row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    size: 20,
                    color: isDark ? Colors.amber : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isDark ? 'Mode Gelap' : 'Mode Terang',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              Switch(
                value: isDark,
                onChanged: (_) => context.read<ThemeProvider>().toggle(),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Logout'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(context);
            await auth.logout();
            if (!context.mounted) return;
            // ignore: use_build_context_synchronously
            Navigator.pushReplacementNamed(context, AppRouter.login);
          },
        ),
      ],
    );
  }
}
