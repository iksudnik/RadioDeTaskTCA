//
//  Download.swift
//  RadioDeTask
//
//  Created by Ilya Sudnik on 24.02.24.
//

import Foundation

final class Download: NSObject {
	let url: URL
	let destinationUrl: URL
	let downloadSession: URLSession

	private var continuation: AsyncStream<Event>.Continuation?

	private lazy var task: URLSessionDownloadTask = {
		let task = downloadSession.downloadTask(with: url)
		task.delegate = self
		return task
	}()

	init(url: URL, destinationUrl: URL, downloadSession: URLSession) {
		self.url = url
		self.destinationUrl = destinationUrl
		self.downloadSession = downloadSession
	}

	var isDownloading: Bool {
		task.state == .running
	}

	var events: AsyncStream<Event> {
		AsyncStream { continuation in
			self.continuation = continuation
			continuation.yield(.initiated)
			task.resume()
			continuation.onTermination = { @Sendable [weak self] _ in
				self?.task.cancel()
			}
		}
	}

	func cancel() {
		continuation?.yield(.cancelled)
		continuation?.finish()
		task.cancel()
	}
}

extension Download {
	enum Event {
		case initiated
		case progress(currentBytes: Int64, totalBytes: Int64)
		case success(url: URL)
		case cancelled
	}
}

extension Download: URLSessionDownloadDelegate {
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
					didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
					totalBytesExpectedToWrite: Int64) {
		continuation?.yield(
			.progress(
				currentBytes: totalBytesWritten,
				totalBytes: totalBytesExpectedToWrite))
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
					didFinishDownloadingTo location: URL) {
		defer { continuation?.finish() }

		do {
			try moveFile(from: location, to: destinationUrl)
			continuation?.yield(.success(url: destinationUrl))
		} catch {
			continuation?.yield(.cancelled)
		}

	}

	private func moveFile(from tmpUrl: URL, to destinationUrl: URL) throws {
		let newDirectoryURL = destinationUrl.deletingLastPathComponent()

		let fileManager = FileManager.default

		if !fileManager.fileExists(atPath: newDirectoryURL.path) {
			try fileManager.createDirectory(at: newDirectoryURL,
											withIntermediateDirectories: true,
											attributes: nil)
		}

		if fileManager.fileExists(atPath: destinationUrl.path) {
			try fileManager.removeItem(at: destinationUrl)
		}

		try fileManager.moveItem(at: tmpUrl, to: destinationUrl)
	}
}

