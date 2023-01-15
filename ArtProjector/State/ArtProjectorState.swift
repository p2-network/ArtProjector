//
//  ArtProjectorState.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 23/12/2022.
//

import Alamofire
import Combine
import Foundation
import SimpleKeychain

struct DeviceCodeResponse: Decodable {
  let device_code: String
  let user_code: String
  let verification_uri: String
  let expires_in: Int32
  let interval: Int32
  let verification_uri_complete: String
}

struct SurfacePlaylistLoading {
  let surface: Surface
  let playlistId: String
  let playlistEtag: String?
}

struct SurfacePlaylistDownloading {
  let surface: Surface
  let playlistId: String
  let playlistEtag: String?
  let playlist: ArtResponses.PlaylistResponse.PlaylistHttpResponse.Playlist
  let queue: DownloadQueue<ImageDownload>
}

struct SurfacePlaylistPlaying {
  let surface: Surface
  let playlistId: String
  let playlistEtag: String?
  let playlist: ArtResponses.PlaylistResponse.PlaylistHttpResponse.Playlist
  let assets: [ImageDownload]
  let playbackState: PlaybackState
}

@MainActor
class ArtProjectorState: ObservableObject {
  enum State {
    case startup

    case deviceCodeWaiting(DeviceCodeWaiting)
    case deviceCodeInitFailed
    case deviceCodeClaimed
    case hasRefreshToken

    case registeringSurface
    case loadingSurfaceInfo

    case noPlaylist(SurfaceNoPlaylist)

    case loadingPlaylist(SurfacePlaylistLoading)
    case downloadingAssets(SurfacePlaylistDownloading)
    case playing(SurfacePlaylistPlaying)
  }

  enum Errors: Error {
    case unexpectedServerResposne
    case unableToGetToken(TokenResponse.Error)
    case calledWithoutRefreshToken
    case noCacheDirectory
    case invalidStateTransition
  }

  @Published var state: State = .startup

  let simpleKeychain = SimpleKeychain()
  var deviceCodeTimer: Timer?

  func hasRefreshToken() -> Bool {
    do {
      return try simpleKeychain.hasItem(forKey: AuthConfig.Keys.refreshToken)
    } catch {
      print("Something went wrong: \(error)")
      return false
    }
  }

  func storeRefreshToken(token: TokenResponse.Refresh) throws {
    do {
      try simpleKeychain.set(token.refreshToken, forKey: AuthConfig.Keys.refreshToken)

      storeAccessToken(token: token.accessOnly)
    } catch {
      print("Something went wrong: \(error)")
    }
  }

  func storeAccessToken(token: TokenResponse.Access) {
    do {
      try simpleKeychain.set(token.accessToken, forKey: AuthConfig.Keys.accessToken)

      let expiresAt = Date.now.addingTimeInterval(TimeInterval(token.expiresIn))

      UserDefaults.standard.set(expiresAt, forKey: AuthConfig.Keys.accessTokenExpiresAt)
    } catch {
      print("Something went wrong storing the access token: \(error)")
    }
  }

  func startDeviceCodeFlow() async {
    // TODO: Refuse to enter this function if we aren't in .startup
    //    guard case .deviceCodeSetup = state else {
    //      return
    //    }

    let authRequest = ["client_id": AuthConfig.clientID, "scope": AuthConfig.scope, "audience": AuthConfig.audience] as! [String: String]

    let request = AF.request(AuthConfig.deviceCodeEndpoint, method: .post, parameters: authRequest, encoder: JSONParameterEncoder.default)

    do {
      // {
      //   "device_code": "...",
      //   "user_code": "AAAA-BBBB",
      //   "verification_uri": "https://.../activate",
      //   "expires_in": 900,
      //   "interval": 5,
      //   "verification_uri_complete": "https://.../activate?user_code=AAAA-BBBB"
      // }
      let response = try await request.serializingDecodable(DeviceCodeResponse.self).value
      let expiresAt = Date.now.addingTimeInterval(TimeInterval(response.expires_in))
      let refreshInterval = TimeInterval(response.interval)

      let waiting = DeviceCodeWaiting(verificationUri: response.verification_uri, userCode: response.user_code, expiresAt: expiresAt, refreshInterval: refreshInterval, deviceCode: response.device_code)

      print("got device stuff \(response)")

      await MainActor.run {
        self.state = .deviceCodeWaiting(waiting)

        self.waitForDeviceCodeFinish()
      }

    } catch {
      print("failed to get device code stuff \(error)")
      state = .deviceCodeInitFailed
    }
  }

