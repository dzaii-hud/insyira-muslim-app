import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../theme/app_theme.dart';
import '../widgets/kajian_card_background.dart';

class KajianScreen extends StatefulWidget {
  const KajianScreen({super.key});

  @override
  State<KajianScreen> createState() => _KajianScreenState();
}

class _KajianScreenState extends State<KajianScreen> {
  List<Kajian> _kajianList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _refreshTimer;

  // ===== PENCARIAN =====
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Warna aksen teks di atas foto (selalu versi terang karena
  // background-nya gelap dari overlay foto)
  static const Color _accentOnPhoto = Color(0xFF8BD6B6); // hijau mint
  static const Color _softWhite = Color(0xFFBEC9C2); // putih kehijauan

  @override
  void initState() {
    super.initState();
    _fetchKajian();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // =====================================================================
  // DATA
  // =====================================================================
  Future<void> _fetchKajian() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/kajian'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          _kajianList = data.map((e) => Kajian.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data (${response.statusCode})';
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat kajian: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Tidak bisa memuat jadwal kajian. Periksa koneksi internetmu ya.';
      });
    }
  }

  String get _todayStr {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Kajian? _getFeaturedKajian() {
    final todayKajian =
        _kajianList.where((k) => k.tanggal == _todayStr).toList()
          ..sort((a, b) => a.jamMulai.compareTo(b.jamMulai));

    if (todayKajian.isEmpty) return null;

    for (final k in todayKajian) {
      if (_isKajianOngoing(k)) return k;
    }

    final now = DateTime.now();
    final nowTime =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    for (final k in todayKajian) {
      if (k.jamMulai.compareTo(nowTime) > 0) return k;
    }

    return null;
  }

  List<Kajian> _getOtherKajian(Kajian? featured) {
    final list = _kajianList.where((k) {
      if (featured == null) return true;
      return !(k.tanggal == featured.tanggal &&
          k.jamMulai == featured.jamMulai &&
          k.judul == featured.judul);
    }).toList();

    list.sort((a, b) {
      final cmp = a.tanggal.compareTo(b.tanggal);
      if (cmp != 0) return cmp;
      return a.jamMulai.compareTo(b.jamMulai);
    });
    return list;
  }

  List<Kajian> _getSearchResults() {
    final list = _kajianList.where((k) {
      return k.judul.toLowerCase().contains(_searchQuery) ||
          k.ustadz.toLowerCase().contains(_searchQuery) ||
          k.lokasi.toLowerCase().contains(_searchQuery);
    }).toList();

    list.sort((a, b) {
      final cmp = a.tanggal.compareTo(b.tanggal);
      if (cmp != 0) return cmp;
      return a.jamMulai.compareTo(b.jamMulai);
    });
    return list;
  }

  int get _todayCount =>
      _kajianList.where((k) => k.tanggal == _todayStr).length;

  bool _hasKajianHariIni() => _todayCount > 0;

  bool _hasPhoto(Kajian kajian) =>
      kajian.fotoUstadz != null && kajian.fotoUstadz!.trim().isNotEmpty;

  // =====================================================================
  // BUILD
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchKajian,
      color: AppColors.getGoldLeaf(context),
      backgroundColor: AppColors.getSurfaceContainerLow(context),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) return _buildLoading(context);
    if (_errorMessage.isNotEmpty) return _buildError(context);

    final bool isSearching = _searchQuery.isNotEmpty;
    final featured = _getFeaturedKajian();
    final otherKajian = _getOtherKajian(featured);
    final searchResults = isSearching ? _getSearchResults() : <Kajian>[];
    final isLive = featured != null && _isKajianOngoing(featured);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: [
        _buildHeroBanner(context),
        const SizedBox(height: 20),
        _buildSearchField(context),
        const SizedBox(height: 24),

        if (isSearching) ...[
          _buildSectionHeader(
            context,
            'Hasil Pencarian',
            badge: '${searchResults.length}',
          ),
          const SizedBox(height: 14),
          if (searchResults.isEmpty)
            _buildEmpty(context, searched: true)
          else
            ...searchResults.map((k) => _buildRegularCard(context, k)),
        ] else ...[
          _buildSectionHeader(
            context,
            isLive ? 'Sedang Live' : 'Kajian Berikutnya',
            icon: isLive
                ? Icons.podcasts_rounded
                : Icons.event_available_rounded,
            highlight: isLive,
          ),
          const SizedBox(height: 14),

          if (featured != null)
            _buildFeaturedCard(context, featured)
          else
            _buildEmptyFeaturedState(context, _hasKajianHariIni()),

          const SizedBox(height: 30),

          _buildSectionHeader(
            context,
            'Jadwal Kajian Lainnya',
            icon: Icons.calendar_month_rounded,
            badge: '${otherKajian.length}',
          ),
          const SizedBox(height: 14),

          if (otherKajian.isEmpty)
            _buildEmpty(context, searched: false, onlyOthers: true)
          else
            ...otherKajian.map((k) => _buildRegularCard(context, k)),
        ],
      ],
    );
  }

  // =====================================================================
  // HERO BANNER
  // =====================================================================
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
            child: Icon(Icons.mosque_rounded, color: goldColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jadwal Kajian',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ikuti kajian ilmu di sekitar & online sesuai jadwalnya.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.getOnSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildHeroChip(
                      context,
                      label: '${_kajianList.length} Kajian',
                      goldColor: goldColor,
                    ),
                    const SizedBox(width: 8),
                    _buildHeroChip(
                      context,
                      label: '$_todayCount Hari Ini',
                      goldColor: goldColor,
                      isLiveHighlight: _todayCount > 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(
    BuildContext context, {
    required String label,
    required Color goldColor,
    bool isLiveHighlight = false,
  }) {
    final color = isLiveHighlight
        ? goldColor
        : AppColors.getOnSurfaceVariant(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: goldColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: goldColor.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // =====================================================================
  // SEARCH
  // =====================================================================
  Widget _buildSearchField(BuildContext context) {
    final goldColor = AppColors.getGoldLeaf(context);
    final surfaceVariant = AppColors.getSurfaceVariant(context);

    return TextField(
      controller: _searchController,
      style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 14),
      cursorColor: goldColor,
      decoration: InputDecoration(
        hintText: 'Cari judul, ustadz, atau lokasi...',
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

  // =====================================================================
  // SECTION HEADER
  // =====================================================================
  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    IconData? icon,
    String? badge,
    bool highlight = false,
  }) {
    final goldColor = AppColors.getGoldLeaf(context);
    final accent = highlight ? goldColor : AppColors.getSurfaceVariant(context);

    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: highlight ? goldColor : AppColors.getPrimaryText(context),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        if (icon != null) ...[
          Icon(
            icon,
            size: 17,
            color: highlight
                ? goldColor
                : AppColors.getOnSurfaceVariant(context),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: highlight ? goldColor : AppColors.getTextPrimary(context),
            ),
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withOpacity(0.45)),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: highlight
                    ? goldColor
                    : AppColors.getOnSurfaceVariant(context),
              ),
            ),
          ),
      ],
    );
  }

  // =====================================================================
  // FEATURED CARD
  // =====================================================================
  Widget _buildFeaturedCard(BuildContext context, Kajian kajian) {
    final hasPhoto = _hasPhoto(kajian);
    final isLive = _isKajianOngoing(kajian);

    final surfaceColor = AppColors.getSurfaceContainerLow(context);
    final borderColor = AppColors.getSurfaceVariant(context);
    final goldColor = AppColors.getGoldLeaf(context);
    final textColor = AppColors.getTextPrimary(context);
    final subTextColor = AppColors.getOnSurfaceVariant(context);
    final primaryColor = AppColors.getPrimaryText(context);
    final shadowOpacity = Theme.of(context).brightness == Brightness.dark
        ? 0.25
        : 0.1;

    final titleColor = hasPhoto ? Colors.white : textColor;
    final ustadzColor = hasPhoto ? _accentOnPhoto : primaryColor;
    final metaColor = hasPhoto ? _softWhite : subTextColor;
    final cardRadius = BorderRadius.circular(20);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 224,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: cardRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // BACKGROUND FOTO (dijamin full-bleed, tidak ada sisa kosong)
            KajianCardBackground(
              photoUrl: kajian.fotoUstadz,
              plainBaseColor: surfaceColor,
            ),

            // OVERLAY GELAP (khusus ada foto) supaya teks terbaca
            if (hasPhoto)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.88),
                    ],
                  ),
                ),
              ),

            // CONTENT
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isLive)
                        _buildStatusBadge(
                          label: 'LIVE',
                          icon: Icons.play_arrow_rounded,
                          bgColor: goldColor,
                          fgColor: const Color(0xFF00120B),
                        )
                      else
                        _buildStatusBadge(
                          label: 'SEGERA',
                          icon: Icons.schedule,
                          bgColor: hasPhoto
                              ? Colors.black.withOpacity(0.55)
                              : goldColor.withOpacity(0.15),
                          fgColor: hasPhoto ? _accentOnPhoto : goldColor,
                        ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: hasPhoto
                              ? Colors.black.withOpacity(0.4)
                              : Colors.black.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bookmark_add_outlined,
                          color: hasPhoto ? _accentOnPhoto : textColor,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  Text(
                    kajian.judul,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      shadows: hasPhoto
                          ? const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: hasPhoto
                            ? Colors.black.withOpacity(0.45)
                            : goldColor.withOpacity(0.18),
                        child: Icon(
                          Icons.person_outline,
                          size: 14,
                          color: ustadzColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          kajian.ustadz,
                          style: TextStyle(
                            color: ustadzColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _buildMetaRow(
                    context,
                    hasPhoto: hasPhoto,
                    metaColor: metaColor,
                    goldColor: goldColor,
                    kajian: kajian,
                  ),
                ],
              ),
            ),

            // BORDER OVERLAY — di atas foto, biar full-bleed
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: cardRadius,
                    border: Border.all(
                      color: isLive ? goldColor.withOpacity(0.65) : borderColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // REGULAR CARD
  // =====================================================================
  Widget _buildRegularCard(BuildContext context, Kajian kajian) {
    final hasPhoto = _hasPhoto(kajian);
    final isToday = kajian.tanggal == _todayStr;
    final isLive = _isKajianOngoing(kajian);
    final highlight = isLive || isToday;

    final borderColor = AppColors.getSurfaceVariant(context);
    final goldColor = AppColors.getGoldLeaf(context);
    final textColor = AppColors.getTextPrimary(context);
    final subTextColor = AppColors.getOnSurfaceVariant(context);
    final primaryColor = AppColors.getPrimaryText(context);
    final shadowOpacity = Theme.of(context).brightness == Brightness.dark
        ? 0.25
        : 0.1;

    final titleColor = hasPhoto ? Colors.white : textColor;
    final ustadzColor = hasPhoto ? _accentOnPhoto : primaryColor;
    final metaColor = hasPhoto ? _softWhite : subTextColor;
    final cardRadius = BorderRadius.circular(18);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceContainerLow(context),
        borderRadius: cardRadius,
        border: Border.all(
          color: highlight ? goldColor.withOpacity(0.55) : borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: cardRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: KajianCardBackground(
                photoUrl: kajian.fotoUstadz,
                overlayOpacity: hasPhoto ? 0.62 : 0,
                plainBaseColor: AppColors.getSurfaceContainerLow(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildDateBadge(context, kajian, hasPhoto: hasPhoto),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                kajian.judul,
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  height: 1.25,
                                  shadows: hasPhoto
                                      ? const [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 3,
                                            offset: Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isLive) ...[
                              const SizedBox(width: 8),
                              _buildStatusBadge(
                                label: 'LIVE',
                                icon: Icons.circle,
                                bgColor: goldColor,
                                fgColor: const Color(0xFF00120B),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: hasPhoto
                                  ? Colors.black.withOpacity(0.45)
                                  : goldColor.withOpacity(0.18),
                              child: Icon(
                                Icons.person_outline,
                                size: 12,
                                color: ustadzColor,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                kajian.ustadz,
                                style: TextStyle(
                                  color: ustadzColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildMetaRow(
                          context,
                          hasPhoto: hasPhoto,
                          metaColor: metaColor,
                          goldColor: goldColor,
                          kajian: kajian,
                          compact: true,
                        ),
                      ],
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

  Widget _buildDateBadge(
    BuildContext context,
    Kajian kajian, {
    required bool hasPhoto,
  }) {
    final goldColor = AppColors.getGoldLeaf(context);
    final textColor = AppColors.getTextPrimary(context);

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: hasPhoto
            ? Colors.black.withOpacity(0.5)
            : goldColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasPhoto
              ? Colors.white.withOpacity(0.25)
              : goldColor.withOpacity(0.35),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            kajian.tanggal.length >= 10
                ? kajian.tanggal.substring(8, 10)
                : '--',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: hasPhoto ? Colors.white : textColor,
            ),
          ),
          Text(
            _getMonthShort(kajian.tanggal),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: goldColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(
    BuildContext context, {
    required bool hasPhoto,
    required Color metaColor,
    required Color goldColor,
    required Kajian kajian,
    bool compact = false,
  }) {
    final double fontSize = compact ? 11 : 12;
    final double iconSize = compact ? 13 : 14;

    return Row(
      children: [
        Icon(Icons.schedule, color: metaColor, size: iconSize),
        const SizedBox(width: 4),
        Text(
          '${kajian.jamMulai} - ${kajian.jamSelesai}',
          style: TextStyle(
            color: metaColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.location_on_outlined, color: metaColor, size: iconSize),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            kajian.lokasi,
            style: TextStyle(color: metaColor, fontSize: fontSize),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color fgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fgColor, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // STATE KOSONG / LOADING / ERROR (senada halaman Fawaidh)
  // =====================================================================
  Widget _buildEmptyFeaturedState(BuildContext context, bool hasToday) {
    final surfaceColor = AppColors.getSurfaceContainerLow(context);
    final borderColor = AppColors.getSurfaceVariant(context);
    final subTextColor = AppColors.getOnSurfaceVariant(context);
    final goldColor = AppColors.getGoldLeaf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(
            hasToday ? Icons.check_circle_outline : Icons.event_busy_outlined,
            size: 48,
            color: goldColor.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            hasToday
                ? 'Tidak ada lagi kajian di hari ini'
                : 'Tidak ada kajian hari ini',
            style: TextStyle(
              color: AppColors.getTextPrimary(context),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            hasToday
                ? 'Semua jadwal kajian hari ini sudah selesai'
                : 'Cek jadwal kajian di hari-hari berikutnya di bawah',
            style: TextStyle(color: subTextColor, fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(
    BuildContext context, {
    required bool searched,
    bool onlyOthers = false,
  }) {
    final goldColor = AppColors.getGoldLeaf(context);
    final subTextColor = AppColors.getOnSurfaceVariant(context);

    final String title;
    final String subtitle;
    final IconData icon;

    if (searched) {
      icon = Icons.search_off_rounded;
      title = 'Kajian tidak ditemukan';
      subtitle = 'Coba gunakan kata kunci lain.';
    } else if (onlyOthers) {
      icon = Icons.event_note_outlined;
      title = 'Belum ada jadwal kajian lain';
      subtitle = 'Nantikan jadwal kajian berikutnya ya.';
    } else {
      icon = Icons.event_busy_outlined;
      title = 'Belum ada jadwal kajian';
      subtitle = 'Jadwal akan muncul di sini setelah ditambahkan.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 52, color: goldColor),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.6, color: subTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
          'Memuat jadwal kajian...',
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
            onPressed: _fetchKajian,
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

  // =====================================================================
  // HELPER WAKTU
  // =====================================================================
  bool _isKajianOngoing(Kajian kajian) {
    if (kajian.tanggal != _todayStr) return false;

    final now = DateTime.now();
    final nowTime =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    return nowTime.compareTo(kajian.jamMulai) >= 0 &&
        nowTime.compareTo(kajian.jamSelesai) <= 0;
  }

  String _getMonthShort(String tanggal) {
    final bulan = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MEI',
      'JUN',
      'JUL',
      'AGU',
      'SEP',
      'OKT',
      'NOV',
      'DES',
    ];
    if (tanggal.length < 7) return '';
    final month = int.tryParse(tanggal.substring(5, 7)) ?? 1;
    return bulan[month - 1];
  }
}

// ============================================================
// MODEL KAJIAN
// ============================================================
class Kajian {
  final String tanggal;
  final String judul;
  final String ustadz;
  final String jamMulai;
  final String jamSelesai;
  final String lokasi;
  final String? fotoUstadz;

  Kajian({
    required this.tanggal,
    required this.judul,
    required this.ustadz,
    required this.jamMulai,
    required this.jamSelesai,
    required this.lokasi,
    this.fotoUstadz,
  });

  factory Kajian.fromJson(Map<String, dynamic> json) {
    final String tanggalRaw = json['tanggal']?.toString() ?? '';
    final String tanggalClean = tanggalRaw.contains('T')
        ? tanggalRaw.split('T').first
        : tanggalRaw;

    final String jamMulaiRaw = json['jam_mulai']?.toString() ?? '';
    final String jamMulaiClean = jamMulaiRaw.length >= 5
        ? jamMulaiRaw.substring(0, 5)
        : jamMulaiRaw;

    final String jamSelesaiRaw = json['jam_selesai']?.toString() ?? '';
    final String jamSelesaiClean = jamSelesaiRaw.length >= 5
        ? jamSelesaiRaw.substring(0, 5)
        : jamSelesaiRaw;

    return Kajian(
      tanggal: tanggalClean,
      judul: json['judul'] ?? '',
      ustadz: json['ustadz'] ?? '',
      jamMulai: jamMulaiClean,
      jamSelesai: jamSelesaiClean,
      lokasi: json['lokasi'] ?? '',
      fotoUstadz: json['foto_ustadz_url'] ?? json['foto_ustadz'],
    );
  }
}
