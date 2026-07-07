import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  // Fungsi untuk membuka URL (YouTube / Web)
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Tidak dapat membuka link: $urlString');
    }
  }

  // Fungsi khusus untuk membuka Email Client
  Future<void> _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'emailkamu@gmail.com', // GANTI dengan alamat email admin kamu
      queryParameters: {
        'subject': 'Tanya Admin - Aplikasi Anni Laundry',
        'body': 'Halo Admin, saya ingin bertanya mengenai...',
      },
    );

    if (!await launchUrl(emailLaunchUri)) {
      throw Exception('Tidak dapat membuka aplikasi email');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Pusat Bantuan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF152C4A),
          ),
        ),
        backgroundColor: Colors.amber,
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Banner Maskot / Ilustrasi Bantuan
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.help_center_rounded,
                  size: 60,
                  color: Colors.amber,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Ada kendala atau bingung?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF152C4A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Kami siap membantu kamu memahami penggunaan aplikasi Laundry ini.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Pilih Menu Bantuan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),

          // MENU 1: Baca Cara Penggunaan Aplikasi
          _buildHelpMenu(
            icon: Icons.menu_book_rounded,
            title: 'Baca Cara Penggunaan',
            subtitle: 'Panduan teks lengkap fitur & sistem aplikasi',
            color: Colors.blue,
            onTap: () {
              // Arahkan ke halaman panduan teks internal aplikasi kamu jika ada
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PanduanTeksPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // MENU 2: Tonton Video Tutorial (YouTube)
          _buildHelpMenu(
            icon: Icons.play_circle_fill_rounded,
            title: 'Tonton Video Tutorial',
            subtitle: 'Lihat video tutorial interaktif di YouTube',
            color: Colors.red,
            onTap: () {
              // GANTI dengan link video atau playlist YouTube milikmu
              _launchURL('https://www.youtube.com/watch?v=XXXXXX');
            },
          ),
          const SizedBox(height: 12),

          // MENU 3: Tanya ke Admin (Kirim Email)
          _buildHelpMenu(
            icon: Icons.mail_rounded,
            title: 'Tanya ke Admin',
            subtitle: 'Kirim pesan kendala langsung ke email kami',
            color: Colors.green,
            onTap: _sendEmail,
          ),
        ],
      ),
    );
  }

  // Widget Reusable untuk Item Menu
  Widget _buildHelpMenu({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF152C4A),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle, style: const TextStyle(fontSize: 12)),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}

// === TEMPLATE HALAMAN PANDUAN TEKS (MENU 1) ===
class PanduanTeksPage extends StatelessWidget {
  const PanduanTeksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panduan Penggunaan'),
        backgroundColor: Colors.amber,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          const Text(
            '1. Cara Membuat Pesanan Baru',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF152C4A),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '• Buka halaman transaksi lalu pilih nama pelanggan.',
                  style: TextStyle(color: Color(0xFF152C4A)),
                ),
                SizedBox(height: 4),
                Text(
                  '• Tambahkan item laundry yang dipilih dan inputkan jumlah berat/Unit.',
                  style: TextStyle(color: Color(0xFF152C4A)),
                ),
                SizedBox(height: 4),
                Text(
                  '• Pilih varian parfum serta tentukan opsi status pembayaran (Lunas/Belum Bayar).',
                  style: TextStyle(color: Color(0xFF152C4A)),
                ),
                SizedBox(height: 4),
                Text(
                  '• Klik tombol SIMPAN PESANAN & LIHAT NOTA.',
                  style: TextStyle(color: Color(0xFF152C4A)),
                ),
                SizedBox(height: 4),
                Text(
                  '• Setelah halaman Rincian Pesanan terbuka, Anda dapat mengirimkan nota langsung via WhatsApp atau mencetaknya ke printer Bluetooth.',
                  style: TextStyle(color: Color(0xFF152C4A)),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}