  func deviceCodeFlowGiveUp() {
    state = .startup

    // Restart
    Task { await startDeviceCodeFlow() }
  }

  func useDeviceCode(deviceCode: String) async throws -> TokenResponse.Refresh? {
    let authRequest = ["grant_type": "urn:ietf:params:oauth:grant-type:device_code", "client_id": AuthConfig.clientID, "device_code": deviceCode] as! [String: String]

    let request = AF.request(AuthConfig.tokenEndpoint, method: .post, parameters: authRequest, encoder: JSONParameterEncoder.default)
    do {
      let response = try await request.serializingDecodable(TokenResponse.self).value
      print("resposne \(response)")

      switch response {
      case .accessToken:
        print("We have not been given a refresh token, this means something went wrong")
        throw Errors.unexpectedServerResposne
      case .invalidResponse:
        throw Errors.unexpectedServerResposne
      case let .error(error):
        print("Error from the server? \(error)")

        if error.error == "authorization_pending" {
          return nil
        } else {
          throw Errors.unableToGetToken(error)
        }

      case let .refreshToken(token):
        return token
      }
    } catch {
      print("failed to get device code stuff \(error)")
      throw error
    }
  }

  func cleanupDeviceCodeTimer() {
    deviceCodeTimer?.invalidate()
    deviceCodeTimer = nil
  }

  func waitForDeviceCodeFinish() {
    guard case let .deviceCodeWaiting(waiting) = state else {
      return
    }

    deviceCodeTimer?.invalidate()

    deviceCodeTimer = Timer.scheduledTimer(withTimeInterval: waiting.refreshInterval, repeats: true) { _ in
      print("check if user has logged in")

      Task {
        guard case let .deviceCodeWaiting(deviceCodeWaiting) = await self.state else {
          print("Can't check device code now, state is wrong \(await self.state)")
          await self.cleanupDeviceCodeTimer()
          return
        }

        do {
          if let token = try await self.useDeviceCode(deviceCode: deviceCodeWaiting.deviceCode) {
            print("Got a token \(token)")
            await self.cleanupDeviceCodeTimer()
            await self.gotDeviceToken(token: token)
            return // TODO: Tidy up this to make it clearer when we are exiting this function and cleaning up the timer
          }
        } catch {
          await MainActor.run {
            self.state = .deviceCodeInitFailed
          }
        }

        if Date.now > waiting.expiresAt {
          print("Give up")
          await self.deviceCodeFlowGiveUp()
        } else {
          print("See you in \(waiting.refreshInterval) seconds...")
        }
      }
    }
  }

  func gotDeviceToken(token: TokenResponse.Refresh) {
    state = .deviceCodeClaimed
    do {
      try storeRefreshToken(token: token)
      transitionToHasRefreshToken()
    } catch {
      print("Storing the tokens in the keychain failed: \(error)")
      state = .deviceCodeInitFailed
    }
  }

  func becomeActive() {
    // TODO: add a state for when deviceCodeWaiting occurred when we were background, then catch that state here.

    guard case .startup = state else {
      print("Resume active from non startup state")
      return
    }

    if !hasRefreshToken() {
      print("No one has logged in yet, begin that flow...")
      Task {
        await startDeviceCodeFlow()
      }
    } else {
      transitionToHasRefreshToken()
    }
  }

