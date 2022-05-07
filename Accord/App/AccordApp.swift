//
//  AccordApp.swift
//  Accord
//
//  Created by evelyn on 2020-11-24.
//

import AppKit
import Foundation
import SwiftUI
import UserNotifications

@main
struct AccordApp: App {
    @State var loaded: Bool = false
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var popup: Bool = false
    @State var token = AccordCoreVars.token
    var body: some Scene {
        WindowGroup {
            if self.token == "" {
                LoginView()
                    .frame(width: 700, height: 400)
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LoggedIn"))) { _ in
                        self.token = AccordCoreVars.token
                        print("posted", self.token)
                    }
            } else {
                GeometryReader { reader in
                    ContentView(loaded: $loaded)
                        .onDisappear {
                            loaded = false
                        }
                        .preferredColorScheme(darkMode ? .dark : nil)
                        .sheet(isPresented: $popup, onDismiss: {}) {
                            SearchView()
                                .focusable()
                                .touchBar {
                                    Button(action: {
                                        popup.toggle()
                                    }) {
                                        Image(systemName: "magnifyingglass")
                                    }
                                }
                        }
                        .focusable()
                        .touchBar {
                            Button(action: {
                                popup.toggle()
                            }) {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                }
                .onAppear {
                    // AccordCoreVars.loadVersion()
                    // DispatchQueue(label: "socket").async {
                    //     let rpc = IPC().start()
                    // }
                    DispatchQueue.global().async {
                        NetworkCore.shared = NetworkCore()
                    }
                    DispatchQueue.global(qos: .background).async {
                        Regex.precompute()
                    }
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
                        granted, error in
                    }
                    let windowWidth = UserDefaults.standard.integer(forKey: "windowWidth")
                    let windowHeight = UserDefaults.standard.integer(forKey: "windowHeight")
                    appDelegate.fileNotifications()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                        NSApp.keyWindow?.setContentSize(NSSize.init(width: windowWidth, height: windowHeight))
                    })
                }
            }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            SidebarCommands() // 1
            CommandMenu("Navigate") {
                Button("Show quick jump") {
                    popup.toggle()
                }.keyboardShortcut("k")
                #if DEBUG
                Button("Error", action: {
                    Self.error(Request.FetchErrors.invalidRequest, additionalDescription: "uwu")
                })
                #endif
            }
            CommandMenu("Account") {
                Button("Log out") {
                    logOut()
                }
                #if DEBUG
                Menu("Debug") {
                    Button("Reconnect") {
                        wss.reset()
                    }
                    Button("Force reconnect") {
                        wss.hardReset()
                    }
                }
                #endif
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @objc func onWakeNote(_: NSNotification) {
        print("hi")
        concurrentQueue.async {
            wss?.reset()
        }
    }

    @objc func onSleepNote(_: NSNotification) {
        wss?.close(.protocolCode(.protocolError))
    }

    func fileNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onWakeNote(_:)),
            name: NSWorkspace.didWakeNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onSleepNote(_:)),
            name: NSWorkspace.willSleepNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowClosed(_:)),
            name: NSWindow.willCloseNotification, object: nil
        )
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "_MRPlayerPlaybackQueueContentItemsChangedNotification"), object: nil, queue: nil) { _ in
            print("Song Changed")
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                MediaRemoteWrapper.updatePresence()
            }
        }
    }

    var popover = NSPopover()
    var statusBarItem: NSStatusItem?

    func applicationWillTerminate(_: Notification) {
        wss?.close(.protocolCode(.noStatusReceived))
    }

    func applicationDidFinishLaunching(_: Notification) {
        guard UserDefaults.standard.bool(forKey: "MentionsMenuBarItemEnabled") else { return }

        let contentView = MentionsView(replyingTo: Binding.constant(nil))

        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: contentView)
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "ellipsis.bubble.fill", accessibilityDescription: "Accord")
            button.action = #selector(togglePopover(_:))
        }
        statusBarItem?.button?.action = #selector(AppDelegate.togglePopover(_:))
    }

    @objc func showPopover(_: AnyObject?) {
        if let button = statusBarItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }

    @objc func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    @objc func windowClosed(_: AnyObject?) {
        print(NSApplication.shared.keyWindow?.contentView?.bounds)
        UserDefaults.standard.set(Int(NSApplication.shared.keyWindow?.contentView?.bounds.width ?? 1000), forKey: "windowWidth")
        UserDefaults.standard.set(Int(NSApplication.shared.keyWindow?.contentView?.bounds.height ?? 800), forKey: "windowHeight")
    }
}
