import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          title: const Text(
            'الإعدادات',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ═══ إعدادات المسح ═══
            _SectionHeader(title: 'إعدادات المسح', icon: Icons.qr_code_scanner),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // عند مسح صنف غير معروف
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.help_outline,
                              size: 18,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'عند مسح صنف غير معروف',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _OptionTile(
                          label: 'حفظ تلقائياً للمراجعة لاحقاً',
                          icon: Icons.save_outlined,
                          color: Colors.blue,
                          selected: settings.unknownBarcodeAction == 'save',
                          onTap: () => settings.setUnknownBarcodeAction('save'),
                        ),
                        const SizedBox(height: 8),
                        _OptionTile(
                          label: 'اسأل الموظف عن اسم الصنف',
                          icon: Icons.edit_outlined,
                          color: Colors.green,
                          selected: settings.unknownBarcodeAction == 'ask',
                          onTap: () => settings.setUnknownBarcodeAction('ask'),
                        ),
                        const SizedBox(height: 8),
                        _OptionTile(
                          label: 'رفض المسح وتنبيه الموظف',
                          icon: Icons.block,
                          color: Colors.red,
                          selected: settings.unknownBarcodeAction == 'reject',
                          onTap: () =>
                              settings.setUnknownBarcodeAction('reject'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up, color: Colors.blue),
                    title: const Text('صوت المسح'),
                    subtitle: const Text('تشغيل صوت عند كل مسح'),
                    value: settings.soundEnabled,
                    onChanged: settings.setSoundEnabled,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration, color: Colors.blue),
                    title: const Text('الاهتزاز'),
                    subtitle: const Text('اهتزاز عند كل مسح'),
                    value: settings.vibrationEnabled,
                    onChanged: settings.setVibrationEnabled,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ═══ إعدادات التقرير ═══
            _SectionHeader(title: 'إعدادات التقرير', icon: Icons.bar_chart),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(
                      Icons.warning_amber,
                      color: Colors.red,
                    ),
                    title: const Text('إظهار الأصناف غير المعرفة'),
                    subtitle: const Text('أصناف مسحت لكن غير موجودة في النظام'),
                    value: settings.showUnknown,
                    onChanged: settings.setShowUnknown,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    title: const Text('إظهار الأصناف المطابقة'),
                    subtitle: const Text('أصناف الكمية الفعلية = المتوقعة'),
                    value: settings.showMatching,
                    onChanged: settings.setShowMatching,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ═══ إعدادات العرض ═══
            _SectionHeader(title: 'إعدادات العرض', icon: Icons.palette),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(
                      Icons.dark_mode,
                      color: Colors.indigo,
                    ),
                    title: const Text('الوضع الليلي'),
                    subtitle: const Text('تغيير مظهر التطبيق للوضع الداكن'),
                    value: settings.darkMode,
                    onChanged: settings.setDarkMode,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.language, color: Colors.blue),
                    title: const Text('اللغة'),
                    trailing: DropdownButton<String>(
                      value: settings.language,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'ar', child: Text('العربية')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                      ],
                      onChanged: (val) {
                        if (val != null) settings.setLanguage(val);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                'NMA Inventory v1.0.0',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? color
                  : Theme.of(context).iconTheme.color ?? Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected
                      ? color
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_circle, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}
