//
//  PlaybackState.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 15/1/2023.
//

import Foundation

@MainActor
class PlaybackState: ObservableObject {
  @Published var sceneIndex = 0
  var playlist: ArtResponses.PlaylistResponse.PlaylistHttpResponse.Playlist
  var assets: [ImageDownload]
  
  var changeSceneTimer: Timer?

  var firstImage: Data? {
    guard let desiredAsset = scene?.assets.first?.assetId else { print("Scene contains no assets")
      return nil
    }

    guard let url = assets.first(where: { $0.assetId == desiredAsset })?.url else {
      print("Asset not found")
      return nil
    }

    do {
      return try Data(contentsOf: url)
    } catch {
      print("Error loading image \(error)")
      return nil
    }
  }
  
  var scene: ArtResponses.PlaylistResponse.PlaylistHttpResponse.Playlist.Scene? {
    if sceneIndex >= playlist.scenes.count {
      return nil
    }

    return playlist.scenes[sceneIndex]
  }

  init(sceneIndex: Int = 0, playlist: ArtResponses.PlaylistResponse.PlaylistHttpResponse.Playlist, assets: [ImageDownload]) {
    self.sceneIndex = sceneIndex
    self.playlist = playlist
    self.assets = assets

    // setup timer
    
    self.changeScene(index: sceneIndex)
  }

  func changeScene(index: Int) {
    if index >= playlist.scenes.count  {
      print("Index \(index) is out of bounds \(playlist.scenes.count), giving up")
      // throw ...
      return
    }

    sceneIndex = index
    
    changeSceneTimer?.invalidate()
    changeSceneTimer = nil

    guard let remainingTime = scene?.duration else { return }
    
    print("Next scene change in \(remainingTime)")

    // TODO: HACK TIME THING
    changeSceneTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(remainingTime / 60), repeats: false) { _ in
      Task {
        await self.nextScene()
      }
    }
  }

  func nextScene() {
    let nextScene = sceneIndex + 1
    // if random...?
    if nextScene >= playlist.scenes.count {
      changeScene(index: 0)
    } else {
      changeScene(index: nextScene)
    }
  }
}
