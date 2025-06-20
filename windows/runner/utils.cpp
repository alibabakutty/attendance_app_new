#include "utils.h"
#include <flutter_windows.h>
#include <windows.h>
#include <shellapi.h>  // ✅ Required for CommandLineToArgvW
#include <io.h>
#include <stdio.h>
#include <iostream>
#include <vector>
#include <string>

// Converts a UTF-16 wide string to UTF-8.
std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }

  int input_length = static_cast<int>(wcslen(utf16_string));
  if (input_length == 0) {
    return std::string();
  }

  int target_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string, input_length,
      nullptr, 0, nullptr, nullptr);

  if (target_length == 0) {
    return std::string();  // Conversion failed
  }

  std::string utf8_string;
  utf8_string.resize(target_length);

  int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string, input_length,
      utf8_string.data(), target_length, nullptr, nullptr);

  if (converted_length == 0) {
    return std::string();
  }

  return utf8_string;
}

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE* unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  // Convert the UTF-16 command line arguments to UTF-8.
  int argc = 0;
  LPWSTR* argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  // Skip the first argument (executable path).
  for (int i = 1; i < argc; ++i) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);
  return command_line_arguments;
}