  func becomeBackgrounded() {
    // TODO: self.deviceCodeTimer?.invalidate()
    // TODO: Other startup states: other than register can be cancelled
  }

  // MARK: - Transitions

  func transitionToHasRefreshToken() {
    // TODO: sanity check - we should only come here from .startup & .deviceCodeClaimed

    state = .hasRefreshToken

    thonk()
  }

  func authAccessTokenUnlessExpired() -> String? {
    guard let expiresAt = UserDefaults.standard.object(forKey: AuthConfig.Keys.accessTokenExpiresAt) as? Date else {
      print("\(AuthConfig.Keys.accessTokenExpiresAt) isn't set, so expired?")
      return nil
    }

    if expiresAt < Date.now {
      print("\(AuthConfig.Keys.accessTokenExpiresAt) was \(expiresAt), so expired")
      return nil
    }

    print("We think the current token will expire at \(expiresAt)")

    do {
      return try simpleKeychain.string(forKey: AuthConfig.Keys.accessToken)
    } catch {
      print("could not read \(AuthConfig.Keys.accessToken) \(error)")
      return nil
    }
  }

  func getRefreshToken() throws -> String {
    if !(try simpleKeychain.hasItem(forKey: AuthConfig.Keys.refreshToken)) {
      print("You cannot thonk without a refresh token")
      throw Errors.calledWithoutRefreshToken
    }

    return try simpleKeychain.string(forKey: AuthConfig.Keys.refreshToken)
  }

  func getAccessToken() async throws -> String {
    if let previousAccessToken = authAccessTokenUnlessExpired() {
      print("We already have an access token, please use that")
      return previousAccessToken
    }

    print("We need to get a new access token, so, um, lets figure out how to do that")

    let refreshToken = try getRefreshToken()

    let newAccesToken = try await Auth0.refreshToken(token: refreshToken)

    print("newAccessToken: \(newAccesToken)")

    storeAccessToken(token: newAccesToken)

    return newAccesToken.accessToken
  }

  func getSurfaceID(token: String) async throws -> String {
    if let surfaceId = UserDefaults.standard.string(forKey: "surface-id") {
      print("We have an existing surfaceId \(surfaceId)")
      return surfaceId
    }

    state = .registeringSurface

    do {
      let surface = try await ArtAPI.register(token: token)

      switch surface {
      case let .error(error):
        print("Server said something: \(error.error), and possible \(error.message ?? "or actually no")")
        throw error
      case let .ok(registration):
        print("Server said ok! \(registration.id)")
        UserDefaults.standard.set(registration.id, forKey: "surface-id")
        return registration.id
      }

    } catch {
      print("Could not register surface \(error)")
    }

    throw Errors.unexpectedServerResposne // TODO: Come on, now you're just being lazy
  }

  func transitionToPlaying(assets: [ImageDownload]) throws {
    guard case let .downloadingAssets(previous) = state else {
      throw Errors.invalidStateTransition
    }

    let playbackState = PlaybackState(sceneIndex: 0, playlist: previous.playlist, assets: assets)

    state = .playing(SurfacePlaylistPlaying(surface: previous.surface, playlistId: previous.playlistId, playlistEtag: previous.playlistEtag, playlist: previous.playlist, assets: assets, playbackState: playbackState))
  }

  func hello() async throws -> Surface {
    let accessToken = try await getAccessToken()
    let surfaceId = try await getSurfaceID(token: accessToken)

    print("and a surface ID! \(surfaceId)")

    state = .loadingSurfaceInfo
    let hello = try await ArtAPI.hello(token: accessToken, surfaceId: surfaceId)

    print("We are \(hello.surface.Name ?? "an unamed screen"), that's pretty much all we have to go on right now")

    // do we have a rotation?
    if let rotation = hello.surface.Rotation {
      print("Although we should be rotated \(rotation)")
    }

    let surface = Surface(name: hello.surface.Name ?? "(unnamed)", rotation: hello.surface.Rotation ?? 0, playlistId: hello.surface.PlaylistId)

    return surface
  }

