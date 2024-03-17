//
//  AudioPlayerClient.swift
//  RadioDeTCA
//
//  Created by Ilya Sudnik on 16.03.24.
//

import AVFoundation
import ComposableArchitecture
import Foundation

@DependencyClient
struct AudioPlayerClient {
	var play: @Sendable (_ url: URL) async throws -> Bool
}

extension DependencyValues {
	var audioPlayer: AudioPlayerClient {
		get { self[AudioPlayerClient.self] }
		set { self[AudioPlayerClient.self] = newValue }
	}
}

extension AudioPlayerClient: DependencyKey {
	static let liveValue = Self { url in
		await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
			let playerItem = AVPlayerItem(url: url)
			let player = AVPlayer(playerItem: playerItem)

			group.addTask {
				for await _ in NotificationCenter.default
					.notifications(named: .AVPlayerItemDidPlayToEndTime,
								   object: playerItem) {
					return true
				}
				return false
			}

			group.addTask {
				for await _ in NotificationCenter.default
					.notifications(named: .AVPlayerItemFailedToPlayToEndTime,
								   object: playerItem) {
					return false
				}
				return false
			}

			player.play()

			if let result = await group.next() {
				player.pause()
				await player.seek(to: .zero)
				return result
			}

			return false
		}
	}
}
