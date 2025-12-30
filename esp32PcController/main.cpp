#include <windows.h>
#include <winhttp.h>
#include <string>
#include <thread>
#include <vector>
#include <sstream>

// 链接 WinHTTP 库
#pragma comment(lib, "winhttp.lib")

// ==================================================================================
// 关键修复：
// 1. 强制将子系统设置为 WINDOWS (后台/GUI模式)，解决 "无法解析的外部符号 main" 错误。
// 2. 指定入口点为 WinMainCRTStartup，确保正确调用 WinMain 而不是 main。
// ==================================================================================
#pragma comment(linker, "/SUBSYSTEM:WINDOWS /ENTRY:WinMainCRTStartup")

// ================= 配置区域 =================
const std::wstring SERVER_IP = L"192.168.31.87";   // 后端服务器 IP
const INTERNET_PORT SERVER_PORT = 8080;

// TODO: 请在此处修改为单片机的实际 IP 地址
const std::wstring ESP32_IP = L"192.168.31.134";    // 单片机 IP
const INTERNET_PORT ESP32_PORT = 8080;

const std::wstring API_BASE = L"/api";
const std::string USERNAME = "admin";
const std::string PASSWORD = "123456";
// ===========================================

// 日志辅助函数：后台运行时没有控制台，使用 OutputDebugString
void Log(const std::string& msg) {
    std::string finalMsg = msg + "\n";
    OutputDebugStringA(finalMsg.c_str());
}

// 简单的宽字符转换帮助函数
std::wstring StringToWString(const std::string& s) {
    if (s.empty()) return std::wstring();
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, &s[0], (int)s.size(), NULL, 0);
    std::wstring wstrTo(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, &s[0], (int)s.size(), &wstrTo[0], size_needed);
    return wstrTo;
}

