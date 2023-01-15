//
//  DownloadQueue.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 14/1/2023.
//

import Foundation

struct ImageDownload {
  let assetId: String
  let asset: ArtResponses.AssetResponse.Asset
  let url: URL
}

class DownloadQueue<T> {
  let taskQueue: TaskQueue

  init(concurrency: Int) {
    taskQueue = TaskQueue(concurrency: concurrency)
  }

  func getAllThings(ids: [String], downloadTo: URL, getAccessToken: @escaping () async throws -> String) async throws -> [ImageDownload] {
    try await withThrowingTaskGroup(of: ImageDownload.self, returning: [ImageDownload].self) { group in
      var downloads: [ImageDownload] = []

      for x in ids {
        group.addTask {
          try await self.taskQueue.enqueue {
            print("Starting \(x)")

            let assetBaseName = "asset-\(x)"

            // TODO: Store the assets we already know about in a database of some kind instead.

            let items = try FileManager.default.contentsOfDirectory(at: downloadTo, includingPropertiesForKeys: nil)

            var existingFile: URL? = nil

            for item in items {
              let fileName = item.lastPathComponent
              if let baseName = fileName.split(separator: ".").first {
                if baseName == assetBaseName {
                  existingFile = item
                }
              }
            }

            let accessToken = try await getAccessToken()

            print("We are about to ask about the asset \(x)")

            let info = try await ArtAPI.asset(token: accessToken, assetId: x)

            if let existingFile {
              print("We already have this as \(existingFile)")
              return ImageDownload(assetId: x, asset: info.asset, url: existingFile)
            }
            
            print("We should download \(info.asset.name) from \(info.signedURL)")

            print("All done with \(x)")

            let downloadTask = try await ArtAPI.downloadAsset(url: info.signedURL) { progress in
              print("Progress update: \(progress)")
            }

            let downloadURL = try await downloadTask.value

            let downloadFileHandle = try FileHandle(forReadingFrom: downloadURL)
            let fileExtension = try downloadFileHandle.imageFormat.fileExtension

            let storagePath = URL(filePath: "\(assetBaseName).\(fileExtension)", directoryHint: .notDirectory, relativeTo: downloadTo)

            print("Copied \(x) to \(storagePath)")

            try FileManager.default.copyItem(at: downloadURL, to: storagePath)
            
            return ImageDownload(assetId: x, asset: info.asset, url: storagePath)
          }

          // TODO: something like "if this errors, capture that instead"
        }

        print("All downloads queued")

        for try await download in group {
          downloads.append(download)
        }
      }

      return downloads
    }
  }
}
