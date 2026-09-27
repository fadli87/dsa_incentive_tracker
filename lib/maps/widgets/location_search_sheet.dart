import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/location_parser.dart';

class LocationSearchSheet extends StatefulWidget {
  const LocationSearchSheet({super.key});

  static Future<LocationParseResult?> show(BuildContext context) {
    return showModalBottomSheet<LocationParseResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const LocationSearchSheet(),
    );
  }

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _controller.text = data.text!.trim();
        _errorMessage = null;
      });
      _handleSearch();
    }
  }

  Future<void> _handleSearch() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Masukkan teks koordinat atau link ShareLoc.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await LocationParser.parse(text);
      if (!mounted) return;

      if (result != null) {
        Navigator.pop(context, result);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Format tidak dikenali. Pastikan memasukkan angka koordinat (contoh: -7.7188, 109.0156) atau tautan Google Maps / WhatsApp yang valid.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memproses lokasi. Silakan periksa kembali tautan atau teks koordinat.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF002B66).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.share_location_rounded, color: Color(0xFF002B66), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cari Titik / ShareLoc',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Input Lat, Long atau tempel link Google Maps / WA',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Text Input
            TextField(
              controller: _controller,
              maxLines: 3,
              minLines: 1,
              autofocus: true,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Contoh: -7.718821, 109.015632\natau tempel pesan ShareLoc WhatsApp...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          setState(() {
                            _controller.clear();
                            _errorMessage = null;
                          });
                        },
                      ),
                    IconButton(
                      tooltip: 'Tempel dari Clipboard',
                      icon: const Icon(Icons.content_paste_rounded, color: Color(0xFF6366F1), size: 20),
                      onPressed: _pasteFromClipboard,
                    ),
                  ],
                ),
              ),
              onSubmitted: (_) => _handleSearch(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Quick Example Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildExampleChip(
                  label: 'Cilacap Kota (-7.7188, 109.0156)',
                  onTap: () {
                    setState(() {
                      _controller.text = '-7.7188, 109.0156';
                      _errorMessage = null;
                    });
                  },
                  isDark: isDark,
                ),
                _buildExampleChip(
                  label: 'Kroya (-7.6315, 109.2485)',
                  onTap: () {
                    setState(() {
                      _controller.text = '-7.6315, 109.2485';
                      _errorMessage = null;
                    });
                  },
                  isDark: isDark,
                ),
                _buildExampleChip(
                  label: 'Tempel Clipboard',
                  icon: Icons.paste_rounded,
                  onTap: _pasteFromClipboard,
                  isDark: isDark,
                  isHighlight: true,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF002B66),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isLoading ? null : _handleSearch,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded, size: 20),
                label: Text(
                  _isLoading ? 'Mencari Lokasi...' : 'Cari & Kunjungi Lokasi',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleChip({
    required String label,
    IconData? icon,
    required VoidCallback onTap,
    required bool isDark,
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isHighlight
              ? const Color(0xFF6366F1).withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlight
                ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                : (isDark ? Colors.white10 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: isHighlight ? const Color(0xFF6366F1) : (isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                color: isHighlight
                    ? const Color(0xFF6366F1)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
