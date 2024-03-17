//
//  DatabaseClient.swift
//  RadioDeTask
//
//  Created by Ilya Sudnik on 24.02.24.
//

import Foundation
import ComposableArchitecture
import CoreData

struct DatabaseClient {
	var episodes: @MainActor () async throws -> [Episode]
	var saveEpisodes: @MainActor ([Episode]) async throws -> Void
	var updateIsDownloaded: @MainActor (_ isDownloaded: Bool, _ episodeId: String) async throws -> Void
}

enum DatabaseClientError: Error {
	case objectNotExists
}


// MARK: - Live client

extension DatabaseClient: DependencyKey {

	static var liveValue: Self {

		var viewContext: NSManagedObjectContext {
			return persistentContainer.viewContext
		}

		lazy var persistentContainer: NSPersistentContainer = {
			let container = NSPersistentContainer(name: "RadioDeTCA")
			container.loadPersistentStores { _, error in
				if let error = error as NSError? {
					fatalError("Failed to load persistent stores: \(error), \(error.userInfo)")
				}
			}
			container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
			return container
		}()

		return Self(episodes: {
			
			let request = EpisodeEntity.fetchRequest()
			let sortDescriptor = NSSortDescriptor(keyPath: \EpisodeEntity.publishDate, ascending: false)
			request.sortDescriptors = [sortDescriptor]
			let entities = try viewContext.fetch(request)

			return entities.map { $0.toEpisode() }

		}, saveEpisodes: { episodes in
			
			try await viewContext.perform {
				for episode in episodes {
					let entity = EpisodeEntity(context: viewContext)
					entity.update(from: episode)
				}
				try viewContext.save()
			}
		}, updateIsDownloaded: { isDownloaded, episodeId in

			let request = EpisodeEntity.fetchRequest()
			request.predicate = NSPredicate(format: "id == %@", episodeId)

			let entities = try viewContext.fetch(request)

			guard let entity = entities.first else {
				throw DatabaseClientError.objectNotExists
			}

			try await viewContext.perform {
				entity.isDownloaded = isDownloaded
				try viewContext.save()
			}
		})
	}
}

extension DependencyValues {
  var databaseClient: DatabaseClient {
	get { self[DatabaseClient.self] }
	set { self[DatabaseClient.self] = newValue }
  }
}

// MARK: Mock client

extension DatabaseClient {
  static var mock: Self {
	  return Self(episodes: {
		  return [.mock1, .mock2]
	  }, saveEpisodes: { _ in

	  },updateIsDownloaded: { _, _ in })
  }
}
