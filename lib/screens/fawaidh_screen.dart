import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/responsive_content.dart';

class FawaidhScreen extends StatefulWidget {
  const FawaidhScreen({super.key});

  @override
  State<FawaidhScreen> createState() => _FawaidhScreenState();
}

class _FawaidhScreenState extends State<FawaidhScreen> {
  List<Map<String, dynamic>> _fawaidhList = [];
  final Set<int> _expandedIndexes = {};
  bool _isLoading = true;
  String _errorMessage = '';

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchFawaidh();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFawaidh() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/fawaidh'))
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          _fawaidhList = data
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map),
              )
              .toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data');
      }
    } catch (e) {
      debugPrint('Gagal memuat fawaidh: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Tidak bisa memuat fawaidh. Periksa koneksi internetmu ya.';
      });
    }
  }

  /// Daftar fawaidh setelah difilter pencarian.
  /// Key pada MapEntry = index asli di [_fawaidhList] supaya status
  /// "expand" tidak tertukar antar kartu.
  List<MapEntry<int, Map<String, dynamic>>> get _filteredList {
    final entries = _fawaidhList.asMap().entries.toList();
    if (_searchQuery.isEmpty) return entries;

    return entries.where((e) {
      final item = e.value;
      final judul = (item['judul'] ?? '').toString().toLowerCase();
      final penulis = (item['penulis'] ?? '').toString().toLowerCase();
      final isi = (item['isi'] ?? '').toString().toLowerCase();
      return judul.contains(_searchQuery) ||
          penulis.contains(_searchQuery) ||
          isi.contains(_searchQuery);
    }).toList();
  }

  void _copyFawaidh(Map<String, dynamic> item) {
    final text =
        '${item['judul'] ?? ''}\n\n'
        '${item['isi'] ?? ''}\n\n'
        '— ${item['penulis'] ?? 'Anonim'}';
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Fawaidh disalin ke clipboard');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.getSurfaceContainerLow(context),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder dipakai supaya di layar lebar sidebarnya tetap tampil
    // seperti aplikasi desktop, tanpa mengubah tampilan di HP.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints batas) {
        if (batas.maxWidth < kBreakpointDesktop) {
          return _buildHp(context);
        }
        return DesktopSidebarFrame(child: _buildHp(context));
      },
    );
  }

  /// Halaman versi HP — bentuk lama, sengaja tidak diubah.
  Widget _buildHp(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.getPrimaryText(context),
            size: 20,
          ),
          onPressed: () => popOrHome(context),
        ),
        title: Text(
          'Fawaidh Asatidz',
          style: TextStyle(
            color: AppColors.getPrimaryText(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ResponsiveContent(
        child: RefreshIndicator(
          color: AppColors.getGoldLeaf(context),
          backgroundColor: AppColors.getSurfaceContainerLow(context),
          onRefresh: _fetchFawaidh,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) return _buildLoading(context);
    if (_errorMessage.isNotEmpty) return _buildError(context);

    final items = _filteredList;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _buildHeroBanner(context),
        const SizedBox(height: 20),
        _buildSearchField(context),
        const SizedBox(height: 20),
        if (items.isEmpty)
          _buildEmpty(context)
        else
          ...items.map(
            (entry) => _buildFawaidhCard(context, entry.value, entry.key),
          ),
      ],
    );
  }

  // ===================== HERO BANNER =====================
  Widget _buildHeroBanner(BuildContext context) {
    final goldColor = AppColors.getGoldLeaf(context);
    final primaryColor = AppColors.getPrimaryText(context);
    final textColor = AppColors.getTextPrimary(context);
    final surfaceVariant = AppColors.getSurfaceVariant(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: goldColor.withOpacity(0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.20),
            AppColors.getSurfaceContainerLow(context),
            surfaceVariant.withOpacity(0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.08,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: goldColor.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: goldColor.withOpacity(0.4)),
            ),
            child: Icon(Icons.auto_stories_rounded, color: goldColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kumpulan Faedah Ilmiah',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Catatan ilmu & nasihat dari para asatidz pilihan.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.getOnSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: goldColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: goldColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    '${_fawaidhList.length} Fawaidh',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: goldColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== SEARCH =====================
  Widget _buildSearchField(BuildContext context) {
    final goldColor = AppColors.getGoldLeaf(context);
    final surfaceVariant = AppColors.getSurfaceVariant(context);

    return TextField(
      controller: _searchController,
      style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 14),
      cursorColor: goldColor,
      decoration: InputDecoration(
        hintText: 'Cari judul, isi, atau nama ustadz...',
        hintStyle: TextStyle(
          color: AppColors.getOnSurfaceVariant(context),
          fontSize: 13.5,
        ),
        prefixIcon: Icon(Icons.search_rounded, color: goldColor, size: 22),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.getOnSurfaceVariant(context),
                  size: 20,
                ),
                onPressed: () => _searchController.clear(),
              ),
        filled: true,
        fillColor: AppColors.getSurfaceContainerLow(context),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: surfaceVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: goldColor.withOpacity(0.6)),
        ),
      ),
    );
  }

  // ===================== KARTU FAWAIDH =====================
  Widget _buildFawaidhCard(
    BuildContext context,
    Map<String, dynamic> item,
    int index,
  ) {
    final goldColor = AppColors.getGoldLeaf(context);
    final textColor = AppColors.getTextPrimary(context);
    final subTextColor = AppColors.getOnSurfaceVariant(context);
    final surfaceVariant = AppColors.getSurfaceVariant(context);

    final judul = (item['judul'] ?? 'Tanpa Judul').toString();
    final penulis = (item['penulis'] ?? 'Anonim').toString();
    final isi = (item['isi'] ?? '').toString().trim();

    final isExpanded = _expandedIndexes.contains(index);
    final isLongText = isi.length > 220;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceContainerLow(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpanded ? goldColor.withOpacity(0.5) : surfaceVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.07,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isLongText
              ? () {
                  setState(() {
                    if (isExpanded) {
                      _expandedIndexes.remove(index);
                    } else {
                      _expandedIndexes.add(index);
                    }
                  });
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== HEADER: nomor + judul + tombol salin =====
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: goldColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: goldColor.withOpacity(0.35)),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: goldColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          judul,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.35,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Salin fawaidh',
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: subTextColor,
                      ),
                      onPressed: () => _copyFawaidh(item),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ===== PENULIS =====
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: goldColor.withOpacity(0.18),
                      child: Text(
                        penulis.isNotEmpty
                            ? penulis.characters.first.toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: goldColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        penulis,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: subTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ===== ISI =====
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: Text(
                    isi.isEmpty ? 'Tidak ada isi.' : isi,
                    maxLines: isExpanded ? null : 4,
                    overflow: isExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: isExpanded ? textColor : subTextColor,
                    ),
                  ),
                ),

                if (isLongText) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedIndexes.remove(index);
                        } else {
                          _expandedIndexes.add(index);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isExpanded ? 'Sembunyikan' : 'Baca selengkapnya',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: goldColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: goldColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== STATE LAINNYA =====================
  Widget _buildLoading(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: CircularProgressIndicator(
              color: AppColors.getGoldLeaf(context),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Memuat fawaidh...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.getOnSurfaceVariant(context),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(
          Icons.cloud_off_rounded,
          size: 56,
          color: AppColors.getGoldLeaf(context),
        ),
        const SizedBox(height: 20),
        Text(
          'Ups, gagal memuat data',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _errorMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.6,
            color: AppColors.getOnSurfaceVariant(context),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getGoldLeaf(context),
              foregroundColor: const Color(0xFF00120B),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _fetchFawaidh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Coba Lagi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      child: Column(
        children: [
          Icon(
            _searchQuery.isEmpty
                ? Icons.menu_book_outlined
                : Icons.search_off_rounded,
            size: 52,
            color: AppColors.getGoldLeaf(context),
          ),
          const SizedBox(height: 18),
          Text(
            _searchQuery.isEmpty
                ? 'Belum ada fawaidh'
                : 'Fawaidh tidak ditemukan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Nantikan faedah ilmiah berikutnya dari para asatidz.'
                : 'Coba gunakan kata kunci lain.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppColors.getOnSurfaceVariant(context),
            ),
          ),
        ],
      ),
    );
  }
}
