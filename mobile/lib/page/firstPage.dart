import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/config/frontConfig.dart';
import 'package:shared_preferences/shared_preferences.dart';

class firstPage extends StatefulWidget {
  const firstPage({super.key});

  @override
  State<firstPage> createState() => _firstPageState();
}

class _firstPageState extends State<firstPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isObscure = true;
  bool _isCheckingToken = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAutoLogin() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      if (token != null && token.isNotEmpty) {
        var response = await http.get(
          Uri.parse("${FrontConfig.getServerUrl()}/api/checkToken"),
          headers: {
            "Accept": "*/*",
            "token": token,
          },
        );

        if (response.statusCode == 200) {
          var resJson = jsonDecode(response.body);
          if (resJson["code"] == 200 && resJson["data"]["isValid"] == true) {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/index');
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Auto login failed: $e");
    }

    if (mounted) {
      setState(() {
        _isCheckingToken = false;
      });
    }
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      String account = _accountController.text;
      String password = _passwordController.text;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("登录中..."),
              ],
            ),
          );
        },
      );

      try {
        var response = await http.post(
          Uri.parse("${FrontConfig.getServerUrl()}/api/login"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "username": account,
            "password": password
          }),
        );

        Navigator.of(context).pop();

        if (response.statusCode == 200) {
          var resJson = jsonDecode(response.body);
          if (resJson["code"] == 200) {
            String token = resJson['data']['token'];
            final SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('token', token);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('登录成功！欢迎回来, $account'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            await Future.delayed(const Duration(seconds: 1));
            Navigator.pushReplacementNamed(context, '/index');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('登录失败，账号或密码错误'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登录失败，网络错误'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('系统出错：${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingToken) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("正在连接服务器...", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_person_outlined,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 20),
                const Text(
                  "欢迎使用 Esp32 App",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _accountController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '账号',
                    hintText: '请输入用户名或邮箱',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '账号不能为空';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: '密码',
                    hintText: '请输入密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscure = !_isObscure;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '密码不能为空';
                    }
                    if (value.length < 6) {
                      return '密码长度不能少于6位';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '登 录',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}