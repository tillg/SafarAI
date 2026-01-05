//
//  Logger.swift
//  Summa
//
//  Simple logging utility with timestamp and caller information
//

import Foundation
import os.log

// MARK: - Private Helpers

/// Shared date formatter for timestamp generation
private let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    formatter.timeZone = TimeZone.current
    return formatter
}()

/// Extracts class name from file path
/// - Parameter file: The file path (from #file)
/// - Returns: The class/struct name (filename without .swift extension)
private func extractClassName(from file: String) -> String {
    let filename = (file as NSString).lastPathComponent
    return filename.replacingOccurrences(of: ".swift", with: "")
}

// MARK: - Public Logging Functions

/// Global logging function with timestamp and caller information
/// - Parameters:
///   - message: The message to log
///   - function: The calling function (automatically captured)
///   - file: The calling file (automatically captured)
///   - line: The calling line number (automatically captured)
func log(
    _ message: String,
    function: String = #function,
    file: String = #file,
    line: Int = #line
) {
    #if DEBUG
    let timestamp = timestampFormatter.string(from: Date())
    let className = extractClassName(from: file)
    print("[\(timestamp)] [\(className).\(function):\(line)] \(message)")
    #endif
}

// MARK: - Error Logging

/// Private logger for error messages
private let errorLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Summa", category: "Error")

/// Log an error message (displays in red/orange in Xcode console)
/// - Parameters:
///   - message: The error message to log
///   - function: The calling function (automatically captured)
///   - file: The calling file (automatically captured)
///   - line: The calling line number (automatically captured)
func logError(
    _ message: String,
    function: String = #function,
    file: String = #file,
    line: Int = #line
) {
    let timestamp = timestampFormatter.string(from: Date())
    let className = extractClassName(from: file)

    // Use OSLog which Xcode displays with color coding
    let formattedMessage = "[\(timestamp)] [\(className).\(function):\(line)] \(message)"
    errorLogger.error("\(formattedMessage, privacy: .public)")
}
