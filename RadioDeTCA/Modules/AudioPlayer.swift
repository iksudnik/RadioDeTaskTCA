//
//  AudioPlayer.swift
//  RadioDeTCA
//
//  Created by Ilya Sudnik on 16.03.24.
//

import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
struct AudioPlayer {

	@ObservableState
	struct State: Equatable {
		let title: String
		let logoUrl: URL?
		let audioUrl: URL

		var isPlaying: Bool = false
	}

	enum Action {
		case audioPlayerClient(Result<Bool, Error>)
		case playButtonTapped
	}

	@Dependency(\.audioPlayer) var audioPlayer
	private enum CancelID { case play }

	var body: some ReducerOf<Self> {
		Reduce { state, action in
			switch action {
			case .audioPlayerClient(.failure):
				state.isPlaying = false
				return .cancel(id: CancelID.play)
			case .audioPlayerClient:
				state.isPlaying = true
				return .cancel(id: CancelID.play)

			case .playButtonTapped:
				if !state.isPlaying {
					state.isPlaying = true

					return .run { [url = state.audioUrl] send in

					  async let playAudio: Void = send(
						.audioPlayerClient(Result { try await self.audioPlayer.play(url: url) })
					  )

					  await playAudio
					}
					.cancellable(id: CancelID.play, cancelInFlight: true)
				} else {
					state.isPlaying = false
					return .cancel(id: CancelID.play)
				}
			}
		}
	}
}


struct AudioPlayerView: View {
	let store: StoreOf<AudioPlayer>

	var body: some View {
		VStack(spacing: 16) {
			AsyncImage(url: store.logoUrl) { image in
				image.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 300)
					.clipShape(RoundedRectangle(cornerRadius: 16))
			} placeholder: {
				ProgressView()
					.frame(width: 300)
			}

			Text(store.title)
				.font(.system(size: 16, weight: .semibold))
				.lineLimit(0)

			Button(action: {
				store.send(.playButtonTapped)
			}, label: {
				Image(systemName: store.isPlaying ? "pause.rectangle" : "play.rectangle")
					.font(.system(size: 60))
					.tint(.primary)
			})
		}
		.navigationTitle("Player")
		.navigationBarTitleDisplayMode(.inline)
	}
}

#Preview {
	AudioPlayerView(store: .init(initialState: .init(title: 
														Episode.mock1.title,
													 logoUrl: URL(string: Episode.mock1.parentLogo300x300), audioUrl: URL(string: Episode.mock1.url)!),
								 reducer: {
		AudioPlayer()
	}))
}
