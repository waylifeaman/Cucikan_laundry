import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '/services/session_service.dart';
import 'pengaturanUmum/bantuan_page.dart';
import 'pengaturanUmum/pengaturanAkun_page.dart';
import 'pengaturanUmum/profil_page.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  int? _hoveredTileIndex;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<_SettingOption> _settings = [];

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await SessionService.getRole();
    if (!mounted) return;
    setState(() {
      _settings = _buildSettings(role);
    });
  }

  List<_SettingOption> _buildSettings(String role) {
    final commonOptions = [
      _SettingOption(
        index: 2,
        icon: FontAwesomeIcons.desktop,
        title: 'Pusat Bantuan',
        subtitle: 'Cara Penggunaan Aplikasi',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelpCenterPage()),
          );
        },
      ),
      _SettingOption(
        index: 3,
        icon: FontAwesomeIcons.rightFromBracket,
        title: 'Log-out',
        subtitle: 'Keluar dari Aplikasi',
        onTap: () async {
          await SessionService.logout();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        },
      ),
    ];

    if (role == 'cashier') {
      return commonOptions;
    }

    return [
      _SettingOption(
        index: 0,
        icon: FontAwesomeIcons.user,
        title: 'Profil',
        subtitle: 'Nama Laundry, Alamat Laundry',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilPage()),
          );
        },
      ),
      _SettingOption(
        index: 1,
        icon: FontAwesomeIcons.key,
        title: 'Pengaturan Akun',
        subtitle: 'Ubah Password, email, info Akun',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
          );
        },
      ),
      ...commonOptions,
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_SettingOption> get _filteredSettings {
    if (_searchQuery.isEmpty) {
      return _settings;
    }
    final query = _searchQuery.toLowerCase();
    return _settings.where((item) {
      return item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredSettings = _filteredSettings;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(
        backgroundColor: Colors.amber,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Pengaturan',
          style: TextStyle(
            color: Color(0xFF152C4A),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 16),
                    _buildSectionTitle(
                      'Pengaturan umum',
                      style: TextStyle(color: Color(0xFF152C4A)),
                    ),
                    const SizedBox(height: 16),
                    ...filteredSettings.map((item) {
                      return _buildSettingTile(
                        index: item.index,
                        icon: item.icon,
                        title: item.title,
                        subtitle: item.subtitle,
                        onTap: item.onTap,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style:
            style ??
            const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
      ),
    );
  }

  Widget _buildSettingTile({
    required int index,
    required FaIconData icon, // <-- diubah dari dynamic
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final bool isHovered = _hoveredTileIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredTileIndex = index),
      onExit: (_) => setState(() => _hoveredTileIndex = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isHovered ? const Color(0xFFF8F9FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              leading: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FaIcon(
                  icon,
                  color: Color(0xFF152C4A),
                  size: 20,
                ), // <-- diubah dari Icon
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF152C4A),
                ),
              ),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingOption {
  final int index;
  final FaIconData icon; // <-- diubah dari dynamic
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _SettingOption({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
