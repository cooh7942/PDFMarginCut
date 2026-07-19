import Foundation
import Testing
@testable import PDFMarginCut

struct ReadingProgressStoreTests {

    @Test func roundTripSave() {
        let suite = "test.ReadingProgressStore.roundtrip"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReadingProgressStore(defaults: defaults)
        store.setLastPageIndex(5, forFilename: "book.pdf")
        #expect(store.lastPageIndex(forFilename: "book.pdf") == 5)
    }

    @Test func differentFilesAreIndependent() {
        let suite = "test.ReadingProgressStore.independent"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReadingProgressStore(defaults: defaults)
        store.setLastPageIndex(10, forFilename: "alpha.pdf")
        store.setLastPageIndex(20, forFilename: "beta.pdf")
        #expect(store.lastPageIndex(forFilename: "alpha.pdf") == 10)
        #expect(store.lastPageIndex(forFilename: "beta.pdf") == 20)
    }

    @Test func clampedIndexWithinBounds() {
        let suite = "test.ReadingProgressStore.clamp"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReadingProgressStore(defaults: defaults)
        store.setLastPageIndex(999, forFilename: "small.pdf")
        // pageCount=10 → valid indices 0..<10, so 999 clamps to 9
        #expect(store.clampedPageIndex(forFilename: "small.pdf", pageCount: 10) == 9)
    }

    @Test func noSavedIndexReturnsNil() {
        let suite = "test.ReadingProgressStore.nil"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReadingProgressStore(defaults: defaults)
        #expect(store.lastPageIndex(forFilename: "nosuchfile.pdf") == nil)
    }

    @Test func clampedIndexForZeroPageCountReturnsNil() {
        let suite = "test.ReadingProgressStore.zeropages"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ReadingProgressStore(defaults: defaults)
        store.setLastPageIndex(0, forFilename: "empty.pdf")
        #expect(store.clampedPageIndex(forFilename: "empty.pdf", pageCount: 0) == nil)
    }
}
