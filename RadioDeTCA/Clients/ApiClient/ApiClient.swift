//
//  ApiClient.swift
//  RadioDeTask
//
//  Created by Ilya Sudnik on 24.02.24.
//

import ComposableArchitecture
import Foundation

struct ApiClient {
	var episodes: () async throws -> [Episode]
}

extension ApiClient: DependencyKey {
	private static let episodesLink = "https://prod.radio-api.net/podcasts/episodes/by-podcast-ids?podcastIds=verbrechen&count=40&offset=0"

	static let liveValue = Self(episodes: {
		let url = URL(string: episodesLink)!

		let (data, _) = try await URLSession.shared.data(from: url)
		let response = try JSONDecoder().decode(EpisodesResponse.self, from: data)
		return response.episodes
	})
}

extension DependencyValues {
	var apiClient: ApiClient {
		get { self[ApiClient.self] }
		set { self[ApiClient.self] = newValue }
	}
}


// MARK: Mock client

extension ApiClient {
	static var mock: Self {
		return Self(episodes:  {
			return [.mock1, .mock2]
		})
	}
}
