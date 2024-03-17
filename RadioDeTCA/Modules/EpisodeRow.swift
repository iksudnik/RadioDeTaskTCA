//
//  EpisodeRow.swift
//  RadioDeTCA
//
//  Created by Ilya Sudnik on 16.03.24.
//

import ComposableArchitecture
import Foundation
import SwiftUI

@CasePathable
@dynamicMemberLookup
enum DownloadState: Equatable {
	case notDownloaded
	case inProgress(_ percent: Int)
	case downloaded(_ fileUrl: URL)
}

@Reducer
struct EpisodeRow {

	@ObservableState
	struct State: Equatable, Identifiable {
		let episodeId: String
		let title: String
		let description: String
		let publishDate: Date
		let duration: TimeInterval
		let logoUrl: URL?
		let remoteUrl:URL?

		var downloadState = DownloadState.notDownloaded

		var id: String { self.episodeId }
	}

	enum Action {
		case downloadButtonTapped
		case cancelDownload
		case downloadStateUpdated(DownloadState)
		case fileDownloaded(URL)
	}

	@Dependency(\.downloadManager) var downloadManager
	@Dependency(\.repository) var repository

	private enum CancelID { case download }

	var body: some ReducerOf<Self> {
		Reduce { state, action in
			switch action {

			case .cancelDownload:
					return .merge(
					  .cancel(id: CancelID.download),
					  .send(.downloadStateUpdated(.notDownloaded))
					)
			
			case let .downloadStateUpdated(downloadState):
				state.downloadState = downloadState
				return .none

			case let .fileDownloaded(fileUrl):
				return .run { [id = state.id ] send in
					do {
						try await repository.updateIsDownloaded(true, id)
						await send(.downloadStateUpdated(.downloaded(fileUrl)))
					} catch {
						await send(.downloadStateUpdated(.notDownloaded))
						print("Failed to save file")
					}
				}

			case .downloadButtonTapped:
				if case .downloaded = state.downloadState {
					return .none
				}
				
				return .run { [url = state.remoteUrl,
							   fileUrl = state.fileUrl,
							   downloadState = state.downloadState] send in

					guard let url else { return }

					if case .inProgress = downloadState {
						downloadManager.cancel(url)
						await send(.cancelDownload)
						return
					}

					guard let downloadEvents = downloadManager.download(url, fileUrl) else { return }

					for await event in downloadEvents {
						switch event {
						case .initiated:
							await send(.downloadStateUpdated(.inProgress(0)))
						case let .progress(currentBytes, totalBytes):
							let percent = Int(Double(currentBytes) / Double(totalBytes) * 100)
							await send(.downloadStateUpdated(.inProgress(max(0, min(100, percent)))))
						case let .success(fileUrl):
							await send(.fileDownloaded(fileUrl))
						case .cancelled:
							await send(.cancelDownload)
						}
					}
				}
				.cancellable(id: CancelID.download, cancelInFlight: true)
			}
		}
	}
}


extension Episode {
	func toEpisodeRowState() -> EpisodeRow.State {
		.init(episodeId: self.id,
			  title: self.title,
			  description: self.description,
			  publishDate: self.publishDateFixed,
			  duration: self.duration,
			  logoUrl: URL(string: self.parentLogo300x300),
			  remoteUrl: URL(string: self.url),
			  downloadState: self.isDownloaded == true ? .downloaded(self.fileUrl): .notDownloaded)
	}
}

extension DownloadState {
	var image: Image {
		return switch self {
		case .notDownloaded: Image(systemName: "arrow.down.circle.fill")
		case .inProgress: Image(systemName: "x.circle.fill")
		case .downloaded: Image(systemName: "checkmark.circle.fill")
		}
	}
}

struct EpisodeRowView: View {
	let store: StoreOf<EpisodeRow>

	var body: some View {
		HStack(alignment: .top, spacing: 8) {
			VStack(spacing: 8) {
				AsyncImage(url: store.logoUrl) { image in
					image.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 44)
						.clipShape(RoundedRectangle(cornerRadius: 4))
				} placeholder: {
					ProgressView()
						.frame(width: 44)
				}

				Button(action: {
					store.send(.downloadButtonTapped)
				}) {
					VStack(spacing: 0) {
						store.downloadState.image
							.padding(.vertical, 2)
						if case let .inProgress(percent) = store.downloadState {
							Text(percent, format: .percent)
								.font(.system(size: 10))
								.padding(.bottom, 2)
						}
					}
					.foregroundStyle(.white)
					.frame(width: 44)
					.background {
						RoundedRectangle(cornerRadius: 4)
							.fill(.blue)
					}
				}
				.buttonStyle(BorderlessButtonStyle())
			}

			VStack(alignment: .leading) {
				Text(store.title)
					.lineLimit(1)
					.font(.system(size: 12, weight: .semibold))
				HStack(spacing: 8) {
					Text(store.publishDate, formatter: DateFormatter.publushDateFormatter)
					Text(DateComponentsFormatter.durationFormatter.string(from: store.duration) ?? "-")
				}
				.font(.system(size: 11, weight: .semibold))
				Text(store.description)
					.lineLimit(5)
					.font(.system(size: 11))
			}.offset(y: -2)
		}
	}
}


#Preview(traits: .sizeThatFitsLayout) {
	EpisodeRowView(store: .init(initialState: Episode.mock1.toEpisodeRowState(),
								reducer: {
		EpisodeRow()
	}))
}
