@testable import DynamicNotchKit
import AppKit
import SwiftUI
import Testing

@MainActor
@Suite(.serialized)
struct DynamicNotchLifecycleTests {
    private typealias Notch = DynamicNotch<EmptyView, EmptyView, EmptyView, EmptyView>

    init() {
        _ = NSApplication.shared
    }

    @Test("Screen observation does not retain an unused notch")
    func releasesUnusedNotch() async throws {
        var notch: Notch? = makeNotch()
        weak var reference = notch
        try await Task.sleep(for: .milliseconds(50))

        notch = nil

        let released = try await waitUntil { reference == nil }
        #expect(released)
    }

    @Test("Screen observation does not retain a dismissed notch")
    func releasesDismissedNotch() async throws {
        var notch: Notch? = makeNotch()
        weak var reference = notch
        await notch?.expand()
        await notch?.hide()

        notch = nil

        let released = try await waitUntil { reference == nil }
        #expect(released)
    }

    @Test("Screen changes do not present an unused notch")
    func keepsUnusedNotchHidden() async throws {
        let notch = makeNotch()
        defer { notch.windowController?.close() }

        try await postScreenChanges()

        #expect(notch.windowController == nil)
    }

    @Test("Screen changes do not recreate a dismissed notch window")
    func keepsDismissedNotchHidden() async throws {
        let notch = makeNotch()
        defer { notch.windowController?.close() }
        await notch.expand()
        await notch.hide()
        #expect(notch.windowController == nil)

        try await postScreenChanges()

        #expect(notch.windowController == nil)
    }

    @Test("Visible notches still update after screen changes")
    func updatesVisibleNotch() async throws {
        var notch: Notch? = makeNotch()
        weak var reference = notch
        await notch?.expand()
        var originalWindow = notch?.windowController?.window
        #expect(originalWindow != nil)

        try await postScreenChanges()

        #expect(notch?.windowController?.window !== originalWindow)
        #expect(notch?.windowController?.window?.isVisible == true)
        await notch?.hide()
        originalWindow = nil
        notch = nil

        let released = try await waitUntil { reference == nil }
        #expect(released)
    }

    private func makeNotch() -> Notch {
        Notch(hoverBehavior: [], style: .auto) { EmptyView() }
    }

    private func postScreenChanges() async throws {
        for _ in 0..<3 {
            NotificationCenter.default.post(
                name: NSApplication.didChangeScreenParametersNotification,
                object: NSApplication.shared
            )
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func waitUntil(_ condition: () -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
}
