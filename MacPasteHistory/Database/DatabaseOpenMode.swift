import SQLite3

enum DatabaseOpenMode {
    case readWriteCreate
    case readOnly

    var flags: Int32 {
        switch self {
        case .readWriteCreate:
            return SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        case .readOnly:
            return SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        }
    }
}
