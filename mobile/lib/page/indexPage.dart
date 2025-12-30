import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../config/frontConfig.dart';

class Indexpage extends StatefulWidget {
  const Indexpage({super.key});

  @override
  State<Indexpage> createState() => _IndexpageState();
}

class _IndexpageState extends State<Indexpage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const MinePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isServoOn = false;
  bool isDesktopOn = false;
  bool isPageLoading = true;

  @override
  void initState() {
    super.initState();
    _initDeviceStatus();
  }

  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _initDeviceStatus() async {
    String? token = await _getToken();
    if (token == null) return;

    while (mounted) {
      try {
        var response = await http.get(
          Uri.parse("${FrontConfig.getServerUrl()}/api/user/getDeviceStatus"),
          headers: {
            "token": token,
            "Accept": "*/*",
          },
        );

        if (response.statusCode == 200) {
          var jsonResponse = jsonDecode(response.body);
          if (jsonResponse['code'] == 200) {
            Map<String, dynamic> data = jsonResponse['data'];

            if (data.isNotEmpty && data.containsKey('duoji') && data.containsKey('pc')) {
              setState(() {
                isServoOn = data['duoji'];
                isDesktopOn = data['pc'];
                isPageLoading = false;
              });
              return;
            }
          }
        }
      } catch (e) {}

      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _handleDeviceToggle(String deviceName, bool currentValue, Function(bool) onStateChanged) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Dialog(
          backgroundColor: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.blue),
                SizedBox(width: 20),
                Text("正在执行指令..."),
              ],
            ),
          ),
        );
      },
    );

    String? token = await _getToken();
    if (token == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    bool targetServo = deviceName == '舵机1' ? !isServoOn : isServoOn;
    bool targetPc = deviceName == '台式机' ? !isDesktopOn : isDesktopOn;

    try {
      var setResponse = await http.post(
        Uri.parse("${FrontConfig.getServerUrl()}/api/user/setDeviceStatus"),
        headers: {
          "Content-Type": "application/json",
          "token": token,
        },
        body: jsonEncode({
          "duoji": targetServo,
          "pc": targetPc,
        }),
      );

      if (setResponse.statusCode == 200) {
        var setJson = jsonDecode(setResponse.body);
        if (setJson['code'] == 200) {
          while (mounted) {
            await Future.delayed(const Duration(seconds: 1));

            var getResponse = await http.get(
              Uri.parse("${FrontConfig.getServerUrl()}/api/user/getDeviceStatus"),
              headers: {
                "token": token,
                "Accept": "*/*",
              },
            );

            if (getResponse.statusCode == 200) {
              var getJson = jsonDecode(getResponse.body);
              Map<String, dynamic> data = getJson['data'];

              if (data.isNotEmpty && data.containsKey('duoji') && data.containsKey('pc')) {
                bool currentServoStatus = data['duoji'];
                bool currentPcStatus = data['pc'];

                if (currentServoStatus == targetServo && currentPcStatus == targetPc) {
                  if (mounted) {
                    Navigator.pop(context);
                    onStateChanged(!currentValue);
                  }
                  return;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('远程控制'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isPageLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("正在同步设备状态..."),
          ],
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildControlCard(
            title: '舵机1',
            icon: Icons.settings_remote,
            isOn: isServoOn,
            onChanged: (value) {
              _handleDeviceToggle('舵机1', isServoOn, (newValue) {
                setState(() {
                  isServoOn = newValue;
                });
              });
            },
          ),
          const SizedBox(height: 16),
          _buildControlCard(
            title: '台式机',
            icon: Icons.desktop_windows,
            isOn: isDesktopOn,
            onChanged: (value) {
              _handleDeviceToggle('台式机', isDesktopOn, (newValue) {
                setState(() {
                  isDesktopOn = newValue;
                });
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlCard({
    required String title,
    required IconData icon,
    required bool isOn,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isOn ? Colors.blue : Colors.grey.withOpacity(0.1),
              child: Icon(icon, color: isOn ? Colors.white : Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOn ? Colors.blue : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOn ? "运行中" : "已关闭",
                        style: TextStyle(
                          fontSize: 12,
                          color: isOn ? Colors.blue : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: isOn,
              activeColor: Colors.blue,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(Icons.person, size: 40, color: Colors.blue),
            ),
            const SizedBox(height: 10),
            const Text(
              "Admin",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 10),
                        Text(
                          "关于项目",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    const Text(
                      "这是一个物联网远程控制应用，主要用于控制舵机设备以及远程唤醒或关闭台式计算机。",
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("当前版本", style: TextStyle(color: Colors.grey)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "v1.0.0",
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.remove('token');
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
                icon: const Icon(Icons.logout),
                label: const Text("退出登录"),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}