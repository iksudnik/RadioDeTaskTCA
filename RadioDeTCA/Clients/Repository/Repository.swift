//
//  Repository.swift
//  RadioDeTCA
//
//  Created by Ilya Sudnik on 29.02.24.
//

import ComposableArchitecture
import Foundation


struct Repository {
	var episodes: () async throws -> [Episode]
	var updateIsDownloaded: (_ isDownloaded: Bool, _ episodeId: String) async throws -> Void
}

extension Repository: DependencyKey {
	static let liveValue = {
		@Dependency(\.apiClient) var apiClient
		@Dependency(\.databaseClient) var database

		return Self(episodes: {
			let storedEpisodes = try await database.episodes()
			if !storedEpisodes.isEmpty {
				return storedEpisodes
			}

			let remoteEpisodes = try await apiClient.episodes()
			try await database.saveEpisodes(remoteEpisodes)
			return remoteEpisodes
		}, updateIsDownloaded: { isDownloaded, episodeId in
			try await database.updateIsDownloaded(isDownloaded, episodeId)
		})
	}()
}

extension DependencyValues {
	var repository: Repository {
		get { self[Repository.self] }
		set { self[Repository.self] = newValue }
	}
}
