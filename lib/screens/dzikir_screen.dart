import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:insyira_muslim_app/widgets/floating_audio_player.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/streak_service.dart';
import '../widgets/streak_week_card.dart';

class DzikirScreen extends StatefulWidget {
  const DzikirScreen({super.key});

  @override
  State<DzikirScreen> createState() => _DzikirScreenState();
}

class _DzikirScreenState extends State<DzikirScreen> {
  bool _isPagi = true;
  double _arabFontSize = 26.0;

  List<dynamic> _dzikirList = [];
  final Map<int, int> _counters = {};
  bool _isLoading = true;

  Map<String, dynamic>? _activeAudio;

  // ===== STATUS PENYELESAIAN DZIKIR =====
  final NotificationService _notificationService = NotificationService();
  final StreakService _streakService = StreakService();
  bool _completionNotified = false;

  /// Runtutan mingguan untuk kartu bulatan per-hari.
  RingkasanStreak? _ringkasan;

  @override
  void initState() {
    super.initState();
    _notificationService.init();
    _loadDzikirData();
    _muatRingkasan();
  }

  Future<void> _muatRingkasan() async {
    final RingkasanStreak ringkasan = await _streakService.ringkasan();
    if (!mounted) return;
    setState(() => _ringkasan = ringkasan);
  }

  /// Satu baris penjelas untuk kartu runtutan. Menyebut bagian mana yang
  /// masih kurang, bukan cuma "belum selesai".
  String get _keteranganDzikir {
    final RingkasanStreak? r = _ringkasan;
    if (r == null) return '';
    if (r.dzikirHariIniTuntas) return 'Dzikir pagi & sore selesai hari ini';

    final List<String> belum = <String>[
      if (!r.pagiTuntas) 'pagi',
      if (!r.soreTuntas) 'sore',
    ];
    return 'Belum tuntas: dzikir ${belum.join(' & ')}';
  }

