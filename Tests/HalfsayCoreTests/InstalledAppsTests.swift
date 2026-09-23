import Foundation
import Testing
@testable import HalfsayCore

@Suite struct InstalledAppsTests {
    @Test func listsAppBundlesAcrossFoldersOnce() throws {
        let fm = FileManager.default
        let a = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let b = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: a); try? fm.removeItem(at: b) }
        for dir in ["Foo.app", "Bar.app"] { try fm.createDirectory(at: a.appendingPathComponent(dir), withIntermediateDirectories: true) }
        try fm.createDirectory(at: b.appendingPathComponent("Foo.app"), withIntermediateDirectories: true)
        try Data().write(to: a.appendingPathComponent("notes.txt"))
        #expect(InstalledApps.names(in: [a.path, b.path, "/nope/missing"]) == ["Bar", "Foo"])
        #expect(InstalledApps.urls(in: [a.path, b.path])["Foo"]?.path == a.appendingPathComponent("Foo.app").path)
        #expect(InstalledApps.aliases(for: InstalledApps.urls(in: [a.path]))["Foo"] == ["Foo"])
    }

    /// From a --text run on a Portuguese Mac: asked the usual way the names came back in English, so "abre as notas e
    /// digita bom" found no "notas", the open took the whole sentence and "digita bom" went with it.
    @Test(.enabled(if: ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 15, minorVersion: 4, patchVersion: 0))))
    func aliasesAreTheNamesInYourLanguages() {
        let notes = ["Notes": URL(fileURLWithPath: "/System/Applications/Notes.app")]
        #expect(InstalledApps.aliases(for: notes, languages: ["pt-BR"])["Notes"] == ["Notes", "Notas"])
        #expect(InstalledApps.aliases(for: notes, languages: ["en-US", "pt-BR", "es"])["Notes"] == ["Notes", "Notas"])
    }

    @Test func browsersAreTheAppsThatOpenWebLinks() {
        let apps = ["Safari": URL(fileURLWithPath: "/Applications/Safari.app"), "Notes": URL(fileURLWithPath: "/System/Applications/Notes.app")]
        #expect(InstalledApps.names(of: [URL(fileURLWithPath: "/Applications/Safari.app/")], among: apps) == ["Safari"])
    }
}
