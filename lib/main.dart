import 'package:flutter/material.dart';
import 'products_screen.dart';
import 'operations_screen.dart';

void main() {
  runApp(const NMAApp());
}

class NMAApp extends StatelessWidget {
  const NMAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NMA Inventory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          title: const Text(
            'NMA نظام المخزون',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'القائمة الرئيسية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    MenuCard(
                      icon: Icons.inventory_2,
                      title: 'جرد',
                      subtitle: 'عمليات الجرد',
                      color: Colors.blue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OperationsScreen(type: 'جرد'),
                        ),
                      ),
                    ),
                    MenuCard(
                      icon: Icons.swap_horiz,
                      title: 'تحويلات',
                      subtitle: 'استلام / تسليم',
                      color: Colors.orange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const OperationsScreen(type: 'تحويلات'),
                        ),
                      ),
                    ),
                    MenuCard(
                      icon: Icons.category,
                      title: 'الأصناف',
                      subtitle: 'استيراد / إدارة',
                      color: Colors.green,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProductsScreen(),
                        ),
                      ),
                    ),
                    MenuCard(
                      icon: Icons.bar_chart,
                      title: 'التقارير',
                      subtitle: 'قريباً',
                      color: Colors.purple,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Column(
                  children: [
                    Text(
                      '© 2026 إدارة المخزون - NMA | جميع الحقوق محفوظة',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.black38),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'NMA Inventory Management © 2026 | All Rights Reserved',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.black38),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const MenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