  Future<void> _loadDzikirData() async {
    // Sesi mana yang sedang dibuka DIAMBIL DULU. Kalau tidak, pergantian
    // pagi/sore saat proses memuat bisa membuat penanda hariannya tertukar.
    final bool pagi = _isPagi;

    // Apakah sesi ini sudah tuntas HARI INI menurut data tersimpan, bukan
    // hanya menurut memori.
    //
    // Sebelumnya penanda ini hanya ada di memori, jadi menutup lalu membuka
    // aplikasi membuat perayaan & notifikasinya muncul lagi — dan runtutan
    // hariannya tidak pernah tercatat sama sekali.
    final bool sudahDitandai = await _streakService.dzikirSudahDitandai(
      isPagi: pagi,
    );

    try {
      final String response = await rootBundle.loadString('assets/dzikir.json');
      final data = await json.decode(response);

      if (!mounted) return;
      setState(() {
        _dzikirList = pagi ? data['pagi'] : data['sore'];
        _counters.clear();
        _isLoading = false;
        _activeAudio = null;
        _completionNotified = sudahDitandai;
      });
    } catch (e) {
      debugPrint("Gagal memuat JSON: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleWaktu(bool isPagi) {
    if (_isPagi != isPagi) {
      setState(() {
        _isPagi = isPagi;
        _isLoading = true;
      });
      _loadDzikirData();
    }
  }

  void _changeFontSize(double step) {
    setState(() {
      _arabFontSize += step;
      if (_arabFontSize < 20.0) _arabFontSize = 20.0;
      if (_arabFontSize > 40.0) _arabFontSize = 40.0;
    });
  }

  void _incrementCounter(int index, int target) {
    setState(() {
      int current = _counters[index] ?? 0;
      if (current < target) {
        _counters[index] = current + 1;
      }
    });
    // Cek apakah seluruh dzikir sudah selesai dibaca.
    _checkDzikirCompletion();
  }

  // =====================================================================
  // LOGIKA PENYELESAIAN DZIKIR
  // =====================================================================

  /// Jumlah bacaan yang sudah tuntas (counter >= target).
  int get _completedCount {
    int done = 0;
    for (int i = 0; i < _dzikirList.length; i++) {
      final int target = (_dzikirList[i]['target'] ?? 1) as int;
      if ((_counters[i] ?? 0) >= target) done++;
    }
    return done;
  }

  bool get _isAllCompleted =>
      _dzikirList.isNotEmpty && _completedCount == _dzikirList.length;

  /// Dipanggil setiap kali user menekan tombol counter.
  void _checkDzikirCompletion() {
    if (_completionNotified) return;
    if (!_isAllCompleted) return;

    _completionNotified = true;

    // 0. Catat penyelesaian hari ini (dipakai runtutan 🔥 dan sebagai
    //    penanda supaya perayaan & notifikasi tidak muncul dua kali sehari).
    _streakService
        .tandaiDzikirSelesai(isPagi: _isPagi)
        .then((_) => _muatRingkasan());

    // 1. Kirim notifikasi ke sistem (muncul di notification bar HP)
    _notificationService.showDzikirCompleted(isPagi: _isPagi);

    // 2. Tampilkan perayaan di dalam aplikasi
    _showDzikirCompletedDialog();
  }

  void _showDzikirCompletedDialog() {
    if (!mounted) return;

    final goldColor = AppColors.getGoldLeaf(context);
    final waktu = _isPagi ? 'pagi' : 'sore';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.getSurfaceContainerLow(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.getSurfaceVariant(dialogContext)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: goldColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: goldColor.withOpacity(0.4)),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: goldColor,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Alhamdulillah!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(dialogContext),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Kamu sudah menyelesaikan dzikir $waktu hari ini.\n'
                  'Semoga Allah menerima amal ibadahmu. 🤲',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.getOnSurfaceVariant(dialogContext),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldColor,
                      foregroundColor: const Color(0xFF00120B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _counters.clear();
                      // ⚠️ Sengaja TETAP `true`. Hari ini sudah tercatat
                      // tuntas, jadi perayaan & notifikasinya tidak boleh
                      // muncul lagi hanya karena user mengulang dzikirnya.
                      _completionNotified = true;
                    });
                  },
                  child: Text(
                    'Ulangi dzikir $waktu',
                    style: TextStyle(
                      color: AppColors.getGoldLeaf(dialogContext),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 👇 Helper cek apakah audio tersedia
  bool _hasAudio(Map<String, dynamic> dzikir) {
    final audio = dzikir['audio'];
    return audio != null && audio.toString().trim().isNotEmpty;
  }

  // 👇 Handler tombol play
  void _onPlayAudio(BuildContext context, Map<String, dynamic> dzikir) {
    if (!_hasAudio(dzikir)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.getGoldLeaf(context),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Audio untuk dzikir ini belum tersedia',
                  style: TextStyle(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.getSurfaceContainerLow(context),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 200,
            left: 20,
            right: 20,
          ),
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return;
    }
    setState(() {
      _activeAudio = dzikir;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            _activeAudio != null ? 180 : 120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 25),
              _buildSelectionCards(context),
              const SizedBox(height: 20),

              // Runtutan mingguan — diletakkan tepat di bawah tombol
              // pagi & petang, karena di situlah user menentukan sesi mana
              // yang sedang dikerjakan.
              if (_ringkasan != null)
                StreakWeekCard(
                  judul: 'Runtutan Dzikir',
                  ikon: Icons.local_fire_department_rounded,
                  runtutan: _ringkasan!.dzikir,
                  tanggalTuntas: _ringkasan!.tanggalDzikir,
                  tuntasHariIni: _ringkasan!.dzikirHariIniTuntas,
                  keteranganHariIni: _keteranganDzikir,
                ),
              const SizedBox(height: 30),
              _buildControls(context),
              const SizedBox(height: 15),

              if (!_isLoading && _dzikirList.isNotEmpty) ...[
                _buildProgressCard(context),
                const SizedBox(height: 20),
              ],

              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(
                    color: AppColors.getGoldLeaf(context),
                  ),
                )
              else if (_dzikirList.isEmpty)
                Center(
                  child: Text(
                    "Data dzikir kosong",
                    style: TextStyle(color: AppColors.getTextPrimary(context)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _dzikirList.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    return _buildDzikirCard(context, _dzikirList[index], index);
                  },
                ),
            ],
          ),
        ),

        // FLOATING AUDIO PLAYER
        if (_activeAudio != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 24.0, bottom: 4.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _activeAudio = null),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceContainerLow(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.getSurfaceVariant(context),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              Theme.of(context).brightness == Brightness.dark
                                  ? 0.4
                                  : 0.15,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: AppColors.getOnSurfaceVariant(context),
                      ),
                    ),
                  ),
                ),
                FloatingAudioPlayer(
                  // 👇 KUNCI UTAMA: key unik per audio, supaya widget di-recreate
                  // saat ganti audio → audio lama otomatis stop
                  key: ValueKey(_activeAudio!['audio']),
                  title: _activeAudio!['judul'] ?? 'Audio Dzikir',
                  audioUrl: _activeAudio!['audio'] as String,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Banner judul halaman Dzikir.
  ///
  /// Sebelumnya cuma dua baris teks di atas latar kosong. Sekarang dibuat
  /// banner bergradasi dengan label kecil ala "TERAKHIR DIBACA" di halaman
  /// Quran, supaya bahasa visualnya seragam.
  ///
  /// Warnanya sengaja DIPATOK hijau tua, bukan dari tema: gradasi gelap
  /// membuat teks putihnya tetap kontras di mode terang maupun gelap.
  Widget _buildHeader(BuildContext context) {
    final Color emas = AppColors.getGoldLeaf(context);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF003527), Color(0xFF0B6B49)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF003527).withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          // Motif hias: ikon besar tembus pandang. Cukup samar supaya jadi
          // tekstur, bukan gambar yang ikut dibaca.
          Positioned(
            right: -26,
            top: -30,
            child: Icon(
              Icons.auto_awesome,
              size: 150,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: emas,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.auto_awesome, size: 13, color: emas),
                    const SizedBox(width: 6),
                    Text(
                      'DZIKIR HARIAN',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.6,
                        color: emas,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Temukan ketenangan dalam mengingat Allah.',
                  style: TextStyle(
                    fontSize: 21,
                    height: 1.3,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 1,
                  width: 56,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _toggleWaktu(true),
            child: _buildTabCard(
              context,
              title: 'Pagi',
              subtitle: 'Dzikir Pagi',
              icon: Icons.wb_twilight,
              isActive: _isPagi,
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: GestureDetector(
            onTap: () => _toggleWaktu(false),
            child: _buildTabCard(
              context,
              title: 'Petang',
              subtitle: 'Dzikir Petang',
              icon: Icons.nights_stay_outlined,
              isActive: !_isPagi,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
  }) {
    final goldColor = AppColors.getGoldLeaf(context);
    final primaryColor = AppColors.getPrimaryText(context);
    final surfaceVariant = AppColors.getSurfaceVariant(context);
    final surfaceLow = AppColors.getSurfaceContainerLow(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isActive ? surfaceVariant : surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? goldColor.withOpacity(0.5) : surfaceVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.08,
            ),
            blurRadius: isActive ? 20 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: isActive ? goldColor : primaryColor, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: AppColors.getTextPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: isActive
                  ? goldColor
                  : AppColors.getOnSurfaceVariant(context),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ===== KARTU PROGRES DZIKIR =====
  Widget _buildProgressCard(BuildContext context) {
    final goldColor = AppColors.getGoldLeaf(context);
    final primaryColor = AppColors.getPrimaryText(context);
    final surfaceVariant = AppColors.getSurfaceVariant(context);
    final textColor = AppColors.getTextPrimary(context);
    final subTextColor = AppColors.getOnSurfaceVariant(context);

    final total = _dzikirList.length;
    final done = _completedCount;
    final progress = total == 0 ? 0.0 : done / total;
    final isDone = total > 0 && done == total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceContainerLow(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? goldColor.withOpacity(0.6) : surfaceVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDone ? Icons.verified_rounded : Icons.track_changes_rounded,
                size: 18,
                color: isDone ? goldColor : primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDone
                      ? 'Alhamdulillah, dzikir ${_isPagi ? 'pagi' : 'sore'} selesai!'
                      : 'Progres dzikir ${_isPagi ? 'pagi' : 'sore'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDone ? goldColor : textColor,
                  ),
                ),
              ),
              Text(
                '$done/$total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: subTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              tween: Tween<double>(begin: 0, end: progress),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(goldColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final surfaceVariant = AppColors.getSurfaceVariant(context);
    final primaryColor = AppColors.getPrimaryText(context);
    final textColor = AppColors.getTextPrimary(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryColor.withOpacity(0.3)),
          ),
          child: Text(
            '${_dzikirList.length} Bacaan',
            style: TextStyle(
              color: primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => _changeFontSize(-2.0),
              child: Text(
                'A-',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _changeFontSize(2.0),
              child: Text(
                'A+',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDzikirCard(
    BuildContext context,
    Map<String, dynamic> dzikir,
    int index,
  ) {
    int target = dzikir['target'] ?? 1;
    int currentCount = _counters[index] ?? 0;
    bool isCompleted = currentCount >= target;

    bool isPlayingThis = _activeAudio != null && _activeAudio == dzikir;
    final hasAudio = _hasAudio(dzikir); // 👈 cek audio

    final goldColor = AppColors.getGoldLeaf(context);
    final primaryColor = AppColors.getPrimaryText(context);
    final surfaceVariant = AppColors.getSurfaceVariant(context);
    final surfaceLow = AppColors.getSurfaceContainerLow(context);
    final textColor = AppColors.getTextPrimary(context);
    final subTextColor = AppColors.getOnSurfaceVariant(context);
    final shadowOpacity = Theme.of(context).brightness == Brightness.dark
        ? 0.4
        : 0.1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isCompleted ? goldColor : surfaceVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: goldColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // HEADER CARD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dzikir['judul'],
                  style: TextStyle(
                    color: goldColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _onPlayAudio(context, dzikir),
                    child: Icon(
                      isPlayingThis
                          ? Icons.volume_up_rounded
                          : (hasAudio
                                ? Icons.play_circle_fill
                                : Icons.volume_off_rounded),
                      color: isPlayingThis
                          ? goldColor
                          : (hasAudio
                                ? primaryColor
                                : subTextColor.withOpacity(0.5)),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.bookmark_border, color: subTextColor, size: 24),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),

          // ARABIC
          Text(
            dzikir['arab'],
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: _arabFontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
              fontFamily: 'LPMQ',
              height: 2.2,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 30),

          // LATIN
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: goldColor, width: 4)),
            ),
            child: Text(
              dzikir['latin'],
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: subTextColor,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ARTI
          Text(
            dzikir['arti'],
            style: TextStyle(fontSize: 14, color: subTextColor, height: 1.5),
          ),
          const SizedBox(height: 30),
          Divider(color: surfaceVariant),
          const SizedBox(height: 10),

          // COUNTER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.repeat, color: subTextColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Dibaca $target kali',
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _incrementCounter(index, target),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isCompleted ? goldColor : surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted
                          ? Colors.transparent
                          : primaryColor.withOpacity(0.5),
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            color: Color(0xFF00120B),
                            size: 24,
                          )
                        : Text(
                            currentCount.toString(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
