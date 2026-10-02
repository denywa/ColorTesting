//
//  ContentView.swift
//  ColorGameTesting
//
//  Created by Deny Wahyudi Asaloei  on 02/10/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()

    var body: some View {
        switch viewModel.phase {
        case .settings:
            SettingsView(viewModel: viewModel)
        case .playing:
            GameView(viewModel: viewModel)
        case .result:
            ResultView(viewModel: viewModel)
        case .score:
            ScoreView(viewModel: viewModel)
        }
    }
}

#Preview {
    ContentView()
}
