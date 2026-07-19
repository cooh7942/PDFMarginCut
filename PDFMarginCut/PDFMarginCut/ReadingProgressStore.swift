import Foundation

struct ReadingProgressStore {
    private let defaults: UserDefaults
    private let storeKey = "ReadingProgressStore.pageIndices"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func lastPageIndex(forFilename name: String) -> Int? {
        let dict = defaults.dictionary(forKey: storeKey) as? [String: Int] ?? [:]
        return dict[name]
    }

    func setLastPageIndex(_ index: Int, forFilename name: String) {
        var dict = defaults.dictionary(forKey: storeKey) as? [String: Int] ?? [:]
        dict[name] = index
        defaults.set(dict, forKey: storeKey)
    }

    /// 저장된 인덱스를 pageCount 범위로 클램프해 반환한다. pageCount가 0이면 nil.
    func clampedPageIndex(forFilename name: String, pageCount: Int) -> Int? {
        guard pageCount > 0, let saved = lastPageIndex(forFilename: name) else { return nil }
        return min(max(saved, 0), pageCount - 1)
    }
}
