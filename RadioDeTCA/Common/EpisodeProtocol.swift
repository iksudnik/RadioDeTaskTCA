//
//  EpisodeProtocol.swift
//  RadioDeTCA
//
//  Created by Ilya Sudnik on 16.03.24.
//

import Foundation

protocol EpisodeProtocol {
	var id: String { get }
}

extension EpisodeProtocol {
	var fileUrl: URL {
		return  URL.documentsDirectory
			.appending(path: "Podcasts")
			.appending(path: id)
			.appendingPathExtension("mp3")
	}
}

extension Episode: EpisodeProtocol {}

extension EpisodeRow.State: EpisodeProtocol {}
