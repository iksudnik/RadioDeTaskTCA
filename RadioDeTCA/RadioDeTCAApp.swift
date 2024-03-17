//
//  RadioDeTCAApp.swift
//  RadioDeTCA
//
//  Created by Ilya Sudnik on 28.02.24.
//

import ComposableArchitecture
import SwiftUI

@main
struct RadioDeTCAApp: App {
	static let store = Store(initialState: EpisodesList.State()) {
		EpisodesList()
	}

	var body: some Scene {
		WindowGroup {
			EpisodesView(store: RadioDeTCAApp.store)
		}
	}
}
