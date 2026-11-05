import Foundation
import Darwin

/// Minimal Solarman V5 client (Modbus RTU tunnelled over TCP 8899), modelled
/// on pysolarmanv5: same frame layout, checksum, sequence numbers and the
/// "counter" (0x4710) frames the logger sometimes interleaves.
///
/// Blocking I/O — call it from a background queue.
enum SolarmanError: LocalizedError {
    case resolve(String)
    case connect(String)
    case timeout
    case closed
    case frame(String)
    case modbusException(UInt8)

    var errorDescription: String? {
        switch self {
        case .resolve(let m): return "Can't resolve inverter address: \(m)"
        case .connect(let m): return "Can't connect to logger: \(m)"
        case .timeout: return "Logger did not answer (timeout)"
        case .closed: return "Logger closed the connection"
        case .frame(let m): return "Bad frame from logger: \(m)"
        case .modbusException(let c): return "Inverter Modbus exception \(c)"
        }
    }
}

final class SolarmanClient {
    let host: String
    let port: UInt16
    let loggerSerial: UInt32
    let timeout: TimeInterval
    let slaveId: UInt8

    private var fd: Int32 = -1
    private var sequence: UInt8 = UInt8.random(in: 1...0xFE)
    private var buffer: [UInt8] = []

    init(host: String, loggerSerial: UInt32, port: UInt16 = 8899,
         timeout: TimeInterval = 10, slaveId: UInt8 = 1) {
        self.host = host
        self.loggerSerial = loggerSerial
        self.port = port
        self.timeout = timeout
        self.slaveId = slaveId
    }

    deinit { close() }

    var isConnected: Bool { fd >= 0 }

    // MARK: Connection

    func connect() throws {
        close()
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>?
        let rc = getaddrinfo(host, String(port), &hints, &res)
        guard rc == 0, let first = res else {
            throw SolarmanError.resolve(String(cString: gai_strerror(rc)))
        }
        defer { freeaddrinfo(res) }

        var lastError = "no address"
        var ai: UnsafeMutablePointer<addrinfo>? = first
        while let a = ai {
            let s = socket(a.pointee.ai_family, a.pointee.ai_socktype, a.pointee.ai_protocol)
            if s < 0 { lastError = String(cString: strerror(errno)); ai = a.pointee.ai_next; continue }
            var one: Int32 = 1
            setsockopt(s, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))

            // Non-blocking connect so we can apply our own timeout.
            let flags = fcntl(s, F_GETFL, 0)
            _ = fcntl(s, F_SETFL, flags | O_NONBLOCK)
            var ok = Darwin.connect(s, a.pointee.ai_addr, a.pointee.ai_addrlen) == 0
            if !ok && errno == EINPROGRESS {
                var pfd = pollfd(fd: s, events: Int16(POLLOUT), revents: 0)
                let pr = poll(&pfd, 1, Int32(timeout * 1000))
                if pr > 0 {
                    var err: Int32 = 0
                    var len = socklen_t(MemoryLayout<Int32>.size)
                    getsockopt(s, SOL_SOCKET, SO_ERROR, &err, &len)
                    if err == 0 {
                        ok = true
                    } else if err == EHOSTUNREACH {
                        // How macOS reports a Local Network privacy block.
                        lastError = "No route to host — allow Deye Monitor in System Settings → Privacy & Security → Local Network"
                    } else {
                        lastError = String(cString: strerror(err))
                    }
                } else {
                    lastError = pr == 0 ? "timed out" : String(cString: strerror(errno))
                }
            } else if !ok {
                lastError = errno == EHOSTUNREACH
                    ? "No route to host — allow Deye Monitor in System Settings → Privacy & Security → Local Network"
                    : String(cString: strerror(errno))
            }

            if ok {
                _ = fcntl(s, F_SETFL, flags & ~O_NONBLOCK)
                var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
                setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                setsockopt(s, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                fd = s
                buffer.removeAll()
                return
            }
            Darwin.close(s)
            ai = a.pointee.ai_next
        }
        throw SolarmanError.connect(lastError)
    }

    func close() {
        if fd >= 0 { Darwin.close(fd); fd = -1 }
        buffer.removeAll()
    }

    // MARK: Modbus

    /// Function 0x03 — read `count` holding registers starting at `start`.
    func readHoldingRegisters(_ start: UInt16, count: UInt16) throws -> [UInt16] {
        if fd < 0 { try connect() }
        var req: [UInt8] = [slaveId, 0x03,
                            UInt8(start >> 8), UInt8(start & 0xFF),
                            UInt8(count >> 8), UInt8(count & 0xFF)]
        let crc = Self.crc16(req)
        req += [UInt8(crc & 0xFF), UInt8(crc >> 8)]

        let rtu = try exchange(rtuRequest: req)
        return try Self.parseReadResponse(rtu, expected: Int(count), slaveId: slaveId)
    }

