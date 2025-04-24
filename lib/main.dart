import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart'; // Tambahkan dependency ini
import 'dart:math' as math;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(BMIRecordAdapter());
  await Hive.openBox<BMIRecord>('bmiHistory');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BMI Voice by dr. Sapto',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: Colors.grey[50],
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme.copyWith(
                titleLarge: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.purple[900],
                ),
                bodyLarge: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.purple[800],
                ),
                bodyMedium: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: Colors.purple[700],
                ),
              ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const VoiceBMIPage(),
    );
  }
}

class VoiceBMIPage extends StatefulWidget {
  const VoiceBMIPage({super.key});

  @override
  VoiceBMIPageState createState() => VoiceBMIPageState();
}

class VoiceBMIPageState extends State<VoiceBMIPage>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final Box<BMIRecord> _historyBox = Hive.box<BMIRecord>('bmiHistory');
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts(); // Inisialisasi TTS

  // Dialog style constants
  final _dialogTitleStyle = TextStyle(color: Colors.black);
  final _textButtonStyle = TextButton.styleFrom(
    foregroundColor: Colors.purple[800],
  );
  final _filledButtonStyle = FilledButton.styleFrom(
    backgroundColor: Colors.purple[800],
  );
  final _deleteButtonStyle = FilledButton.styleFrom(
    backgroundColor: Colors.red,
  );

  double? _bmi;
  double? _heightCm;
  double? _weightKg;

  bool _isEnglish = false;
  bool _isMetric = true;
  bool _isBeepEnabled = true;
  double _beepVolume = 0.8; // Ubah dari 0.5 menjadi 0.8
  bool _isShowingDialog = false; // Add flag for dialog state

  bool _isSpeechAvailable = false;
  bool _isListening = false;
  bool _isManualInputActive = false;
  bool _isDataConfirmed = false;
  bool _showInstruction = true;
  bool _showListeningCard = false;
  bool _showClassification = false;
  bool _isSavedInSession = false;
  String _recognizedWords = '';

  bool _isSelectMode = false;
  final Map<int, bool> _selectedItems = {};

  late AnimationController _animationController;
  final GlobalKey _tableKey = GlobalKey();
  double _tableHeight = 0.0;

  Timer? _timeoutTimer;

  late Animation<double> _animation;

  String selectedRegion = 'WPRO'; // Default ke Asia-Pasifik

  @override
  void initState() {
    super.initState();
    _tts.setLanguage(_isEnglish ? 'en-US' : 'id-ID');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      reverseDuration: const Duration(milliseconds: 10),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureTableHeight();
    });

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeIn,
    )..addListener(() {
        setState(() {});
      });

    _animationController.repeat(reverse: true);
    _checkSpeechAvailability();
    _updateInitialText();

    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      if (result == ConnectivityResult.none && _speech.isListening) {
        _speech.stop();
        _showError(_isEnglish ? "Connection lost" : "Koneksi terputus");
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _animationController.dispose();
    _audioPlayer.dispose();
    _tts.stop();
    super.dispose();
  }

  void _updateInitialText() {
    setState(() {});
  }

  String get _weightUnit => _isMetric ? 'kg' : 'lbs';
  String get _heightUnit => _isMetric ? 'cm' : 'in';

  double get _weightDisplay =>
      _weightKg != null ? (_isMetric ? _weightKg! : _weightKg! * 2.20462) : 0.0;
  double get _heightDisplay =>
      _heightCm != null ? (_isMetric ? _heightCm! : _heightCm! / 2.54) : 0.0;

  String _formatNumber(double value) {
    if ((value % 1).abs() < 0.0001) {
      return value.toStringAsFixed(0);
    } else {
      return _isEnglish
          ? value.toStringAsFixed(1)
          : value.toStringAsFixed(1).replaceAll('.', ',');
    }
  }

  String _formatCleanNumber(double value) {
    // Jika angka adalah bulat (tidak ada desimal)
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    // Jika ada desimal, tampilkan dengan 1 angka di belakang koma
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _checkSpeechAvailability() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _logger.i('Microphone permission denied');
      _showError(_isEnglish
          ? 'Microphone permission required'
          : 'Izin mikrofon diperlukan');
      setState(() => _isSpeechAvailable = false);
      return;
    }

    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      _logger.i('No internet connection');
      _showError(_isEnglish
          ? 'No internet connection. Speech recognition requires internet.'
          : 'Tidak ada koneksi internet. Pengenalan suara memerlukan internet.');
      setState(() => _isSpeechAvailable = false);
      return;
    }

    final isAvailable = await _speech.initialize(
      onStatus: (status) => _logger.i('Speech status: $status'),
      onError: (error) {
        String errorMessage = error.errorMsg.contains('network')
            ? (_isEnglish
                ? 'Network error: Please check your internet connection.'
                : 'Kesalahan jaringan: Silakan periksa koneksi internet Anda.')
            : '${_isEnglish ? 'Error' : 'Kesalahan'}: ${error.errorMsg}';
        _logger.e('Speech error: ${error.errorMsg}');
        _showError(errorMessage);
      },
    );

    if (mounted) {
      _logger.i('Speech available: $isAvailable');
      setState(() => _isSpeechAvailable = isAvailable);
    }
  }

  Future<void> _startListening() async {
    _logger.i('Starting listening process');
    if (!_isSpeechAvailable) {
      _showError(_isEnglish
          ? 'Speech recognition not available. Please try again.'
          : 'Pengenalan suara tidak tersedia. Silakan coba lagi.');
      return;
    }

    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      _showError(_isEnglish
          ? 'No internet connection. Speech recognition requires internet.'
          : 'Tidak ada koneksi internet. Pengenalan suara memerlukan internet.');
      return;
    }

    if (!kIsWeb && _isBeepEnabled) {
      try {
        await _audioPlayer
            .setVolume(_beepVolume * 1.5); // Tambahkan amplifikasi 1.5x
        await _audioPlayer.play(AssetSource('sounds/start_beep.mp3'));
      } catch (e) {
        _logger.e('Error playing sound: $e');
      }
    }

    setState(() {
      _isListening = true;
      _recognizedWords = '';
      _heightCm = null;
      _weightKg = null;
      _bmi = null;
      _showListeningCard = true;
      _showInstruction = false;
      _isDataConfirmed = false;
      _isSavedInSession = false;
    });

    _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _recognizedWords = result.recognizedWords;
            _extractData(result.recognizedWords);
          });
        }
        if (result.finalResult) {
          _processSpeech(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 6),
      localeId: _isEnglish ? 'en_US' : 'id_ID',
      listenMode: stt.ListenMode.dictation,
    );

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_speech.isListening) {
        _speech.stop();
        if (!kIsWeb && _isBeepEnabled) {
          try {
            _audioPlayer.setVolume(_beepVolume);
            _audioPlayer.play(AssetSource('sounds/end_beep.mp3'));
          } catch (e) {
            _logger.e('Error playing end sound on timeout: $e');
          }
        }
      }
      setState(() {
        _isListening = false;
        _isManualInputActive = false;
        _showListeningCard = true;
      });
      _calculateBMI();
    });
  }

  void _processSpeech(String text) {
    _extractData(text);

    _logger.i('Status setelah ekstraksi: tinggi=$_heightCm, berat=$_weightKg');

    if (_heightCm != null && _weightKg != null) {
      if (mounted) {
        setState(() {
          _isDataConfirmed = true;
          _isListening = false;
          _isManualInputActive = false;
        });
        _calculateBMI();
        if (!kIsWeb && _isBeepEnabled) {
          try {
            _audioPlayer.setVolume(_beepVolume);
            _audioPlayer.play(AssetSource('sounds/end_beep.mp3'));
          } catch (e) {
            _logger.e('Error playing end sound on success: $e');
          }
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isListening = false;
          _isManualInputActive = false;
          _showListeningCard = true;
        });
        if (!kIsWeb && _isBeepEnabled) {
          try {
            _audioPlayer.setVolume(_beepVolume);
            _audioPlayer.play(AssetSource('sounds/end_beep.mp3'));
          } catch (e) {
            _logger.e('Error playing end sound on incomplete: $e');
          }
        }
        _logger.i('Data tidak lengkap, proses dihentikan');
      }
    }
  }

  void _extractData(String text) {
    if (_isDataConfirmed) return;

    try {
      _logger.i('Input suara mentah: $text');
      List<String> tokens = text.toLowerCase().split(' ');
      double? height;
      double? weight;

      // Penanda koreksi
      final correctionMarkers = ['eh', 'maksud', 'saya', 'bukan', 'sorry'];

      // Step 1: Ekstrak semua angka dan konteksnya
      for (int i = 0; i < tokens.length; i++) {
        String token = tokens[i];
        if (correctionMarkers.contains(token)) continue;

        if (RegExp(r'^\d+[,.]?\d*$').hasMatch(token)) {
          double value = double.parse(token.replaceAll(',', '.'));
          if (value <= 0) continue; // Skip nilai negatif atau nol

          String? prevToken =
              i > 0 && !correctionMarkers.contains(tokens[i - 1])
                  ? tokens[i - 1]
                  : null;
          String? nextToken = i < tokens.length - 1 &&
                  !correctionMarkers.contains(tokens[i + 1])
              ? tokens[i + 1]
              : null;

          // Step 2: Validasi dan konversi tinggi badan
          if (_isHeightToken(nextToken) || _isHeightKeyword(prevToken)) {
            double convertedHeight = _convertToHeight(value, nextToken);
            if (_isValidHeight(convertedHeight)) {
              height = convertedHeight;
            } else {
              _showError(_isEnglish
                  ? "Height must be 120-250 cm"
                  : "Tinggi harus 120-250 cm");
              return;
            }
          }

          // Step 3: Validasi dan konversi berat badan
          if (_isWeightToken(nextToken) || _isWeightKeyword(prevToken)) {
            double convertedWeight = _convertToWeight(value, nextToken);
            if (_isValidWeight(convertedWeight)) {
              weight = convertedWeight;
            } else {
              _showError(_isEnglish
                  ? "Weight must be 20-300 kg"
                  : "Berat harus 20-300 kg");
              return;
            }
          }
        }
      }

      // Step 4: Handle kasus dua angka tanpa konteks
      if (height == null && weight == null) {
        var numbers = tokens
            .where((t) => RegExp(r'^\d+[,.]?\d*$').hasMatch(t))
            .map((t) => double.parse(t.replaceAll(',', '.')))
            .toList();
        if (numbers.length == 2) {
          double firstNum = numbers[0] > numbers[1] ? numbers[0] : numbers[1];
          double secondNum = numbers[0] > numbers[1] ? numbers[1] : numbers[0];

          // Validasi sebelum menampilkan dialog
          if (_isValidHeight(firstNum) && _isValidWeight(secondNum)) {
            _showClarificationDialog(firstNum, secondNum);
            return;
          } else {
            _showError(_isEnglish
                ? "Invalid height or weight values"
                : "Nilai tinggi atau berat tidak valid");
            return;
          }
        }
      }

      // Step 5: Update state jika semua validasi berhasil
      if (mounted) {
        setState(() {
          _heightCm = height;
          _weightKg = weight;
          _logger.i('Data disimpan: tinggi=$_heightCm cm, berat=$_weightKg kg');
        });
      }
    } catch (e) {
      _logger.e('Error ekstraksi: $e');
      if (!_isDataConfirmed) {
        _showError(_isEnglish
            ? 'Error processing input'
            : 'Kesalahan memproses input');
      }
    }
  }

  // Helper methods untuk validasi
  bool _isHeightToken(String? token) {
    return token == 'cm' ||
        token == 'sentimeter' ||
        token == 'm' ||
        token == 'meter' ||
        token == 'inches' ||
        token == 'in';
  }

  bool _isHeightKeyword(String? token) {
    return token == 'tinggi' ||
        token == 'height' ||
        token == 'tb' ||
        token == 'tall';
  }

  bool _isWeightToken(String? token) {
    return token == 'kg' ||
        token == 'kilo' ||
        token == 'lbs' ||
        token == 'pounds';
  }

  bool _isWeightKeyword(String? token) {
    return token == 'berat' ||
        token == 'weight' ||
        token == 'bb' ||
        token == 'mass';
  }

  double _convertToHeight(double value, String? unit) {
    // Konversi meter ke cm terlebih dahulu
    if (unit == 'm' || unit == 'meter') {
      return value * 100;
    } else if (unit == 'inches' || unit == 'in') {
      return value * 2.54;
    }

    // Auto-detect meter jika nilai terlalu kecil
    if (value < 3) {
      // Asumsi input dalam meter
      return value * 100;
    }

    return value; // Asumsi sudah dalam cm
  }

  double _convertToWeight(double value, String? unit) {
    if (unit == 'lbs' || unit == 'pounds') {
      return value * 0.453592;
    }
    return value; // Assumed kg if no unit or kg unit
  }

  bool _isValidHeight(double heightInCm) {
    return heightInCm >= 120 && heightInCm <= 250;
  }

  bool _isValidWeight(double weight) {
    return weight >= 20 && weight <= 300;
  }

  void _calculateBMI() {
    if (_weightKg == null || _heightCm == null) {
      return;
    }

    try {
      final heightInMeter = _heightCm! / 100;
      final bmi = _weightKg! / (heightInMeter * heightInMeter);
      if (mounted) {
        setState(() {
          _bmi = bmi;
        });
      }
    } catch (e) {
      _logger.e('Error saat menghitung BMI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_isEnglish ? 'Error' : 'Kesalahan'}: $e',
            ),
            margin: EdgeInsets.only(
              bottom: 100.0,
              left: 16.0,
              right: 16.0,
            ),
          ),
        );
      }
    }
  }

  void _showClarificationDialog(double firstNum, double secondNum) {
    if (_isShowingDialog) return;
    _isShowingDialog = true;

    if (_speech.isListening) {
      _speech.stop();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            _isEnglish ? 'Confirm Data' : 'Konfirmasi Data',
            style: _dialogTitleStyle,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEnglish
                    ? 'Did you mean height $firstNum cm and weight $secondNum kg?'
                    : 'Apakah maksud Anda tinggi $firstNum cm dan berat $secondNum kg?',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _isShowingDialog = false;
                setState(() {
                  _heightCm = null;
                  _weightKg = null;
                  _bmi = null;
                  _isListening = false;
                  _isDataConfirmed = false;
                  _showListeningCard = true;
                  _showInstruction = false;
                  _recognizedWords = '';
                  _speech.cancel();
                });
                Future.delayed(Duration(milliseconds: 500), () {
                  if (mounted) {
                    _startListening();
                  }
                });
              },
              style: _textButtonStyle,
              child: Text(_isEnglish ? 'Retry' : 'Ulangi'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _isShowingDialog = false;
                setState(() {
                  _heightCm = firstNum;
                  _weightKg = secondNum;
                  _isDataConfirmed = true;
                  _isListening = false;
                  _showListeningCard = true;
                  _showInstruction = false;
                });
                _calculateBMI();
                if (!kIsWeb && _isBeepEnabled) {
                  try {
                    _audioPlayer.setVolume(_beepVolume);
                    _audioPlayer.play(AssetSource('sounds/end_beep.mp3'));
                  } catch (e) {
                    _logger.e('Error playing end sound on confirmation: $e');
                  }
                }
              },
              style: _filledButtonStyle,
              child: Text(
                _isEnglish ? 'Yes' : 'Ya',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _saveBMI() {
    final record = BMIRecord(_weightKg!, _heightCm!, _bmi!, DateTime.now());

    if (_historyBox.length >= 100) {
      _historyBox.deleteAt(0);
      _logger.i("Deleted oldest history entry to maintain limit of 100");
    }

    if (_historyBox.isNotEmpty && _historyBox.values.last.bmi == _bmi) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            _isEnglish ? 'Duplicate Data' : 'Data Duplikat',
            style: _dialogTitleStyle,
          ),
          content: Text(_isEnglish
              ? 'This data has been previously saved. Save again?'
              : 'Data ini sudah tersimpan sebelumnya. Simpan lagi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: _textButtonStyle,
              child: Text(_isEnglish ? 'No' : 'Tidak'),
            ),
            FilledButton(
              onPressed: () {
                _historyBox.add(record);
                _logger.i("Duplicate BMI saved: $_bmi");
                Navigator.pop(context);
              },
              style: _filledButtonStyle,
              child: Text(
                _isEnglish ? 'Yes' : 'Ya',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } else {
      _historyBox.add(record);
      _logger.i("BMI saved: $_bmi");
      setState(() {
        _isSavedInSession = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEnglish ? 'Data saved' : 'Data tersimpan',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.purple[800],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: EdgeInsets.only(
            bottom: 100.0,
            left: 16.0,
            right: 16.0,
          ),
        ),
      );
    }
  }

  void _showError(String message, {bool showRetry = true}) {
    if (!mounted) return;

    if (_isBeepEnabled) {
      _audioPlayer.play(AssetSource('sounds/error_beep.mp3'));
    }
    HapticFeedback.vibrate();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.purple[800],
          behavior: SnackBarBehavior.floating,
          action: showRetry
              ? SnackBarAction(
                  label: _isEnglish ? 'Try Again' : 'Coba Lagi',
                  textColor: Colors.white,
                  onPressed: _startListening,
                )
              : null,
          margin: EdgeInsets.only(
            bottom: 100.0,
            left: 16.0,
            right: 16.0,
          ),
        ),
      );
  }

  void _toggleSelectMode() {
    if (mounted) {
      setState(() {
        _isSelectMode = !_isSelectMode;
        _selectedItems.clear();
      });
    }
  }

  void _deleteSelected() {
    if (_selectedItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _isEnglish ? 'Delete Data?' : 'Hapus Data?',
          style: _dialogTitleStyle,
        ),
        content: Text(_isEnglish
            ? '${_selectedItems.length} data will be deleted'
            : '${_selectedItems.length} data akan dihapus'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: _textButtonStyle,
            child: Text(_isEnglish ? 'Cancel' : 'Batal'),
          ),
          FilledButton(
            onPressed: () {
              final indices =
                  _selectedItems.keys.where((k) => _selectedItems[k]!).toList();
              _historyBox.deleteAll(indices);
              _toggleSelectMode();
              Navigator.pop(context);
            },
            style: _deleteButtonStyle,
            child: Text(
              _isEnglish ? 'Delete' : 'Hapus',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(
              _isEnglish ? 'About' : 'Tentang',
              style: _dialogTitleStyle,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEnglish
                  ? 'This app is created by dr. Sapto Sutardi to calculate BMI (Body Mass Index).'
                  : 'Aplikasi ini dibuat oleh dr. Sapto Sutardi untuk menghitung IMT (Indeks Masa Tubuh), yang juga dikenal sebagai Body Mass Index (BMI) dalam bahasa Inggris.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              _isEnglish
                  ? 'The first app to assess weight status with BMI/IMT using voice input.'
                  : 'Aplikasi pertama yang menilai status berat badan dengan IMT/BMI menggunakan input suara.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              _isEnglish
                  ? 'Disclaimer: This app does not substitute for medical examination, nutritional status diagnosis, and advice from doctors or nutritionists.'
                  : 'Peringatan: Aplikasi ini tidak menggantikan pemeriksaan, dignosis status gizi, dan saran dari dokter atau ahli gizi',
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: _textButtonStyle,
            child: Text(_isEnglish ? 'Close' : 'Tutup'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                _isEnglish ? 'Settings' : 'Pengaturan',
                style: _dialogTitleStyle,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      _isEnglish ? 'Language' : 'Bahasa',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[800],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: DropdownButtonFormField<String>(
                      value: _isEnglish ? 'English' : 'Bahasa Indonesia',
                      decoration: InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'English',
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: 'Bahasa Indonesia',
                          child: Text('Bahasa Indonesia'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          final bool newEnglishValue = value == 'English';
                          setDialogState(() {
                            _isEnglish = newEnglishValue;
                          });
                          setState(() {
                            _isEnglish = newEnglishValue;
                            _tts.setLanguage(
                                newEnglishValue ? 'en-US' : 'id-ID');
                          });
                        }
                      },
                    ),
                  ),

                  // Divider
                  SizedBox(height: 16),
                  Divider(color: Colors.purple[200]),
                  SizedBox(height: 16),

                  // Units Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      _isEnglish ? 'Units' : 'Satuan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[800],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: DropdownButtonFormField<String>(
                      value:
                          _isMetric ? 'Metric (kg, cm)' : 'Imperial (lbs, in)',
                      decoration: InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Metric (kg, cm)',
                          child: Text('Metric (kg, cm)'),
                        ),
                        DropdownMenuItem(
                          value: 'Imperial (lbs, in)',
                          child: Text('Imperial (lbs, in)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          final bool newMetricValue =
                              value == 'Metric (kg, cm)';
                          setDialogState(() {
                            _isMetric = newMetricValue;
                          });
                          setState(() {
                            _isMetric = newMetricValue;
                          });
                        }
                      },
                    ),
                  ),

                  // Divider
                  SizedBox(height: 16),
                  Divider(color: Colors.purple[200]),
                  SizedBox(height: 16),

                  // Beep Sound Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      _isEnglish ? 'Beep Sound' : 'Suara Beep',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[800],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_isEnglish ? 'Enable Beep' : 'Aktifkan Beep'),
                        Switch(
                          value: _isBeepEnabled,
                          onChanged: (value) {
                            setDialogState(() {
                              _isBeepEnabled = value;
                            });
                            setState(() {
                              _isBeepEnabled = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Volume Section (only shown if beep is enabled)
                  if (_isBeepEnabled) ...[
                    SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        _isEnglish ? 'Beep Volume' : 'Volume Beep',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4.0,
                          thumbShape:
                              RoundSliderThumbShape(enabledThumbRadius: 8.0),
                          overlayShape:
                              RoundSliderOverlayShape(overlayRadius: 16.0),
                        ),
                        child: Slider(
                          value: _beepVolume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label:
                              '${(_beepVolume * 100).round()}%', // Tambahkan tanda %
                          onChanged: (value) {
                            setDialogState(() {
                              _beepVolume = value;
                            });
                            setState(() {
                              _beepVolume = value;
                              _audioPlayer.setVolume(value *
                                  1.5); // Tambahkan amplifikasi saat testing
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: _textButtonStyle,
                  child: Text(_isEnglish ? 'Close' : 'Tutup'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectMode
          ? AppBar(
              title: Text(_isEnglish ? 'History' : 'Riwayat'),
              backgroundColor: Colors.purple[50],
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _deleteSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _toggleSelectMode,
                ),
              ],
            )
          : AppBar(
              title: Row(
                children: [
                  Text(
                    'BMI Voice',
                    style: TextStyle(color: Colors.purple[900]),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'by dr. Sapto',
                    style: GoogleFonts.kaushanScript(
                      fontSize: 18,
                      color: Colors.purple[900],
                    ),
                  ),
                ],
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.purple[900]),
                  onSelected: (value) {
                    if (value == 'history') {
                      if (_historyBox.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isEnglish
                                  ? 'No history data available'
                                  : 'Tidak ada data riwayat',
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.purple[800],
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            margin: EdgeInsets.only(
                              bottom: 100.0,
                              left: 16.0,
                              right: 16.0,
                            ),
                          ),
                        );
                      } else {
                        _toggleSelectMode();
                      }
                    }
                    if (value == 'settings') _showSettingsDialog(context);
                    if (value == 'about') _showAboutDialog();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'history',
                      child: Text(_isEnglish ? 'History' : 'Riwayat'),
                    ),
                    PopupMenuItem(
                      value: 'settings',
                      child: Text(_isEnglish ? 'Settings' : 'Pengaturan'),
                    ),
                    PopupMenuItem(
                      value: 'about',
                      child: Text(_isEnglish ? 'About' : 'Tentang'),
                    ),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          Expanded(
            child: _isSelectMode
                ? _buildSelectableHistoryList()
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_showInstruction) _buildInitiateInstruction(),
                          if (_showListeningCard) _buildInputStatusCard(),
                          if (_isDataConfirmed && _bmi != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: (Colors.purple[100]),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey
                                        .withAlpha((0.3 * 255).toInt()),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      padding: const EdgeInsets.all(8),
                                      child: _buildHeightWeightDisplay()),
                                  _buildBMIGauge(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FilledButton(
                                  onPressed:
                                      _isSavedInSession ? null : _saveBMI,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isSavedInSession
                                            ? Icons.check
                                            : Icons.save,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isSavedInSession
                                            ? (_isEnglish
                                                ? 'Saved'
                                                : 'Tersimpan')
                                            : (_isEnglish ? 'Save' : 'Simpan'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          Container(
            color: Colors.purple[50]!.withAlpha((0.8 * 255).toInt()),
            height: 60,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 16,
                  top: 0,
                  child: _buildManualInputButton(),
                ),
                Positioned(
                  top: -40,
                  child: _buildMicSection(),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: RegionDrawer(
        selectedRegion: selectedRegion,
        onRegionSelected: (RegionData region) {
          setState(() {
            selectedRegion = region.code;
            // Di sini Anda bisa menambahkan logika untuk mengupdate
            // perhitungan BMI berdasarkan standar yang baru
          });
        },
      ),
    );
  }

  Widget _buildInitiateInstruction() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: (Colors.purple[100]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withAlpha((0.1 * 255).toInt()),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _isEnglish
                  ? 'Tap the microphone button below and say your height and weight in any unit (kg, cm, lbs, in).'
                  : 'Tekan tombol mikrofon di bawah dan ucapkan tinggi badan dan berat badan Anda dalam satuan apa saja (kg, cm, lbs, in).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.purple[800],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.8 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEnglish ? 'Examples:' : 'Beberapa Contoh:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _isEnglish ? '"165 cm 60 kg"' : '"165 cm 60 kg"',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.purple[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(
                      color: Colors.purple[200],
                      thickness: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _isEnglish
                              ? '"Weight 60 kg height 165 cm"'
                              : '"Berat 60 kg tinggi 165 cm"',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.purple[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(
                      color: Colors.purple[200],
                      thickness: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _isEnglish
                              ? '"height 1.7 meter weight 65 kg"'
                              : '"tinggi 1,7 meter berat 65 kg"',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.purple[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(
                      color: Colors.purple[200],
                      thickness: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _isEnglish
                              ? '"170 cm weight 62 kg"'
                              : '"170 cm berat 62 kg"',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.purple[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(
                      color: Colors.purple[200],
                      thickness: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _isEnglish
                              ? '"TB 1.65 m BB 58 kg"'
                              : '"TB 1,65 m BB 58 kg"',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.purple[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputStatusCard() {
    _logger.i(
        'Building InputStatusCard, _isListening: $_isListening, _isManualInputActive: $_isManualInputActive, _isDataConfirmed: $_isDataConfirmed');

    if (_isShowingDialog) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.purple[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEnglish
                  ? 'Waiting for confirmation...'
                  : 'Menunggu konfirmasi...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.purple[800],
              ),
            ),
          ],
        ),
      );
    }

    String title;
    Widget? content;

    if (_isListening) {
      title = _isEnglish ? 'Listening...' : 'Mendengarkan...';
      final pattern = _isEnglish
          ? RegExp(
              r'(height|tall|weight|mass)?\s*(\d+[,.]?\d*)\s*(inches|in|lbs|pounds)?',
              caseSensitive: false,
            )
          : RegExp(
              r'(tinggi badan|tinggi|tb|berat|bb)?\s*(\d+[,.]?\d*)\s*(cm|sentimeter|kg|kilo|m|meter)?',
              caseSensitive: false,
            );

      final matches = pattern.allMatches(_recognizedWords).toList();

      List<TextSpan> textSpans = [];
      String remainingText = _recognizedWords;
      int lastEnd = 0;

      for (var match in matches) {
        final matchedText = match.group(0)!;
        final keyword = match.group(1)?.toLowerCase();
        final unit = match.group(3)?.toLowerCase();

        if (match.start > lastEnd) {
          textSpans.add(
            TextSpan(
              text: remainingText.substring(lastEnd, match.start),
            ),
          );
        }

        bool isWeight = _isEnglish
            ? (keyword == 'weight' ||
                keyword == 'mass' ||
                unit == 'lbs' ||
                unit == 'pounds')
            : (keyword == 'berat' ||
                keyword == 'bb' ||
                unit == 'kg' ||
                unit == 'kilo');
        bool isHeight = _isEnglish
            ? (keyword == 'height' ||
                keyword == 'tall' ||
                unit == 'inches' ||
                unit == 'in')
            : (keyword == 'tinggi' ||
                keyword == 'tinggi badan' ||
                keyword == 'tb' ||
                unit == 'cm' ||
                unit == 'sentimeter' ||
                unit == 'm' ||
                unit == 'meter');

        textSpans.add(
          TextSpan(
            text: matchedText,
            style: TextStyle(
              backgroundColor:
                  (isWeight || isHeight) ? Colors.yellow[100] : null,
            ),
          ),
        );

        lastEnd = match.end;
      }

      if (lastEnd < remainingText.length) {
        textSpans.add(
          TextSpan(
            text: remainingText.substring(lastEnd),
          ),
        );
      }

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Icon(
                Icons.record_voice_over_outlined,
                size: 24,
                color: Colors.purple[800],
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 16, color: Colors.purple[800]),
              children: textSpans.isNotEmpty
                  ? textSpans
                  : [
                      TextSpan(
                        text: _isEnglish
                            ? 'Say your weight and height'
                            : 'Ucapkan berat dan tinggi Anda',
                        style: TextStyle(color: Colors.purple[800]),
                      ),
                    ],
            ),
          ),
        ],
      );
    } else if (_isManualInputActive) {
      title = _isEnglish ? 'Manual Input' : 'Input Manual';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            _isEnglish
                ? 'Data entered manually'
                : 'Data telah dimasukkan secara manual',
            style: TextStyle(fontSize: 14),
          ),
        ],
      );
    } else {
      title = _isEnglish
          ? 'Confirmed Voice Input'
          : 'Input dari Suara Terkonfirmasi';

      List<TextSpan> textSpans = [];

      if (_heightCm != null && _weightKg != null) {
        textSpans.add(
          TextSpan(
            text: '${_formatCleanNumber(_heightCm!)} cm',
            style: TextStyle(
              fontSize: 14,
              backgroundColor: Colors.yellow[100],
            ),
          ),
        );
        textSpans.add(TextSpan(text: ' '));
        textSpans.add(
          TextSpan(
            text: '${_formatCleanNumber(_weightKg!)} kg',
            style: TextStyle(
              fontSize: 14,
              backgroundColor: Colors.yellow[100],
            ),
          ),
        );
      } else {
        textSpans.add(
          TextSpan(
            text: _isEnglish
                ? 'Incomplete data: Please provide both height and weight.'
                : 'Data tidak lengkap: Harap sebutkan tinggi dan berat.',
            style: TextStyle(color: Colors.red[700]),
          ),
        );
      }

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(
                    Icons.check_circle,
                    size: 24,
                    color: Colors.green[800],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 16, color: Colors.purple[800]),
              children: textSpans,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.purple[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: content,
    );
  }

  Widget _buildSelectableHistoryList() {
    return ValueListenableBuilder(
      valueListenable: _historyBox.listenable(),
      builder: (context, Box<BMIRecord> box, _) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: box.length,
          itemBuilder: (context, index) {
            final record = box.getAt(index);
            return CheckboxListTile(
              value: _selectedItems[index] ?? false,
              onChanged: (value) => setState(() {
                _selectedItems[index] = value!;
              }),
              title: Text('BMI: ${_formatNumber(record!.bmi)}'),
              subtitle: Text(
                  '${_formatNumber(record.weight)} $_weightUnit, ${_formatNumber(record.height)} $_heightUnit'),
              secondary: Text(
                '${DateFormat('dd/MM/yy').format(record.timestamp)}\n${DateFormat('HH:mm').format(record.timestamp)}',
                textAlign: TextAlign.right,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeightWeightDisplay() {
    String formatNumber(double? value) {
      if (value == null) return 'N/A';
      String formatted = value.toStringAsFixed(1).replaceAll('.', ',');
      if (formatted.endsWith(',0')) {
        return formatted.substring(0, formatted.length - 2);
      }
      return formatted;
    }

    return Container(
      width: double.infinity,
      color: (Colors.purple[100]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: _isEnglish ? 'Height ' : 'TB: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.purple[800],
                  ),
                ),
                TextSpan(
                  text: formatNumber(_heightCm),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800],
                  ),
                ),
                TextSpan(
                  text: ' cm',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.purple[800],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            '|',
            style: TextStyle(
              fontSize: 14,
              color: Colors.purple[800],
            ),
          ),
          SizedBox(width: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: _isEnglish ? 'Weight ' : 'BB: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.purple[800],
                  ),
                ),
                TextSpan(
                  text: formatNumber(_weightKg),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800],
                  ),
                ),
                TextSpan(
                  text: ' kg',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.purple[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBMIGauge() {
    if (_bmi == null || _heightCm == null || _weightKg == null) {
      return Text(_isEnglish ? 'Waiting for data...' : 'Menunggu data...');
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final double gaugeWidth = screenWidth * 0.8;
    final double segmentWidth = gaugeWidth / 5;
    const double gaugeFontSize = 9.0;

    final double arrowPosition =
        _calculateArrowPosition(_bmi!, gaugeWidth, segmentWidth);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            _buildTopSection(screenWidth),
            const SizedBox(height: 14),
            _buildGaugeSection(gaugeWidth, gaugeFontSize, arrowPosition),
            _buildRiskTable(),
          ],
        ),
      ),
    );
  }

  double _calculateArrowPosition(
      double bmi, double gaugeWidth, double segmentWidth) {
    if (bmi < 18.5) {
      final double minPosition = gaugeWidth * 0.05;
      double calculatedPositionUnderweight = (bmi / 18.5) * segmentWidth;
      return math.max(calculatedPositionUnderweight, minPosition);
    } else if (bmi < 23) {
      return segmentWidth + ((bmi - 18.5) / (22.9 - 18.5)) * segmentWidth;
    } else if (bmi < 25) {
      return 2 * segmentWidth + ((bmi - 23) / (24.9 - 23)) * segmentWidth;
    } else if (bmi < 30) {
      return 3 * segmentWidth + ((bmi - 25) / (29.9 - 25)) * segmentWidth;
    } else {
      const double marginRight = 0.05;
      final double maxAllowedWidth = gaugeWidth * (1 - marginRight);
      final double basePosition = 4 * segmentWidth;
      final double extension = ((bmi - 30) / 20) * segmentWidth;
      return math.min(basePosition + extension, maxAllowedWidth);
    }
  }

  Widget _buildTopSection(double screenWidth) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              width: screenWidth * 0.3,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    'BMI',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                  ),
                  Text(
                    _formatNumber(_bmi!),
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: screenWidth * 0.7,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Flexible(
                    child: Text(
                      _getBMICategory(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getBMIColor(),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      _getWeightStatus(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            Colors.purple[50]!.withAlpha((0.8 * 255).toInt()),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${_isEnglish ? 'Ideal wt.' : 'BB Ideal'}: ${_formatNumber(_getIdealMinKg())}-${_formatNumber(_getIdealMaxKg())} $_weightUnit',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeSection(
      double gaugeWidth, double gaugeFontSize, double arrowPosition) {
    final standard = bmiStandards[selectedRegion]!;
    final thresholds = standard.thresholds;
    final categories = standard.categories;
    final colors = standard.colors;

    // Calculate flex values based on the number of categories
    final List<int> flexValues = [];

    for (int i = 0; i < categories.length; i++) {
      if (i == 0) {
        flexValues.add(80); // First segment (underweight)
      } else if (i == categories.length - 1) {
        flexValues.add(80); // Last segment (highest obesity)
      } else {
        flexValues.add(100); // Middle segments
      }
    }

    final totalFlex = flexValues.reduce((a, b) => a + b);
    final pixelsPerFlex = gaugeWidth / totalFlex;

    return Stack(
      alignment: Alignment.centerRight,
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: 24,
                  width: gaugeWidth,
                  child: Row(
                    children: List.generate(categories.length, (index) {
                      final startValue =
                          index == 0 ? 0.0 : thresholds[index - 1].toDouble();
                      final endValue = index < thresholds.length
                          ? thresholds[index].toDouble()
                          : double.infinity;
                      final color = colors[index];

                      return Expanded(
                        flex: flexValues[index],
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: index == 0
                                ? const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  )
                                : index == categories.length - 1
                                    ? const BorderRadius.only(
                                        topRight: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      )
                                    : null,
                          ),
                          child: Center(
                            child: Text(
                              index == 0
                                  ? '< ${_formatNumber(thresholds[0])}' // Menggunakan threshold pertama (18.5)
                                  : index == categories.length - 1
                                      ? '≥ ${_formatNumber(startValue)}'
                                      : '${_formatNumber(startValue)} - ${_formatNumber(endValue)}',
                              style: TextStyle(
                                fontSize: gaugeFontSize,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Positioned(
                  left: _calculateArrowPositionWithFlex(
                    bmi: _bmi!,
                    gaugeWidth: gaugeWidth,
                    thresholds: thresholds.map((t) => t.toDouble()).toList(),
                    flexValues: flexValues,
                    pixelsPerFlex: pixelsPerFlex,
                  ),
                  top: -30,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 6),
                        child: Text(
                          _formatNumber(_bmi!),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 24,
                        color: Colors.purple[800],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              width: gaugeWidth,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: List.generate(categories.length, (index) {
                  final category = categories[index];
                  final color = colors[index];
                  final isCurrent = _isCurrentCategory(
                    _bmi!,
                    index == 0 ? 0.0 : thresholds[index - 1].toDouble(),
                    index == categories.length - 1
                        ? double.infinity
                        : thresholds[index].toDouble(),
                  );

                  return Expanded(
                    flex: flexValues[index],
                    child: _buildCategoryLabel(
                      category,
                      color,
                      isCurrent: isCurrent,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _calculateArrowPositionWithFlex({
    required double bmi,
    required double gaugeWidth,
    required List<double> thresholds,
    required List<int> flexValues,
    required double pixelsPerFlex,
  }) {
    const double arrowOffset = 12.0;

    for (int i = 0; i < thresholds.length; i++) {
      final startValue = i == 0 ? 0.0 : thresholds[i - 1];
      final endValue = thresholds[i];

      if (bmi < endValue) {
        double position = 0.0;
        for (int j = 0; j < i; j++) {
          position += flexValues[j] * pixelsPerFlex;
        }

        final segmentWidth = flexValues[i] * pixelsPerFlex;
        final progress = (bmi - startValue) / (endValue - startValue);
        return position + (progress * segmentWidth) - arrowOffset;
      }
    }

    // If BMI is higher than the last threshold
    double position = 0.0;
    for (int i = 0; i < thresholds.length - 1; i++) {
      position += flexValues[i] * pixelsPerFlex;
    }
    return position + (flexValues.last * pixelsPerFlex) - arrowOffset;
  }

  bool _isCurrentCategory(double bmi, double startValue, double endValue) {
    return bmi >= startValue && bmi < endValue;
  }

  Widget _buildRiskTable() {
    // Tingkatkan nilai default minimum untuk tinggi tabel
    const double defaultMinHeight = 170.0;
    const double extraPadding = 16.0;

    return ClipRect(
      child: TweenAnimationBuilder<double>(
        tween: Tween(
          begin: _showClassification ? 0.0 : 1.0,
          end: _showClassification ? 1.0 : 0.0,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          final effectiveHeight =
              math.max(_tableHeight + extraPadding, defaultMinHeight);
          return SizedBox(
            height: effectiveHeight * value,
            child: SingleChildScrollView(
              child: child,
            ),
          );
        },
        child: _showClassification
            ? Builder(
                builder: (context) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _measureTableHeight();
                  });
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildBMIClassificationTable(),
                  );
                },
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildBMIClassificationTable() {
    final standard = bmiStandards[selectedRegion]!;
    final thresholds = standard.thresholds;
    final categories = standard.categories;
    final colors = standard.colors;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Colors.grey[50]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Table(
          key: _tableKey,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(2.0),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.5),
          },
          children: [
            TableRow(
              children: [
                _buildTableHeader(_isEnglish ? 'Category' : 'Kategori'),
                _buildTableHeader('BMI'),
                _buildTableHeader(_isEnglish ? 'Risk' : 'Risiko'),
              ],
            ),
            ..._buildTableRows(standard),
          ],
        ),
      ),
    );
  }

  List<TableRow> _buildTableRows(BMIThresholds standard) {
    final List<TableRow> rows = [];
    final thresholds = standard.thresholds;
    final categories = standard.categories;
    final colors = standard.colors;

    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final color = colors[i];
      final isCurrent = _isCurrentCategoryForTable(_bmi!, i, thresholds);

      String rangeText;
      if (i == 0) {
        rangeText = '< ${thresholds[0].toStringAsFixed(1)}';
      } else if (i == categories.length - 1) {
        rangeText = '≥ ${thresholds[i - 1].toStringAsFixed(1)}';
      } else {
        rangeText =
            '${thresholds[i - 1].toStringAsFixed(1)} - ${thresholds[i].toStringAsFixed(1)}';
      }

      rows.add(_buildTableRow(
        _toTitleCase(category),
        rangeText,
        _getRiskLevel(category),
        color,
        isCurrent,
      ));
    }

    return rows;
  }

  bool _isCurrentCategoryForTable(
      double bmi, int index, List<double> thresholds) {
    if (index == 0) {
      return bmi < thresholds[0];
    } else if (index == thresholds.length) {
      return bmi >= thresholds[index - 1];
    } else {
      return bmi >= thresholds[index - 1] && bmi < thresholds[index];
    }
  }

  TableRow _buildTableRow(
      String category, String range, String risk, Color color, bool isCurrent) {
    const double fontSize = 11;
    return TableRow(
      decoration: BoxDecoration(
        color: isCurrent ? color.withOpacity(0.1) : null,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(
            category,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(
            range,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(
            risk,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.purple,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildCategoryLabel(String title, Color color,
      {bool isCurrent = false}) {
    // Fungsi untuk memisahkan teks menjadi baris yang lebih baik
    List<String> _splitText(String text) {
      if (text.length <= 8) return [_toTitleCase(text)];

      // Daftar kata-kata majemuk yang umum dalam kategori BMI
      final compoundWords = {
        'underweight': ['Under', 'Weight'],
        'overweight': ['Over', 'Weight'],
        'pre-obese': ['Pre', 'Obese'],
        'obese i': ['Obese', 'I'],
        'obese ii': ['Obese', 'II'],
        'obese iii': ['Obese', 'III'],
        'obese iv': ['Obese', 'IV'],
        'bb kurang': ['BB', 'Kurang'],
        'bb lebih': ['BB', 'Lebih'],
        'bb normal': ['BB', 'Normal'],
      };

      // Cek apakah teks adalah kata majemuk yang sudah kita ketahui
      final lowerText = text.toLowerCase();
      if (compoundWords.containsKey(lowerText)) {
        return compoundWords[lowerText]!;
      }

      // Jika tidak, gunakan Title Case untuk setiap kata
      final words = text.split(' ');
      if (words.length > 1) {
        final firstLine =
            words.take(words.length ~/ 2).map(_toTitleCase).join(' ');
        final secondLine =
            words.skip(words.length ~/ 2).map(_toTitleCase).join(' ');
        return [firstLine, secondLine];
      }

      final midPoint = text.length ~/ 2;
      final splitPoints = [' ', '-', '_'];
      int bestSplit = midPoint;

      for (int i = midPoint - 2; i <= midPoint + 2; i++) {
        if (i > 0 && i < text.length && splitPoints.contains(text[i])) {
          bestSplit = i + 1;
          break;
        }
      }

      return [
        _toTitleCase(text.substring(0, bestSplit)),
        _toTitleCase(text.substring(bestSplit))
      ];
    }

    final lines = _splitText(title);

    return GestureDetector(
      onTap: isCurrent
          ? () {
              setState(() {
                _showClassification = !_showClassification;
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: isCurrent
            ? BoxDecoration(
                color: color.withAlpha(50),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...lines.map((line) => Text(
                  line,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                )),
            SizedBox(
              height: 16,
              child: isCurrent
                  ? Icon(
                      _showClassification
                          ? Icons.keyboard_double_arrow_up
                          : Icons.keyboard_double_arrow_down,
                      size: 16,
                      color: Colors.grey[600],
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _getWeightStatus() {
    if (_heightCm == null || _weightKg == null) {
      return _isEnglish ? 'Data incomplete' : 'Data belum lengkap';
    }
    final heightM = _heightCm! / 100;
    final idealMinKg = 18.5 * heightM * heightM;
    final idealMaxKg = 22.9 * heightM * heightM;
    final currentWeight = _weightKg!;

    if (currentWeight < idealMinKg) {
      return _isEnglish
          ? 'Need +${_formatNumber(idealMinKg - currentWeight)} $_weightUnit'
          : 'Perlu +${_formatNumber(idealMinKg - currentWeight)} $_weightUnit';
    } else if (currentWeight > idealMaxKg) {
      return _isEnglish
          ? 'Need -${_formatNumber(currentWeight - idealMaxKg)} $_weightUnit'
          : 'Perlu -${_formatNumber(currentWeight - idealMaxKg)} $_weightUnit';
    } else {
      return _isEnglish ? 'Ideal!' : 'Ideal!';
    }
  }

  double _getIdealMinKg() {
    if (_heightCm == null) return 0;
    final heightM = _heightCm! / 100;
    return 18.5 * heightM * heightM;
  }

  double _getIdealMaxKg() {
    if (_heightCm == null) return 0;
    final heightM = _heightCm! / 100;
    return 22.9 * heightM * heightM;
  }

  String _getBMICategory() {
    if (_bmi! < 18.5) return _isEnglish ? 'Underweight' : 'BB Kurang';
    if (_bmi! < 23) return _isEnglish ? 'Normal Weight' : 'BB Normal';
    if (_bmi! < 25) {
      return _isEnglish ? 'Overweight with Risk' : 'BB lebih dgn Risiko';
    }
    if (_bmi! < 30) return _isEnglish ? 'Obese I' : 'Obes I';
    return _isEnglish ? 'Obese II' : 'Obes II';
  }

  Color _getBMIColor() {
    if (_bmi! < 18.5) return Colors.blue;
    if (_bmi! < 23) return Colors.green;
    if (_bmi! < 25) return Colors.orange;
    if (_bmi! < 30) return Colors.deepOrange;
    return Colors.red;
  }

  String _getRiskLevel(String category) {
    switch (category.toLowerCase()) {
      case 'underweight':
        return _isEnglish ? 'Low' : 'Rendah';
      case 'normal':
      case 'normal weight':
        return _isEnglish ? 'Average' : 'Rata-rata';
      case 'overweight':
      case 'pre-obese':
        return _isEnglish ? 'Increased' : 'Meningkat';
      case 'obese':
      case 'obese i':
        return _isEnglish ? 'Moderate' : 'Menengah';
      case 'obese ii':
        return _isEnglish ? 'Severe' : 'Tinggi';
      case 'obese iii':
        return _isEnglish ? 'Very High' : 'Sangat Tinggi';
      case 'obese iv':
        return _isEnglish ? 'Extremely High' : 'Ekstrem Tinggi';
      default:
        return _isEnglish ? 'Unknown' : 'Tidak Diketahui';
    }
  }

  Widget _buildMicSection() {
    bool isTouched = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onPanDown: (_) {
            _logger.i('Mic button pressed');
            setState(() {
              isTouched = true;
            });
            if (_isSpeechAvailable) {
              _logger.i('Mic button touched');
              _startListening();
            } else {
              _logger.i('Mic not available');
              _showError(_isEnglish
                  ? 'Speech recognition not available'
                  : 'Pengenalan suara tidak tersedia');
            }
          },
          onPanEnd: (_) {
            setState(() {
              isTouched = false;
            });
          },
          onPanCancel: () {
            setState(() {
              isTouched = false;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withAlpha((0.3 * 255).toInt()),
                  spreadRadius: isTouched ? 4 : 2,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: isTouched ? 0.95 : 1.0,
                        child: SiriLogoWidgetV2(
                          animationValue: _animation.value,
                          isActive: true,
                        ),
                      ),
                      if (!_isSpeechAvailable)
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.withAlpha((0.5 * 255).toInt()),
                          ),
                          child: const Icon(
                            Icons.mic_off,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildManualInputButton() {
    return GestureDetector(
      onTap: _showManualInputDialog,
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.keyboard,
              color: Colors.deepPurple,
              size: 24,
            ),
            const SizedBox(height: 1),
            const Text(
              'Manual',
              style: TextStyle(
                color: Colors.deepPurple,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualInputDialog() {
    final weightController = TextEditingController();
    final heightController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _isEnglish ? 'Manual Input' : 'Input Manual',
          style: _dialogTitleStyle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: InputDecoration(
                labelText: '${_isEnglish ? 'Weight' : 'Berat'} ($_weightUnit)',
                labelStyle: _dialogTitleStyle,
                icon: Icon(Icons.scale, color: Colors.purple[800]),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: heightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: InputDecoration(
                labelText: '${_isEnglish ? 'Height' : 'Tinggi'} ($_heightUnit)',
                labelStyle: _dialogTitleStyle,
                icon: Icon(Icons.straighten, color: Colors.purple[800]),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: _textButtonStyle,
            child: Text(_isEnglish ? 'Cancel' : 'Batal'),
          ),
          FilledButton(
            onPressed: () => _handleManualInput(
                weightController.text, heightController.text, context),
            style: _filledButtonStyle,
            child: Text(
              _isEnglish ? 'Calculate' : 'Hitung',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _handleManualInput(String weight, String height, BuildContext context) {
    if (weight.isEmpty || height.isEmpty) {
      _showError(_isEnglish ? 'Fill all fields' : 'Isi semua kolom');
      return;
    }

    final parsedWeight = _parseNumber(weight);
    final parsedHeight = _parseNumber(height);

    if (parsedWeight == null || parsedHeight == null) {
      _showError(_isEnglish ? 'Invalid number' : 'Angka tidak valid');
      return;
    }

    if (parsedHeight < 50 || parsedHeight > 250) {
      _showError(
          _isEnglish ? "Height must be 50-250 cm" : "Tinggi harus 50-250 cm");
      return;
    }
    if (parsedWeight < 20 || parsedWeight > 300) {
      _showError(
          _isEnglish ? "Weight must be 20-300 kg" : "Berat harus 20-300 kg");
      return;
    }

    setState(() {
      _weightKg = _isMetric ? parsedWeight : parsedWeight * 0.453592;
      _heightCm = _isMetric ? parsedHeight : parsedHeight * 2.54;
      _isDataConfirmed = true;
      _showListeningCard = true;
      _showInstruction = false;
      _isManualInputActive = true;
      _isListening = false;
      _isSavedInSession = false;
    });

    Navigator.pop(context);
    _calculateBMI();
  }

  double? _parseNumber(String value) {
    final cleanedValue =
        value.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleanedValue);
  }

  void _measureTableHeight() {
    final RenderBox? renderBox =
        _tableKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      final newHeight = renderBox.size.height;
      if (newHeight > 0 && newHeight != _tableHeight) {
        setState(() {
          _tableHeight = newHeight;
          _logger.i('Table height measured: $_tableHeight');
        });
      }
    }
  }

  String _toTitleCase(String text) {
    // Daftar kata yang harus tetap uppercase
    final upperCaseWords = ['BB', 'TB', 'BMI', 'I', 'II', 'III', 'IV'];
    if (upperCaseWords.contains(text)) return text;

    // Pisahkan kata berdasarkan spasi dan strip
    final words = text.split(RegExp(r'[ -]'));
    final titleCaseWords = words.map((word) {
      if (word.isEmpty) return word;
      // Jika kata ada dalam daftar uppercase, kembalikan apa adanya
      if (upperCaseWords.contains(word.toUpperCase())) {
        return word.toUpperCase();
      }
      // Ubah ke Title Case
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    });

    // Gabungkan kembali dengan mempertahankan pemisah asli (spasi atau strip)
    var result = text;
    for (var i = 0; i < words.length; i++) {
      result = result.replaceFirst(words[i], titleCaseWords.elementAt(i));
    }
    return result;
  }
}

class SiriLogoWidgetV2 extends StatelessWidget {
  final double animationValue;

  const SiriLogoWidgetV2({
    super.key,
    required this.animationValue,
    required bool isActive,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final outerDiameter = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final innerDiameter = outerDiameter * 0.75;

        return Center(
          child: SizedBox(
            width: outerDiameter,
            height: outerDiameter,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(outerDiameter, outerDiameter),
                  painter: SiriLogoPainter2(
                    animationValue: animationValue,
                    innerDiameter: innerDiameter,
                    outerDiameter: outerDiameter,
                  ),
                ),
                Container(
                  width: innerDiameter,
                  height: innerDiameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Center(
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: [Colors.deepPurple, Colors.purpleAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds);
                      },
                      child: const Icon(
                        Icons.mic,
                        size: 24,
                        color: Colors.white,
                      ),
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
}

class SiriLogoPainter2 extends CustomPainter {
  final double animationValue;
  final double innerDiameter;
  final double outerDiameter;

  SiriLogoPainter2({
    required this.animationValue,
    required this.innerDiameter,
    required this.outerDiameter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minRadius = innerDiameter / 2;
    final maxRadius = outerDiameter / 2;
    final currentRadius = minRadius + (maxRadius - minRadius) * animationValue;

    final gradient = SweepGradient(
      colors: const [
        Colors.purpleAccent,
        Colors.blueAccent,
        Colors.cyanAccent,
        Colors.greenAccent,
        Colors.purpleAccent,
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      transform: GradientRotation(animationValue * 3.1416 * 2),
    ).createShader(Rect.fromCircle(center: center, radius: currentRadius));

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, currentRadius, paint);
  }

  @override
  bool shouldRepaint(covariant SiriLogoPainter2 oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.innerDiameter != innerDiameter ||
      oldDelegate.outerDiameter != outerDiameter;
}

@HiveType(typeId: 0)
class BMIRecord extends HiveObject {
  @HiveField(0)
  final double weight;
  @HiveField(1)
  final double height;
  @HiveField(2)
  final double bmi;
  @HiveField(3)
  final DateTime timestamp;

  BMIRecord(this.weight, this.height, this.bmi, this.timestamp);
}

class BMIRecordAdapter extends TypeAdapter<BMIRecord> {
  @override
  final int typeId = 0;

  @override
  BMIRecord read(BinaryReader reader) {
    return BMIRecord(
      reader.readDouble(),
      reader.readDouble(),
      reader.readDouble(),
      reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, BMIRecord obj) {
    writer.writeDouble(obj.weight);
    writer.writeDouble(obj.height);
    writer.writeDouble(obj.bmi);
    writer.write(obj.timestamp);
  }
}

// Buat class untuk menyimpan data regional/negara
class RegionData {
  final String name;
  final IconData icon; // Menggunakan IconData alih-alih iconPath
  final String code;
  final Map<String, double> bmiThresholds;

  RegionData({
    required this.name,
    required this.icon,
    required this.code,
    required this.bmiThresholds,
  });
}

// Update daftar region dengan Material Icons
final List<RegionData> regions = [
  RegionData(
    name: 'WHO (Global)',
    icon: Icons.public, // Icon globe untuk standar global
    code: 'WHO',
    bmiThresholds: {
      'underweight': 18.5,
      'normal': 24.9,
      'overweight': 29.9,
      'obese': 30.0,
    },
  ),
  RegionData(
    name: 'Asia-Pasifik (WPRO)',
    icon: Icons.terrain, // Icon untuk merepresentasikan Asia-Pasifik
    code: 'WPRO',
    bmiThresholds: {
      'underweight': 18.5,
      'normal': 22.9,
      'overweight': 24.9,
      'obese': 25.0,
    },
  ),
  RegionData(
    name: 'China (WGOC)',
    icon: Icons.architecture, // Icon untuk merepresentasikan China
    code: 'CN',
    bmiThresholds: {
      'underweight': 18.5,
      'normal': 23.9,
      'overweight': 27.9,
      'obese': 28.0,
    },
  ),
  RegionData(
    name: 'Japan (JASSO)',
    icon: Icons.temple_buddhist, // Icon untuk merepresentasikan Jepang
    code: 'JP',
    bmiThresholds: {
      'underweight': 18.5,
      'normal': 22.9,
      'pre_obese': 24.9,
      'obese_1': 29.9,
      'obese_2': 34.9,
      'obese_3': 39.9,
      'obese_4': 40.0,
    },
  ),
  RegionData(
    name: 'India',
    icon: Icons.mosque, // Icon untuk merepresentasikan India
    code: 'IN',
    bmiThresholds: {
      'underweight': 18.5,
      'normal': 22.9,
      'overweight': 24.9,
      'obese': 25.0,
    },
  ),
  RegionData(
    name: 'Singapore',
    icon: Icons.location_city, // Icon untuk merepresentasikan Singapura
    code: 'SG',
    bmiThresholds: {
      'underweight': 18.5,
      'normal': 22.9,
      'overweight': 27.4,
      'obese': 27.5,
    },
  ),
];

class RegionDrawer extends StatefulWidget {
  final String selectedRegion;
  final Function(RegionData) onRegionSelected;

  const RegionDrawer({
    Key? key,
    required this.selectedRegion,
    required this.onRegionSelected,
  }) : super(key: key);

  @override
  State<RegionDrawer> createState() => _RegionDrawerState();
}

class _RegionDrawerState extends State<RegionDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.health_and_safety,
                  size: 48,
                  color: Colors.white,
                ),
                SizedBox(height: 12),
                Text(
                  'Standar BMI Regional',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Pilih standar yang sesuai dengan region Anda',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: regions.length,
              itemBuilder: (context, index) {
                final region = regions[index];
                final isSelected = region.code == widget.selectedRegion;

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : null,
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.1),
                      ),
                      child: Icon(
                        region.icon,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[600],
                        size: 24,
                      ),
                    ),
                    title: Text(
                      region.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    subtitle: Text(
                      _getRegionDescription(region),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    onTap: () {
                      widget.onRegionSelected(region);
                      Navigator.pop(context);
                    },
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Standar BMI akan mempengaruhi kategori dan rekomendasi yang diberikan',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRegionDescription(RegionData region) {
    switch (region.code) {
      case 'WHO':
        return 'Standar internasional WHO';
      case 'WPRO':
        return 'Disesuaikan untuk populasi Asia-Pasifik';
      case 'CN':
        return 'Standar nasional China';
      case 'JP':
        return 'Standar JASSO dengan 4 tingkat obesitas';
      case 'IN':
        return 'Kriteria khusus populasi India';
      case 'SG':
        return 'Standar kesehatan Singapura';
      default:
        return '';
    }
  }
}

class BMIThresholds {
  final String name;
  final List<double> thresholds;
  final List<String> categories;
  final List<Color> colors;

  BMIThresholds({
    required this.name,
    required this.thresholds,
    required this.categories,
    required this.colors,
  });
}

final Map<String, BMIThresholds> bmiStandards = {
  'WHO': BMIThresholds(
    name: 'WHO (Global)',
    thresholds: [18.5, 25.0, 30.0, 35.0, 40.0],
    categories: [
      'Underweight',
      'Normal',
      'Overweight',
      'Obese I',
      'Obese II',
      'Obese III'
    ],
    colors: [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.red[700]!,
      Colors.red[900]!
    ],
  ),
  'WPRO': BMIThresholds(
    name: 'Asia-Pasifik (WPRO)',
    thresholds: [18.5, 23.0, 25.0, 30.0],
    categories: ['Underweight', 'Normal', 'Overweight', 'Obese I', 'Obese II'],
    colors: [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.red[900]!
    ],
  ),
  'CN': BMIThresholds(
    name: 'China (WGOC)',
    thresholds: [18.5, 24.0, 28.0],
    categories: ['Underweight', 'Normal', 'Overweight', 'Obese'],
    colors: [Colors.blue, Colors.green, Colors.orange, Colors.red],
  ),
  'JP': BMIThresholds(
    name: 'Japan (JASSO)',
    thresholds: [18.5, 23.0, 25.0, 30.0, 35.0, 40.0],
    categories: [
      'Underweight',
      'Normal',
      'Pre-obese',
      'Obese I',
      'Obese II',
      'Obese III',
      'Obese IV'
    ],
    colors: [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.deepOrange,
      Colors.red,
      Colors.red[700]!,
      Colors.red[900]!
    ],
  ),
  'IN': BMIThresholds(
    name: 'India',
    thresholds: [18.5, 23.0, 25.0, 30.0],
    categories: ['Underweight', 'Normal', 'Overweight', 'Obese I', 'Obese II'],
    colors: [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.red[900]!
    ],
  ),
  'SG': BMIThresholds(
    name: 'Singapore',
    thresholds: [18.5, 23.0, 27.5],
    categories: ['Underweight', 'Normal', 'Overweight', 'Obese'],
    colors: [Colors.blue, Colors.green, Colors.orange, Colors.red],
  ),
};
