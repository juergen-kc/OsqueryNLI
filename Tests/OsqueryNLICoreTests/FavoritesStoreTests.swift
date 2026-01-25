import Testing
import Foundation
@testable import OsqueryNLICore

@Suite("FavoritesStore Tests")
struct FavoritesStoreTests {

    // MARK: - Test Helpers

    private func createTestStore() -> (FavoritesStore, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OsqueryNLITests-\(UUID().uuidString)")
        let store = FavoritesStore(directory: tempDir)
        return (store, tempDir)
    }

    private func cleanup(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Read Operations Tests

    @Suite("Read Operations")
    struct ReadOperationsTests {

        private func createTestStore() -> (FavoritesStore, URL) {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("OsqueryNLITests-\(UUID().uuidString)")
            let store = FavoritesStore(directory: tempDir)
            return (store, tempDir)
        }

        private func cleanup(_ directory: URL) {
            try? FileManager.default.removeItem(at: directory)
        }

        @Test("readFavorites returns empty array when file doesn't exist")
        func testReadEmptyStore() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            let favorites = store.readFavorites()
            #expect(favorites.isEmpty)
        }

        @Test("readFavorites returns favorites sorted by date (newest first)")
        func testReadSortsByDate() throws {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            // Add favorites with slight delay to ensure different timestamps
            let first = store.addFavorite(query: "SELECT * FROM first")
            Thread.sleep(forTimeInterval: 0.01)
            let second = store.addFavorite(query: "SELECT * FROM second")

            let favorites = store.readFavorites()
            #expect(favorites.count == 2)
            #expect(favorites[0].id == second?.id)
            #expect(favorites[1].id == first?.id)
        }

        @Test("findFavorite by name matches partial case-insensitive")
        func testFindByNamePartialMatch() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            store.addFavorite(query: "SELECT * FROM processes", name: "Running Processes")

            let found = store.findFavorite(byName: "running")
            #expect(found != nil)
            #expect(found?.name == "Running Processes")
        }

        @Test("findFavorite by name returns nil when not found")
        func testFindByNameNotFound() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            store.addFavorite(query: "SELECT * FROM processes", name: "Processes")

