import Testing
import Foundation
@testable import OsqueryNLICore

@Suite("FavoriteQuery Tests")
struct FavoriteQueryTests {

    // MARK: - Display Name Tests

    @Suite("Display Name")
    struct DisplayNameTests {

        @Test("displayName uses custom name when provided")
        func testDisplayNameWithCustomName() {
            let favorite = FavoriteQuery(query: "SELECT * FROM processes", name: "My Processes")
            #expect(favorite.displayName == "My Processes")
        }

        @Test("displayName uses query when no custom name")
        func testDisplayNameWithoutCustomName() {
            let favorite = FavoriteQuery(query: "SELECT 1")
            #expect(favorite.displayName == "SELECT 1")
        }

        @Test("displayName truncates long queries")
        func testDisplayNameTruncation() {
            let longQuery = String(repeating: "SELECT * FROM very_long_table_name_", count: 3)
            let favorite = FavoriteQuery(query: longQuery)

            #expect(favorite.displayName.count == 50)
            #expect(favorite.displayName.hasSuffix("..."))
        }

        @Test("displayName doesn't truncate 50 char queries")
        func testDisplayNameExactly50() {
            let query = String(repeating: "a", count: 50)
            let favorite = FavoriteQuery(query: query)
            #expect(favorite.displayName == query)
            #expect(!favorite.displayName.hasSuffix("..."))
        }

        @Test("displayName uses query when name is empty string")
        func testDisplayNameEmptyName() {
            let favorite = FavoriteQuery(query: "SELECT 1", name: "")
            #expect(favorite.displayName == "SELECT 1")
        }
    }

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("default initialization creates valid favorite")
        func testDefaultInit() {
            let favorite = FavoriteQuery(query: "SELECT 1")

            #expect(favorite.query == "SELECT 1")
            #expect(favorite.name == nil)
            #expect(favorite.id != UUID())
        }

        @Test("custom initialization preserves values")
        func testCustomInit() {
            let id = UUID()
            let date = Date()
            let favorite = FavoriteQuery(id: id, query: "SELECT 1", name: "Test", createdAt: date)

            #expect(favorite.id == id)
            #expect(favorite.query == "SELECT 1")
            #expect(favorite.name == "Test")
            #expect(favorite.createdAt == date)
        }

        @Test("each favorite has unique id")
        func testUniqueIds() {
            let fav1 = FavoriteQuery(query: "SELECT 1")
            let fav2 = FavoriteQuery(query: "SELECT 1")
            #expect(fav1.id != fav2.id)
        }
    }

    // MARK: - Codable Tests

    @Suite("Codable")
    struct CodableTests {

        @Test("encodes and decodes correctly")
        func testCodable() throws {
            let favorite = FavoriteQuery(query: "SELECT * FROM users", name: "All Users")

            let data = try JSONEncoder().encode(favorite)
            let decoded = try JSONDecoder().decode(FavoriteQuery.self, from: data)

            #expect(decoded.id == favorite.id)
            #expect(decoded.query == favorite.query)
            #expect(decoded.name == favorite.name)
        }

        @Test("encodes and decodes with nil name")
        func testCodableNilName() throws {
            let favorite = FavoriteQuery(query: "SELECT 1")

            let data = try JSONEncoder().encode(favorite)
            let decoded = try JSONDecoder().decode(FavoriteQuery.self, from: data)

            #expect(decoded.name == nil)
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable")
    struct EquatableTests {

        @Test("same id and content are equal")
        func testEquality() {
            let id = UUID()
            let date = Date()
            let fav1 = FavoriteQuery(id: id, query: "SELECT 1", name: "Test", createdAt: date)
            let fav2 = FavoriteQuery(id: id, query: "SELECT 1", name: "Test", createdAt: date)
            #expect(fav1 == fav2)
        }

        @Test("different ids are not equal")
        func testInequality() {
            let fav1 = FavoriteQuery(query: "SELECT 1", name: "Test")
            let fav2 = FavoriteQuery(query: "SELECT 1", name: "Test")
            #expect(fav1 != fav2)
        }
    }
}
