#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>
#include <WiFiUdp.h>
#include <WakeOnLan.h>
#include <WebServer.h>

const char *ssid = "esp32Test";
const char *password = "123456";
String url = "http://192.168.137.1:8080/api";
String username = "admin";
String accountPassword = "123456";
String token = "";

// 电脑的MAC地址
const char *macAddress = "";

WiFiUDP UDP;
WakeOnLan WOL(UDP); // 创建WakeOnLan对象
unsigned int localUdpPort = 4210; // 定义UDP监听端口
char incomingPacket[255];         // 接收数据缓冲区

WebServer server(8080);

bool wifiConnected = false;

Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver(0x40);
bool pwmInitialized = false;

#define SERVO_FREQ 50 // 50Hz = 20ms 周期

// 360°舵机控制说明 (基于4096分辨率):
// 停止: 1.5ms -> (1.5 / 20) * 4096 ≈ 307
// 正转: >1.5ms (例如 2.0ms -> 410)
// 反转: <1.5ms (例如 1.0ms -> 205)
// 如果发现方向反了，可以交换 ON_PULSE 和 OFF_PULSE 的值
#define STOP_PULSE 307
#define ON_PULSE 205  // 交换方向：原410改为205
#define OFF_PULSE 410 // 交换方向：原205改为410
#define ON_DURATION 80 // 开启时长
#define OFF_DURATION 100 // 关闭时长

uint8_t servoNum = 0;
bool duoji = false;
bool pcState = false;

void wakePC()
{
  Serial.println("正在发送WOL唤醒包...");
  WOL.sendMagicPacket(macAddress);
  Serial.println("WOL魔术包发送完成!");
}

void triggerLightSwitch()
{
  if (!pwmInitialized)
    return;

  if (duoji)
  {
    pwm.setPWM(servoNum, 0, OFF_PULSE);
    delay(OFF_DURATION);
    pwm.setPWM(servoNum, 0, 4096); // 发送完全关闭信号(Full OFF)，强制停止
    duoji = false;
    Serial.println("关闭灯");
  }
  else
  {
    pwm.setPWM(servoNum, 0, ON_PULSE);
    delay(ON_DURATION);
    pwm.setPWM(servoNum, 0, 4096); // 发送完全关闭信号(Full OFF)，强制停止
    duoji = true;
    Serial.println("打开灯");
  }
}

void initServo()
{
  Serial.println("初始化舵机控制...");

  Wire.begin(21, 22);
  delay(100);

  Wire.beginTransmission(0x40);
  byte error = Wire.endTransmission();

  if (error == 0)
  {
    pwm.begin();
    pwm.setPWMFreq(SERVO_FREQ);
    pwmInitialized = true;
    pwm.setPWM(servoNum, 0, 4096); // 初始化时完全关闭信号，防止乱转
    Serial.println("PCA9685初始化成功");
  }
  else
  {
    Serial.println("PCA9685未连接");
    Serial.print("I2C错误代码: ");
    Serial.println(error);
  }

  delay(500);
}

void connectWiFi()
{
  Serial.println("\n正在连接到WiFi网络: " + String(ssid));
  WiFi.begin(ssid, password);

  Serial.print("连接中");
  int times = 0;
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
    times++;
    if (times > 30)
    {
      Serial.println("\nWiFi连接失败！");
      wifiConnected = false;
      return;
    }
  }

  if (WiFi.status() == WL_CONNECTED)
  {
    Serial.println("\nWiFi连接成功！");
    Serial.print("IP地址: ");
    Serial.println(WiFi.localIP());
    wifiConnected = true;

    // 设置广播地址（可选）
    WOL.calculateBroadcastAddress(WiFi.localIP(), WiFi.subnetMask());

    // 设置重复发送（可选）
    WOL.setRepeat(3, 100); // 重复发送3次，间隔100ms
  }
}

void loginToServer()
{
  if (!wifiConnected || WiFi.status() != WL_CONNECTED)
  {
    Serial.println("WiFi未连接，无法登录");
    return;
  }

  HTTPClient http;
  String fullUrl = url + "/login";
  http.begin(fullUrl);
  http.addHeader("Content-Type", "application/json");

  String jsonData = "{\"username\":\"" + username + "\",\"password\":\"" + accountPassword + "\"}";
  Serial.println("发送数据: " + jsonData);

  int httpCode = http.POST(jsonData);

  if (httpCode > 0)
  {
    Serial.print("HTTP响应代码: ");
    Serial.println(httpCode);

    if (httpCode == HTTP_CODE_OK)
    {
      String response = http.getString();
      Serial.println("服务器响应: " + response);
      Serial.println("登录成功！");
      DynamicJsonDocument doc(256);
      deserializeJson(doc, response);
      token = doc["data"]["token"].as<String>();
    }
    else
    {
      Serial.print("HTTP错误: ");
      Serial.println(httpCode);
    }
  }
  else
  {
    Serial.print("请求失败，错误: ");
    Serial.println(http.errorToString(httpCode));
  }

  http.end();
}

