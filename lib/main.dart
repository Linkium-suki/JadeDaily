import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';

// 全局时间通知器
final ValueNotifier<DateTime> timeNotifier = ValueNotifier(DateTime.now());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  
  runApp(const PorcelainApp());

  _initWindow();
  
  Timer.periodic(const Duration(seconds: 1), (timer) {
    timeNotifier.value = DateTime.now();
  });
}

Future<void> _initWindow() async {
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Color(0xFFF2F4F3),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize();
  });
}

class PorcelainApp extends StatelessWidget {
  const PorcelainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '凝脂画报',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F4F3),
        fontFamily: 'Microsoft YaHei',
      ),
      home: const PorcelainScreen(),
    );
  }
}

class PorcelainScreen extends StatefulWidget {
  const PorcelainScreen({super.key});

  @override
  State<PorcelainScreen> createState() => _PorcelainScreenState();
}

class _PorcelainScreenState extends State<PorcelainScreen> {
  String? _bingUrl;
  String? _bingTitle;
  String? _bingCopyright;
  String _hitokoto = "正在研墨...";
  String _author = "";
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final bingRes = await http.get(Uri.parse('https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=zh-CN'));
      final hitoRes = await http.get(Uri.parse('https://v1.hitokoto.cn/?c=i&c=d'));

      if (mounted) {
        setState(() {
          if (bingRes.statusCode == 200) {
            final json = jsonDecode(bingRes.body);
            final img = json['images'][0];
            _bingUrl = 'https://www.bing.com${img['url']}';
            _bingTitle = img['title'];
            _bingCopyright = img['copyright'];
          }
          if (hitoRes.statusCode == 200) {
            final json = jsonDecode(hitoRes.body);
            _hitokoto = json['hitokoto'];
            _author = json['from'];
          } else {
             _hitokoto = "行到水穷处，坐看云起时。";
             _author = "王维";
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Err: $e");
      if(mounted) {
        setState(() {
          _isLoading = false;
          _bingTitle = "网络连接微恙";
          _hitokoto = "且听风吟，静待花开。";
        });
      }
    }
  }

  void _toggleWindowMode() async {
    bool isFull = await windowManager.isFullScreen();
    if (isFull) {
      windowManager.setFullScreen(false);
      windowManager.maximize();
    } else {
      windowManager.setFullScreen(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
      body: GestureDetector(
        onDoubleTap: _toggleWindowMode,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // --- 层1：背景图 ---
            RepaintBoundary(
              child: _bingUrl != null
                ? Image.network(
                    _bingUrl!,
                    fit: BoxFit.cover,
                    color: const Color(0xFFF2F4F3).withOpacity(0.2),
                    colorBlendMode: BlendMode.lighten,
                    errorBuilder: (_,__,___) => Container(color: const Color(0xFFF2F4F3)),
                  )
                : Container(color: const Color(0xFFF2F4F3)),
            ),

            // --- 层2：UI 布局 ---
            if (_isLoading)
              const Center(child: Text("研墨中...", style: TextStyle(color: Colors.grey, letterSpacing: 4)))
            else
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Stack(
                    children: [
                      // === 左下角：瓷白玉牌 ===
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: PorcelainContainer(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ValueListenableBuilder<DateTime>(
                                  valueListenable: timeNotifier,
                                  builder: (context, now, _) {
                                    return Text(
                                      DateFormat('yyyy年MM月dd日 · EEEE', 'zh_CN').format(now),
                                      style: GoogleFonts.notoSerifSc(
                                        fontSize: 16, 
                                        color: const Color(0xFF5E616D),
                                        letterSpacing: 2
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: ValueListenableBuilder<DateTime>(
                                    valueListenable: timeNotifier,
                                    builder: (context, now, _) {
                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            _getTimeStringHour(now),
                                            style: GoogleFonts.maShanZheng(
                                              fontSize: 88,
                                              color: const Color(0xFF2B333E),
                                              height: 1.0,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Text("·", style: TextStyle(fontSize: 40, color: Colors.grey.withOpacity(0.5))),
                                          ),
                                          Text(
                                            _getTimeStringMinute(now),
                                            style: GoogleFonts.maShanZheng(
                                              fontSize: 88,
                                              color: const Color(0xFF2B333E),
                                              height: 1.0,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text(
                                  _bingTitle ?? "凝脂画报",
                                  style: GoogleFonts.notoSerifSc(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF333333),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _bingCopyright?.split(' (')[0] ?? "",
                                  style: GoogleFonts.notoSerifSc(
                                    fontSize: 14,
                                    color: const Color(0xFF666666),
                                    height: 1.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // === 右侧：诗词玉简 ===
                      Align(
                        alignment: Alignment.centerRight,
                        child: PorcelainContainer(
                          vertical: true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 80),
                                  VerticalText(
                                    text: _author.isEmpty ? "佚名" : _author,
                                    fontSize: 16,
                                    color: const Color(0xFF888888),
                                    fontFamily: GoogleFonts.notoSerifSc().fontFamily,
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFA64036).withOpacity(0.95),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text("雅趣", style: TextStyle(color: Colors.white, fontSize: 12)),
                                  )
                                ],
                              ),
                              const SizedBox(width: 36),
                              VerticalText(
                                text: _hitokoto,
                                fontSize: 34,
                                color: const Color(0xFF222222),
                                fontFamily: GoogleFonts.notoSerifSc().fontFamily,
                                letterSpacing: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // 刷新按钮
            Positioned(
              bottom: 20,
              right: 20,
              child: IconButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _fetchData();
                },
                icon: const Icon(Icons.refresh, color: Colors.black26),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final List<String> _cnNums = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
  String _numToCn(int n) {
    if (n <= 10) return _cnNums[n];
    if (n < 20) return "十${n==10?'':_cnNums[n%10]}";
    return "${_cnNums[n~/10]}十${n%10==0?'':_cnNums[n%10]}";
  }
  
  String _getTimeStringHour(DateTime t) => "${_numToCn(t.hour)}点";
  String _getTimeStringMinute(DateTime t) {
    int m = t.minute;
    if (m == 0) return "整";
    if (m < 10) return "零${_cnNums[m]}分";
    return "${_numToCn(m)}分";
  }
}

class PorcelainContainer extends StatelessWidget {
  final Widget child;
  final bool vertical;
  const PorcelainContainer({super.key, required this.child, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: vertical 
          ? const EdgeInsets.symmetric(horizontal: 28, vertical: 48)
          : const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8).withOpacity(0.92), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF869D7A).withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class VerticalText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final String? fontFamily;
  final double letterSpacing;

  const VerticalText({
    super.key,
    required this.text,
    required this.fontSize,
    required this.color,
    this.fontFamily,
    this.letterSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    List<String> chars = text.split('');
    return SizedBox(
      width: fontSize * 1.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: chars.map((e) {
          bool isPunct = "，。、；：？！".contains(e);
          return Container(
            margin: EdgeInsets.only(bottom: letterSpacing),
            alignment: isPunct ? Alignment.topRight : Alignment.center,
            child: Text(e, style: TextStyle(fontSize: fontSize, color: color, fontFamily: fontFamily, height: 1)),
          );
        }).toList(),
      ),
    );
  }
}