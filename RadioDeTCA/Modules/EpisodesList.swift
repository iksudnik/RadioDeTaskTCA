//
//  EpisodesList.swift
//  RadioDeTCA
//
//  Created by Ilya Sudnik on 28.02.24.
//

import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
struct EpisodesList {
	@ObservableState
	struct State: Equatable {
		var episodes: IdentifiedArrayOf<EpisodeRow.State> = []
		var showError: Bool = false
		var path = StackState<AudioPlayer.State>()
	}

	enum Action {
		case initialLoad
		case episodesResponse(Result<[Episode], Error>)
		case episodes(IdentifiedActionOf<EpisodeRow>)
		case path(StackAction<AudioPlayer.State, AudioPlayer.Action>)
	}

	@Dependency(\.repository) var repository

	var body: some ReducerOf<Self> {
		Reduce { state, action in
			switch action {
			case .initialLoad:
				return .run { send in
					let result = await Result { try await repository.episodes() }
					await send(.episodesResponse(result))
				}

			case let .episodesResponse(result):
				switch result {
				case let .success(episodes):
					state.episodes = .init(uniqueElements: episodes.map { $0.toEpisodeRowState() })
					state.showError = false
					return .none

				case .failure:
					state.showError = true
					return .none
				}

			case .episodes:
				return .none

			case .path:
				return .none
			}
		}
		.forEach(\.episodes, action: \.episodes) {
			EpisodeRow()
		}
		.forEach(\.path, action: \.path) {
			AudioPlayer()
		}
	}
}


struct EpisodesView: View {
	@Bindable var store: StoreOf<EpisodesList>

	var body: some View {
		NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
			List {
				ForEach(store.scope(state: \.episodes, action: \.episodes)) { episode in

					NavigationLink(state: episode.state.toPlayerState()) {
						EpisodeRowView(store: episode)
					}
					.buttonStyle(.borderless)
				}
			}
			.listStyle(PlainListStyle())
			.navigationTitle("Episodes")
			.task {
				store.send(.initialLoad)
			}
		} destination: { store in
			AudioPlayerView(store: store)
		}
		.overlay {
			if store.showError {
				ContentUnavailableView {
				  Label("Something went wrong.", systemImage: "exclamationmark.circle.fill")
				} description: {
				  Text("Please try again later.")
				} actions: {
					Button("Retry") {
						store.send(.initialLoad)
						}
					.buttonStyle(.borderedProminent)
				}
			} else if store.episodes.isEmpty {
				ContentUnavailableView {
				  Label("Episodes", systemImage: "waveform")
				} description: {
				  Text("The list is empty")
				}
			}
		}
	}
}

private extension EpisodeRow.State {
	func toPlayerState() -> AudioPlayer.State {
		let audioUrl: URL
		if case let .downloaded(fileUrl) = downloadState {
			audioUrl = fileUrl
		} else {
			audioUrl = remoteUrl!
		}

		return .init(title: title, logoUrl: logoUrl, audioUrl: audioUrl)
	}
}


#Preview("Default") {
	EpisodesView(
		store: Store(
			initialState: EpisodesList.State()) {
				EpisodesList()
					.dependency(\.repository.episodes, { [ .mock1, .mock2] })
			}
	)
}


#Preview("Empty") {
	EpisodesView(
		store: Store(
			initialState: EpisodesList.State()) {
				EpisodesList()
					.dependency(\.repository.episodes, { [ ] })
			}
	)
}


#Preview("Error") {
	return EpisodesView(
		store: Store(
			initialState: EpisodesList.State()) {
				EpisodesList()
					.dependency(\.repository.episodes, { throw NSError() })
			}
	)
}
