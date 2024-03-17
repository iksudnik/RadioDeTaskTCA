//
//  DownloadManager.swift
//  RadioDeTask
//
//  Created by Ilya Sudnik on 24.02.24.
//

import ComposableArchitecture
import Foundation

// MARK: - Interface

struct DownloadManager {
	var download: (_ remoteUrl: URL, _ destinationUrl: URL) -> AsyncStream<Download.Event>?
	var cancel: (URL) -> Void
}

extension DownloadManager: DependencyKey {
	static let liveValue = {
		var downloads: [URL: Download] = [:]

		lazy var downloadSession: URLSession = {
			let configuration = URLSessionConfiguration.default
			return URLSession(configuration: configuration, delegate: nil, delegateQueue: .main)
		}()

		return Self(download: { url, destinationUrl in

			guard downloads[url] == nil else { return downloads[url]?.events }

			let download = Download(url: url, destinationUrl: destinationUrl, downloadSession: downloadSession)

			downloads[url] = download
			return download.events
		}, cancel: { url in
			downloads[url]?.cancel()
			downloads[url] = nil
		})
	}()
}

extension DependencyValues {
	var downloadManager: DownloadManager {
		get { self[DownloadManager.self] }
		set { self[DownloadManager.self] = newValue }
	}
}