    static func parseReadResponse(_ m: [UInt8], expected: Int, slaveId: UInt8) throws -> [UInt16] {
        guard m.count >= 3 else { throw SolarmanError.frame("short Modbus response") }
        if m[1] & 0x80 != 0 { throw SolarmanError.modbusException(m[2]) }
        guard m[1] == 0x03 else { throw SolarmanError.frame("unexpected function \(m[1])") }
        let byteCount = Int(m[2])
        guard byteCount == expected * 2, m.count >= 3 + byteCount + 2 else {
            throw SolarmanError.frame("expected \(expected) registers, got \(byteCount / 2)")
        }
        // CRC over the ADU; some loggers append a second CRC (00 00), ignore extra bytes.
        let crc = crc16(Array(m[0..<(3 + byteCount)]))
        let got = UInt16(m[3 + byteCount]) | UInt16(m[4 + byteCount]) << 8
        guard crc == got else { throw SolarmanError.frame("Modbus CRC mismatch") }
        return stride(from: 3, to: 3 + byteCount, by: 2).map { UInt16(m[$0]) << 8 | UInt16(m[$0 + 1]) }
    }

    static func crc16(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for b in bytes {
            crc ^= UInt16(b)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1
            }
        }
        return crc
    }

    // MARK: V5 framing

    private func nextSequence() -> UInt8 {
        sequence = sequence &+ 1
        if sequence == 0 { sequence = 1 }
        return sequence
    }

    private func encode(_ rtu: [UInt8], seq: UInt8) -> [UInt8] {
        let length = UInt16(15 + rtu.count)
        var f: [UInt8] = [0xA5, UInt8(length & 0xFF), UInt8(length >> 8),
                          0x10, 0x45,            // control code 0x4510 (request)
                          seq, 0x00]             // sequence number
        withUnsafeBytes(of: loggerSerial.littleEndian) { f += $0 }
        f += [0x02, 0x00, 0x00]                 // frame type, sensor type
        f += [UInt8](repeating: 0, count: 12)   // delivery / power-on / offset time
        f += rtu
        f += [0x00, 0x15]                       // checksum placeholder, end
        f[f.count - 2] = Self.checksum(f)
        return f
    }

    static func checksum(_ f: [UInt8]) -> UInt8 {
        var sum: UInt32 = 0
        for i in 1..<(f.count - 2) { sum &+= UInt32(f[i]) }
        return UInt8(sum & 0xFF)
    }

    private func exchange(rtuRequest: [UInt8]) throws -> [UInt8] {
        let seq = nextSequence()
        let frame = encode(rtuRequest, seq: seq)
        try sendAll(frame)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let f = try nextFrame(deadline: deadline) {
                // Skip counter/heartbeat frames and stale replies.
                guard f.count >= 13 else { continue }
                if f[3] == 0x10 && f[4] == 0x47 { continue }
                guard f[5] == seq else { continue }
                return try decode(f)
            }
        }
        throw SolarmanError.timeout
    }

    private func decode(_ f: [UInt8]) throws -> [UInt8] {
        guard f.first == 0xA5, f.last == 0x15 else { throw SolarmanError.frame("bad start/end") }
        guard f[f.count - 2] == Self.checksum(f) else { throw SolarmanError.frame("bad V5 checksum") }
        let serial = UInt32(f[7]) | UInt32(f[8]) << 8 | UInt32(f[9]) << 16 | UInt32(f[10]) << 24
        guard serial == loggerSerial else {
            throw SolarmanError.frame("logger serial mismatch (got \(serial)) — check the logger SN")
        }
        guard f[3] == 0x10, f[4] == 0x15 else { throw SolarmanError.frame("unexpected control code") }
        guard f[11] == 0x02 else { throw SolarmanError.frame("unexpected frame type") }
        guard f.count > 27 else { throw SolarmanError.frame("no Modbus payload") }
        let rtu = Array(f[25..<(f.count - 2)])
        if rtu.count < 5 { throw SolarmanError.frame("no valid Modbus frame (logger busy?)") }
        return rtu
    }

    /// Pull one complete V5 frame out of the receive buffer, reading more as needed.
    private func nextFrame(deadline: Date) throws -> [UInt8]? {
        while true {
            if let start = buffer.firstIndex(of: 0xA5) {
                if start > 0 { buffer.removeFirst(start) }
                if buffer.count >= 3 {
                    let payload = Int(buffer[1]) | Int(buffer[2]) << 8
                    let total = 13 + payload
                    if total > 1024 { buffer.removeFirst(); continue }   // garbage
                    if buffer.count >= total {
                        let f = Array(buffer[0..<total])
                        buffer.removeFirst(total)
                        return f
                    }
                }
            } else {
                buffer.removeAll()
            }
            if Date() >= deadline { return nil }
            try receiveMore()
        }
    }

    private func receiveMore() throws {
        var chunk = [UInt8](repeating: 0, count: 1024)
        let n = recv(fd, &chunk, chunk.count, 0)
        if n > 0 { buffer += chunk[0..<n]; return }
        if n == 0 { close(); throw SolarmanError.closed }
        if errno == EAGAIN || errno == EWOULDBLOCK { throw SolarmanError.timeout }
        let msg = String(cString: strerror(errno))
        close()
        throw SolarmanError.connect(msg)
    }

    private func sendAll(_ bytes: [UInt8]) throws {
        var sent = 0
        while sent < bytes.count {
            let n = bytes[sent...].withUnsafeBytes { send(fd, $0.baseAddress, $0.count, 0) }
            if n <= 0 {
                let msg = String(cString: strerror(errno))
                close()
                throw SolarmanError.connect(msg)
            }
            sent += n
        }
    }
}
