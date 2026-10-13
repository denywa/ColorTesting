//
//  ColorGameTestingApp.swift
//  ColorGameTesting
//
//  Created by Deny Wahyudi Asaloei  on 02/10/26.
//

import SwiftUI

@main
struct ColorGameTestingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 680, minHeight: 480)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 600)
        .windowResizability(.contentMinSize)
        #endif
    }
}