void setup()
{
  Serial.begin(115200);
  delay(5000);

  Serial.println("\n========== ESP32启动 ==========");

  initServo();

  connectWiFi();

  while (!wifiConnected)
  {
    Serial.println("等待WiFi连接...");
    delay(5000);
    connectWiFi();
  }

  loginToServer();

  server.on("/pcturnoff", []() {
    pcState = false;
    server.send(200, "text/plain", "Ok.");
    Serial.println("收到访问请求!");
  });

  // 设置处理 404 (未知路径) 的情况
  server.onNotFound([]() {
    server.send(404, "text/plain", "404: Not Found");
  });

  // 启动服务器
  server.begin();
  Serial.println("HTTP 服务器已启动");

  Serial.println("初始化完成");
}

void loop()
{
  server.handleClient();
  static unsigned long lastCheck = 0;
  static unsigned long lastSendData = 0;
  static unsigned long lastLoginAttempt = 0;
  static bool loggedIn = false;
  static unsigned long lastToggle = 0;

  if (millis() - lastCheck > 10000)
  {
    lastCheck = millis();

    if (WiFi.status() != WL_CONNECTED)
    {
      Serial.println("WiFi断开，尝试重连...");
      wifiConnected = false;
      loggedIn = false;
      connectWiFi();
    }
    else
    {
      if (!wifiConnected)
      {
        wifiConnected = true;
      }
      Serial.print("WiFi保持连接，信号强度: ");
      Serial.print(WiFi.RSSI());
      Serial.println(" dBm");

      if (wifiConnected && !loggedIn)
      {
        if (millis() - lastLoginAttempt > 3000)
        {
          lastLoginAttempt = millis();
          Serial.println("检测到未登录，尝试登录服务器...");
          loginToServer();
          loggedIn = true;
        }
      }
    }
  }

  if (millis() - lastSendData > 1000)
  {
    lastSendData = millis();
    if (loggedIn)
    {
      // Serial.println("token:"+token);
      HTTPClient http;
      http.begin(url + "/esp32/nowDeviceStatus");
      http.addHeader("Content-Type", "application/json");
      http.addHeader("token", token);
      // bool pc = false;
      String jsonData = "{\"duoji\":" + String(duoji ? "true" : "false") + ",\"pc\":" + String(pcState ? "true" : "false") + "}";
      http.POST(jsonData);
      http.end();

      HTTPClient httpGetDeviceStatus;
      httpGetDeviceStatus.begin(url + "/esp32/getDeviceStatus");
      httpGetDeviceStatus.addHeader("token", token);
      int httpCode = httpGetDeviceStatus.GET();
      if (httpCode == HTTP_CODE_OK)
      {
        String response = httpGetDeviceStatus.getString();
        Serial.println("服务器响应: " + response);
        DynamicJsonDocument doc(256);
        deserializeJson(doc, response);
        bool duojiNew = doc["data"]["duoji"].as<bool>();
        bool pcNew = doc["data"]["pc"].as<bool>();
        String message = doc["message"].as<String>();
        
        if (pcNew != pcState && message == "success")
        {
          if (pcNew)
          {
            wakePC();
            pcState = pcNew;
            // 立即更新状态
            HTTPClient http;
            http.begin(url + "/esp32/nowDeviceStatus");
            http.addHeader("Content-Type", "application/json");
            http.addHeader("token", token);
            String jsonData = "{\"duoji\":" + String(duoji ? "true" : "false") + ",\"pc\":" + String(pcState ? "true" : "false") + "}";
            http.POST(jsonData);
            http.end();
          }
        }

        if (duojiNew != duoji && message == "success")
        {
          triggerLightSwitch();
          HTTPClient http;
          http.begin(url + "/esp32/nowDeviceStatus");
          http.addHeader("Content-Type", "application/json");
          http.addHeader("token", token);
          // bool pc = false;
          String jsonData = "{\"duoji\":" + String(duoji ? "true" : "false") + ",\"pc\":" + String(pcState ? "true" : "false") + "}";
          http.POST(jsonData);
          http.end();
        }
      }
    }
  }

  // if (pwmInitialized && millis() - lastToggle > 5000) {
  //   lastToggle = millis();
  //   triggerLightSwitch();
  // }

  delay(100);
}
