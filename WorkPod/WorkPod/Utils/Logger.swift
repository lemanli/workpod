import Foundation

class Logger {
    static let shared = Logger()
    
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    var minLevel: Level = .info
    var logToFile: Bool = false
    var logFileURL: URL?
    
    private init() {
        #if DEBUG
        self.minLevel = .debug
        #endif
    }
    
    func log(_ level: Level, message: String, file: String = #file, line: Int = #line, function: String = #function) {
        guard level.rawValue.compare(minLevel.rawValue, options: .caseInsensitive) != .orderedAscending else {
            return
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(message)"
        
        // 打印到控制台
        switch level {
        case .debug:
            print("\(logMessage)")
        case .info:
            print("\(logMessage)")
        case .warning:
            print("\(logMessage)")
        case .error:
            print("\(logMessage)")
        }
        
        // 写入文件
        if logToFile {
            writeToFile(logMessage)
        }
    }
    
    func debug(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(.debug, message: message, file: file, line: line, function: function)
    }
    
    func info(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(.info, message: message, file: file, line: line, function: function)
    }
    
    func warning(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(.warning, message: message, file: file, line: line, function: function)
    }
    
    func error(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        log(.error, message: message, file: file, line: line, function: function)
    }
    
    private func writeToFile(_ message: String) {
        if logFileURL == nil {
            let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Logs", isDirectory: true)
            try? FileManager.default.createDirectory(at: logsDir!, withIntermediateDirectories: true)
            logFileURL = logsDir?.appendingPathComponent("WorkPod.log")
        }
        
        guard let fileURL = logFileURL else { return }
        
        do {
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: "\(message)\n".data(using: .utf8)!)
            try handle.close()
        } catch {
            print("Failed to write to log file: \(error)")
        }
    }
}

// 便捷全局函数
func logDebug(_ message: String) { Logger.shared.debug(message) }
func logInfo(_ message: String) { Logger.shared.info(message) }
func logWarning(_ message: String) { Logger.shared.warning(message) }
func logError(_ message: String) { Logger.shared.error(message) }