  func transitionToNoPlaylist(surface: Surface) {
    // TODO: sanity check
    state = .noPlaylist(SurfaceNoPlaylist(surface: surface))
  }

  func transitionToLoadingPlaylist(surface: Surface, playlistId: String, playlistEtag: String?) {
    // TODO: sanity check
    state = .loadingPlaylist(SurfacePlaylistLoading(surface: surface, playlistId: playlistId, playlistEtag: playlistEtag))
  }

  func transitionToDownloadingPlaylistAssets(playlist: ArtResponses.PlaylistResponse.PlaylistHttpResponse.Playlist, queue: DownloadQueue<ImageDownload>) throws {
    guard case let .loadingPlaylist(state) = state else {
      throw Errors.invalidStateTransition
    }

    self.state = .downloadingAssets(SurfacePlaylistDownloading(surface: state.surface, playlistId: state.playlistId, playlistEtag: state.playlistEtag, playlist: playlist, queue: queue))
  }

  func downloadPlaylist(playlistId: String) async throws -> ArtResponses.PlaylistResponse {
    let accessToken = try await getAccessToken()
    let playlist = try await ArtAPI.playlist(token: accessToken, playlistId: playlistId)

    print("which gave us \(playlist)")

    return playlist
  }

  func thonk() {
    Task {
      do {
        let surface = try await self.hello()

        if let playlistId = surface.playlistId {
          print("and we should show \(playlistId)")

          self.transitionToLoadingPlaylist(surface: surface, playlistId: playlistId, playlistEtag: nil) // TODO: Know etag from caching

          let playlist = try await downloadPlaylist(playlistId: playlistId)
          print("which gave us \(playlist)")

          let queue = DownloadQueue<ImageDownload>(concurrency: 1)

          try! self.transitionToDownloadingPlaylistAssets(playlist: playlist.playlist, queue: queue)

          let needs = assetsNeeded(scenes: playlist.playlist.scenes)
          let downloadedAssets = try await downloadAssets(assets: needs, queue: queue)

          try! self.transitionToPlaying(assets: downloadedAssets)

        } else {
          self.transitionToNoPlaylist(surface: surface)
        }

        print("Ok really that's all we know")
      } catch {
        print("An error occurred \(error)")
      }
    }
  }

  func whereToStore() throws -> URL {
    guard let cacheDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last else {
      throw Errors.noCacheDirectory
    }

    guard let bundleIdentifer = Bundle.main.bundleIdentifier else {
      throw Errors.noCacheDirectory
    }

    let cacheBundle = cacheDirectory.appending("/\(bundleIdentifer)/assets")

    try FileManager.default.createDirectory(atPath: cacheBundle, withIntermediateDirectories: true)

    return URL(filePath: cacheBundle, directoryHint: .isDirectory)
  }

  func assetsNeeded(scenes: [ArtResponses.PlaylistResponse.PlaylistHttpResponse.Playlist.Scene]) -> [String] {
    var assetIds = Set<String>()
    for scene in scenes {
      for asset in scene.assets {
        assetIds.insert(asset.assetId)
      }
    }

    return Array(assetIds)
  }

  func downloadAssetsM() async throws -> [ImageDownload] {
    guard case let .downloadingAssets(downloadState) = state else {
      throw Errors.invalidStateTransition
    }

    let needs = assetsNeeded(scenes: downloadState.playlist.scenes)
    let assets = try await downloadAssets(assets: needs, queue: downloadState.queue)

    return assets
  }

  func downloadAssets(assets: [String], queue: DownloadQueue<ImageDownload>) async throws -> [ImageDownload] {
    let downloadTo = try whereToStore()

    let allThings = try await queue.getAllThings(ids: assets, downloadTo: downloadTo) { try await self.getAccessToken() }

    print("We got \(allThings)")

    return allThings
  }
}