            let found = store.findFavorite(byName: "nonexistent")
            #expect(found == nil)
        }

        @Test("findFavorite by ID returns correct favorite")
        func testFindById() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            let added = store.addFavorite(query: "SELECT * FROM users")

            let found = store.findFavorite(byId: added!.id)
            #expect(found != nil)
            #expect(found?.query == "SELECT * FROM users")
        }

        @Test("findFavorite by ID returns nil for unknown ID")
        func testFindByIdNotFound() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            store.addFavorite(query: "SELECT * FROM users")

            let found = store.findFavorite(byId: UUID())
            #expect(found == nil)
        }

        @Test("contains returns true for existing query")
        func testContainsExisting() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            store.addFavorite(query: "SELECT * FROM test")

            #expect(store.contains(query: "SELECT * FROM test"))
        }

        @Test("contains returns false for non-existing query")
        func testContainsNonExisting() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            store.addFavorite(query: "SELECT * FROM test")

            #expect(!store.contains(query: "SELECT * FROM other"))
        }
    }

    // MARK: - Write Operations Tests

    @Suite("Write Operations")
    struct WriteOperationsTests {

        private func createTestStore() -> (FavoritesStore, URL) {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("OsqueryNLITests-\(UUID().uuidString)")
            let store = FavoritesStore(directory: tempDir)
            return (store, tempDir)
        }

        private func cleanup(_ directory: URL) {
            try? FileManager.default.removeItem(at: directory)
        }

        @Test("addFavorite creates new favorite")
        func testAddFavorite() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            let favorite = store.addFavorite(query: "SELECT * FROM processes", name: "All Processes")

            #expect(favorite != nil)
            #expect(favorite?.query == "SELECT * FROM processes")
            #expect(favorite?.name == "All Processes")
        }

        @Test("addFavorite prevents duplicates")
        func testAddFavoritePreventsDuplicates() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            let first = store.addFavorite(query: "SELECT * FROM processes")
            let second = store.addFavorite(query: "SELECT * FROM processes")

            #expect(first != nil)
            #expect(second == nil)
            #expect(store.readFavorites().count == 1)
        }

        @Test("addFavorite without name uses query as display name")
        func testAddFavoriteWithoutName() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            let favorite = store.addFavorite(query: "SELECT * FROM test")

            #expect(favorite?.name == nil)
            #expect(favorite?.displayName == "SELECT * FROM test")
        }

        @Test("saveFavorite updates existing favorite")
        func testSaveFavoriteUpdates() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            let original = store.addFavorite(query: "SELECT * FROM test", name: "Original")!
            let updated = FavoriteQuery(
                id: original.id,
                query: original.query,
                name: "Updated",
                createdAt: original.createdAt
            )

            store.saveFavorite(updated)

            let found = store.findFavorite(byId: original.id)
            #expect(found?.name == "Updated")
        }

        @Test("saveFavorite adds new favorite if ID not found")
        func testSaveFavoriteAddsNew() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            let newFavorite = FavoriteQuery(query: "SELECT * FROM new", name: "New Query")
            store.saveFavorite(newFavorite)

            let found = store.findFavorite(byId: newFavorite.id)
            #expect(found != nil)
            #expect(found?.name == "New Query")
        }

        @Test("removeFavorite deletes by ID")
        func testRemoveFavorite() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            let favorite = store.addFavorite(query: "SELECT * FROM test")!

            store.removeFavorite(id: favorite.id)

            #expect(store.readFavorites().isEmpty)
        }

        @Test("removeFavorite does nothing for unknown ID")
        func testRemoveFavoriteUnknownId() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            store.addFavorite(query: "SELECT * FROM test")

            store.removeFavorite(id: UUID())

            #expect(store.readFavorites().count == 1)
        }

        @Test("updateFavoriteName changes name")
        func testUpdateFavoriteName() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            let favorite = store.addFavorite(query: "SELECT * FROM test", name: "Old Name")!

            store.updateFavoriteName(id: favorite.id, name: "New Name")

            let updated = store.findFavorite(byId: favorite.id)
            #expect(updated?.name == "New Name")
        }

        @Test("updateFavoriteName with nil removes name")
        func testUpdateFavoriteNameToNil() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            let favorite = store.addFavorite(query: "SELECT * FROM test", name: "Has Name")!

            store.updateFavoriteName(id: favorite.id, name: nil)

            let updated = store.findFavorite(byId: favorite.id)
            #expect(updated?.name == nil)
        }

        @Test("clearFavorites removes all favorites")
        func testClearFavorites() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            store.addFavorite(query: "SELECT 1")
            store.addFavorite(query: "SELECT 2")
            store.addFavorite(query: "SELECT 3")

            store.clearFavorites()

            #expect(store.readFavorites().isEmpty)
        }

        @Test("replaceFavorites overwrites all favorites")
        func testReplaceFavorites() {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            store.addFavorite(query: "SELECT old")

            let newFavorites = [
                FavoriteQuery(query: "SELECT new1", name: "New 1"),
                FavoriteQuery(query: "SELECT new2", name: "New 2")
            ]
            store.replaceFavorites(newFavorites)

            let favorites = store.readFavorites()
            #expect(favorites.count == 2)
            #expect(!store.contains(query: "SELECT old"))
            #expect(store.contains(query: "SELECT new1"))
        }
    }

    // MARK: - Persistence Tests

    @Suite("Persistence")
    struct PersistenceTests {

        private func createTestStore() -> (FavoritesStore, URL) {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("OsqueryNLITests-\(UUID().uuidString)")
            let store = FavoritesStore(directory: tempDir)
            return (store, tempDir)
        }

        private func cleanup(_ directory: URL) {
            try? FileManager.default.removeItem(at: directory)
        }

        @Test("favorites persist across store instances")
        func testPersistence() {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("OsqueryNLITests-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: tempDir) }

            // Create first store and add favorites
            let store1 = FavoritesStore(directory: tempDir)
            let added = store1.addFavorite(query: "SELECT * FROM test", name: "Persisted")

            // Create second store with same directory
            let store2 = FavoritesStore(directory: tempDir)
            let favorites = store2.readFavorites()

            #expect(favorites.count == 1)
            #expect(favorites[0].id == added?.id)
            #expect(favorites[0].name == "Persisted")
        }

        @Test("favorites file is valid JSON")
        func testValidJsonFormat() throws {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            store.addFavorite(query: "SELECT * FROM test", name: "Test Query")

            let fileURL = dir.appendingPathComponent("favorites.json")
            let data = try Data(contentsOf: fileURL)
            let json = try JSONSerialization.jsonObject(with: data)

            #expect(json is [[String: Any]])
        }
    }

    // MARK: - Move Operations Tests

    @Suite("Move Operations")
    struct MoveOperationsTests {

        private func createTestStore() -> (FavoritesStore, URL) {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("OsqueryNLITests-\(UUID().uuidString)")
            let store = FavoritesStore(directory: tempDir)
            return (store, tempDir)
        }

        private func cleanup(_ directory: URL) {
            try? FileManager.default.removeItem(at: directory)
        }

        @Test("moveFavorites writes reordered data to file")
        func testMoveFavoritesWritesToFile() throws {
            let (store, dir) = createTestStore()
            defer { cleanup(dir) }

            // Add favorites
            store.addFavorite(query: "SELECT 1", name: "First")
            store.addFavorite(query: "SELECT 2", name: "Second")
            store.addFavorite(query: "SELECT 3", name: "Third")

            // Perform move operation
            store.moveFavorites(fromOffsets: IndexSet(integer: 0), toOffset: 3)

            // Verify file was written (move doesn't crash)
            let fileURL = dir.appendingPathComponent("favorites.json")
            #expect(FileManager.default.fileExists(atPath: fileURL.path))

            // Verify data is still valid JSON with all 3 items
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([FavoriteQuery].self, from: data)
            #expect(decoded.count == 3)
        }
    }
}