std::string WStringToString(const std::wstring& s) {
    if (s.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &s[0], (int)s.size(), NULL, 0, NULL, NULL);
    std::string strTo(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &s[0], (int)s.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
}

// 发送 HTTP 请求的通用函数 (已重构：支持指定 IP、端口和完整路径)
std::string SendRequest(const std::wstring& ip, INTERNET_PORT port, const std::wstring& method, const std::wstring& path, const std::string& headers, const std::string& body) {
    std::string responseData = "";
    HINTERNET hSession = NULL, hConnect = NULL, hRequest = NULL;

    // 1. 初始化 WinHTTP
    hSession = WinHttpOpen(L"PcShutdownClient/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!hSession) return "";

    // 2. 连接指定服务器
    hConnect = WinHttpConnect(hSession, ip.c_str(), port, 0);
    if (!hConnect) { WinHttpCloseHandle(hSession); return ""; }

    // 3. 创建请求 (直接使用传入的 path，不再自动拼接 API_BASE)
    hRequest = WinHttpOpenRequest(hConnect, method.c_str(), path.c_str(), NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, 0);
    if (!hRequest) { WinHttpCloseHandle(hConnect); WinHttpCloseHandle(hSession); return ""; }

    // 4. 添加 Headers
    std::wstring wHeaders = StringToWString(headers);
    if (!headers.empty()) {
        WinHttpAddRequestHeaders(hRequest, wHeaders.c_str(), (DWORD)wHeaders.length(), WINHTTP_ADDREQ_FLAG_ADD);
    }

    // 5. 发送请求
    BOOL bResults = WinHttpSendRequest(hRequest, WINHTTP_NO_ADDITIONAL_HEADERS, 0, (LPVOID)body.c_str(), (DWORD)body.length(), (DWORD)body.length(), 0);

    // 6. 接收响应
    if (bResults) {
        bResults = WinHttpReceiveResponse(hRequest, NULL);
    }

    // 7. 读取数据
    if (bResults) {
        DWORD dwSize = 0;
        DWORD dwDownloaded = 0;
        do {
            dwSize = 0;
            if (!WinHttpQueryDataAvailable(hRequest, &dwSize)) break;
            if (dwSize == 0) break;

            std::vector<char> buffer(dwSize + 1);
            if (WinHttpReadData(hRequest, &buffer[0], dwSize, &dwDownloaded)) {
                buffer[dwDownloaded] = '\0';
                responseData += &buffer[0];
            }
        } while (dwSize > 0);
    }
    else {
        Log("请求失败，错误代码: " + std::to_string(GetLastError()));
    }

    // 清理句柄
    if (hRequest) WinHttpCloseHandle(hRequest);
    if (hConnect) WinHttpCloseHandle(hConnect);
    if (hSession) WinHttpCloseHandle(hSession);

    return responseData;
}

// 简单的 JSON 字符串提取工具
std::string ExtractJsonValue(const std::string& json, const std::string& key) {
    std::string searchKey = "\"" + key + "\"";
    size_t pos = json.find(searchKey);
    if (pos == std::string::npos) return "";

    size_t valueStart = json.find_first_of(": \t\n", pos + searchKey.length());
    if (valueStart == std::string::npos) return "";
    valueStart = json.find_first_not_of(": \t\n", valueStart);
    if (valueStart == std::string::npos) return "";

    char firstChar = json[valueStart];

    if (firstChar == '\"') {
        size_t endQuote = json.find('\"', valueStart + 1);
        if (endQuote != std::string::npos) {
            return json.substr(valueStart + 1, endQuote - valueStart - 1);
        }
    }
    else {
        size_t endVal = json.find_first_of(",}", valueStart);
        if (endVal != std::string::npos) {
            return json.substr(valueStart, endVal - valueStart);
        }
    }
    return "";
}

std::string g_token = "";

bool Login() {
    Log("正在登录服务器...");
    std::string body = "{\"username\":\"" + USERNAME + "\",\"password\":\"" + PASSWORD + "\"}";
    std::string headers = "Content-Type: application/json";

    // 注意：这里手动拼接 API_BASE
    std::string response = SendRequest(SERVER_IP, SERVER_PORT, L"POST", API_BASE + L"/login", headers, body);

    if (response.empty()) {
        Log("登录请求无响应");
        return false;
    }

    std::string token = ExtractJsonValue(response, "token");

    if (!token.empty()) {
        g_token = token;
        Log("登录成功! Token: " + g_token.substr(0, 10) + "...");
        return true;
    }
    else {
        Log("登录失败，服务器响应: " + response);
        return false;
    }
}

void CheckAndShutdown() {
    if (g_token.empty()) return;

    std::string headers = "token: " + g_token;
    // 获取状态：请求服务器
    std::string response = SendRequest(SERVER_IP, SERVER_PORT, L"GET", API_BASE + L"/esp32/getDeviceStatus", headers, "");

    if (response.empty()) {
        Log("获取状态失败");
        return;
    }

    std::string pcStatusStr = ExtractJsonValue(response, "pc");

    if (pcStatusStr == "true") {
        // 状态正常，不做任何事
    }
    else if (pcStatusStr == "false") {
        Log("[警告] 接收到关机指令 (pc: false)!");

        // === 关键修改：向单片机发送 GET 请求 ===
        Log("正在向单片机发送关机确认 (GET /pcturnoff)...");

        // 发送 GET 请求到单片机
        // 目标: http://ESP32_IP:8080/pcturnoff
        SendRequest(ESP32_IP, ESP32_PORT, L"GET", L"/pcturnoff", "", "");

        Log("已发送确认请求");
        // =================================

        Log("正在执行关机...");

        // 执行 Windows 关机命令
        system("shutdown /s /t 1 /c \"远程关机指令已触发\"");

        // 退出程序
        std::this_thread::sleep_for(std::chrono::seconds(20));
        exit(0);
    }
    else {
        Log("未知状态: " + pcStatusStr);
    }
}

// 使用 WinMain 作为入口点，并添加了 SAL 注解 (_In_, _In_opt_) 以修复警告
int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPSTR lpCmdLine, _In_ int nCmdShow) {
    // 防止程序重复运行 (单实例检查)
    HANDLE hMutex = CreateMutexA(NULL, TRUE, "Global\\PcShutdownAppMutex");
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        return 0; // 已经有一个实例在运行，直接退出
    }

    Log("========== PC 远程关机控制端 (后台运行) ==========");

    // 初始登录
    while (!Login()) {
        Log("5秒后重试登录...");
        std::this_thread::sleep_for(std::chrono::seconds(5));
    }

    // 主循环
    while (true) {
        CheckAndShutdown();

        // 每 5 秒轮询一次
        std::this_thread::sleep_for(std::chrono::seconds(5));
    }

    ReleaseMutex(hMutex);
    CloseHandle(hMutex);
    return 0;
}