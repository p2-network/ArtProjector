//
//  ArtAPI.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 28/12/2022.
//

import Alamofire
import Foundation

enum ArtResponses {
  struct ArtError: Decodable, Error {
    let error: String?
    let message: String?
    
    struct NotFound: Error {
      let error: Error?
    }
    
    struct Forbidden: Error {
      let error: Error
    }
  }

  struct Register: Decodable {
    let id: String
    let owner: String
  }

  struct Hello: Decodable {
    let surface: Surface

    struct Surface: Decodable {
      let Rotation: Int32?
      let Name: String?
      let PlaylistId: String?
    }
  }
  
  struct PlaylistResponse {
    let etag: String?
    let playlist: PlaylistHttpResponse.Playlist
    
    struct PlaylistHttpResponse: Decodable {
      let playlist: Playlist
      
      struct Playlist: Decodable {
        let name: String
        let scenes: [Scene]

        enum CodingKeys: String, CodingKey {
          case scenes = "Scenes"
          case name = "Name"
        }

        struct Scene: Decodable {
          let duration: Int32
          let assets: [Asset]
          
          
          enum CodingKeys: String, CodingKey {
            case duration = "Duration"
            case assets = "Assets"
          }
          
          struct Asset: Decodable {
            let assetId: String
            enum CodingKeys: String, CodingKey {
              case assetId = "AssetId"
            }
          }
        }
      }
    }
  }

  struct AssetResponse: Decodable {
    let asset: Asset
    let signedURL: String
    
    struct Asset: Decodable {
      let notes: String?
      let artist: String?
      let source: String?
      let fileSize: Int32?
      let status: String
      let name: String
      
      enum CodingKeys: String, CodingKey {
        case notes = "Notes"
        case artist = "Artist"
        case source = "Source"
        case fileSize = "FileSize"
        case status = "Status"
        case name = "Name"
      }
    }
  }
}

enum ArtResponse<T: Decodable>: Decodable {
  case error(ArtResponses.ArtError)
  case ok(T)
}

extension ArtResponse {
  init(from decoder: Decoder) throws {
    do {
      let value = try T(from: decoder)
      self = .ok(value)
    } catch {
      let error = try ArtResponses.ArtError(from: decoder)
      self = .error(error)
    }
  }
}

enum ArtAPI {
  enum Errors: Error {
    case httpEror(AFError)
  }

  enum Config {
    static let prefix = "https://fc103km01j.execute-api.ap-southeast-2.amazonaws.com/v1"
  }

  static func register(token: String) async throws -> ArtResponse<ArtResponses.Register> {
    let data = ["os": "appletv"]

    let headers = HTTPHeaders(["Authorization": "Bearer \(token)"])

    let request = AF.request(ArtAPI.Config.prefix.appending("/surface/register"), method: .post, parameters: data, encoder: JSONParameterEncoder.default, headers: headers)

    do {
      let response = try await request.serializingDecodable(ArtResponse<ArtResponses.Register>.self).value
      print("response \(response)")
      return response
    } catch {
      print("Well something went wrong \(error)")
      throw error
    }
  }

  static func hello(token: String, surfaceId: String) async throws -> ArtResponses.Hello {
    let headers = HTTPHeaders(["Authorization": "Bearer \(token)"])

    let request = AF.request(ArtAPI.Config.prefix.appending("/surface/\(surfaceId)/hello"), method: .get, parameters: Alamofire.Empty.value, encoder: URLEncodedFormParameterEncoder.default, headers: headers)

    do {
      let task = request.serializingDecodable(ArtResponse<ArtResponses.Hello>.self)

      let response = await task.response
      print(response.data.map { String(decoding: $0, as: UTF8.self) } ?? "No data.")

      let value = try await task.value

      switch value {
      case let .error(err):
        throw err
      case let .ok(ok):
        return ok
      }

    } catch let err as ArtResponses.ArtError {
      // this is one of ours, just pass it on
      print("this is one of our errors: \(err)")
      throw err
    } catch let err as AFError {
      print("this is an Alamofire error: \(err)")
      throw Errors.httpEror(err)
    } catch {
      print("Well something went wrong \(error)")
      throw error
    }
  }

  // TODO: add etag from previous build!
  static func playlist(token: String, playlistId: String) async throws -> ArtResponses.PlaylistResponse {
    let headers = HTTPHeaders(["Authorization": "Bearer \(token)"])

    let request = AF.request(ArtAPI.Config.prefix.appending("/playlist/\(playlistId)"), method: .get, parameters: Alamofire.Empty.value, encoder: URLEncodedFormParameterEncoder.default, headers: headers)

    do {
      let task = request.serializingDecodable(ArtResponse<ArtResponses.PlaylistResponse.PlaylistHttpResponse>.self)

      let response = await task.response
      print(response.data.map { String(decoding: $0, as: UTF8.self) } ?? "No data.")
      
      let value = try await task.value

      switch value {
      case let .error(err):
        throw err
      case let .ok(ok):
        let etag = response.response?.headers["etag"]
        print("Oh and we got an etag \(etag ?? "or not")")
        return ArtResponses.PlaylistResponse(etag: etag, playlist: ok.playlist)
      }

    } catch let err as ArtResponses.ArtError {
      // this is one of ours, just pass it on
      print("this is one of our errors: \(err)")
      throw err
    } catch let err as AFError {
      print("this is an Alamofire error: \(err)")
      throw Errors.httpEror(err)
    } catch {
      print("Well something went wrong \(error)")
      throw error
    }
  }
  
  static func asset(token: String, assetId: String) async throws -> ArtResponses.AssetResponse {
    let headers = HTTPHeaders(["Authorization": "Bearer \(token)"])

    let request = AF.request(ArtAPI.Config.prefix.appending("/asset/\(assetId)"), method: .get, parameters: Alamofire.Empty.value, encoder: URLEncodedFormParameterEncoder.default, headers: headers)
    
    do {
      let task = request.serializingDecodable(ArtResponse<ArtResponses.AssetResponse>.self)

      let response = await task.response
      
      let statusCode = response.response?.statusCode
      
//      print("status code: \(response.response?.statusCode)")
      print(response.data.map { String(decoding: $0, as: UTF8.self) } ?? "No data.")

      let value = try await task.value

      switch value {
      case let .error(err):
        if statusCode == 403 {
          throw ArtResponses.ArtError.Forbidden(error: err)
        }
        throw err
      case let .ok(ok):
        return ok
      }

    } catch let err as ArtResponses.ArtError {
      // this is one of ours, just pass it on
      print("this is one of our errors: \(err)")
      throw err
    } catch let err as AFError {
      print("this is an Alamofire error: \(err)")
      throw Errors.httpEror(err)
    } catch {
      print("Well something went wrong \(error)")
      throw error
    }
  }
  
  static func downloadAsset(url: String, progressUpdate: @escaping (_: Progress) -> Void) async throws -> Task<URL, any Error> {
    let request = AF.download(url, method: .get, parameters: Alamofire.Empty.value, encoder: URLEncodedFormParameterEncoder.default, headers: [])
    
    let task = Task {
      do {
        try Task.checkCancellation()
        
        request.downloadProgress { progress in
          progressUpdate(progress)
        }
                
        let task = request.serializingDownloadedFileURL(automaticallyCancelling: true)
        
        let response = await task.response
        
        try Task.checkCancellation()
        
        guard let statusCode = response.response?.statusCode else {
          throw ArtResponses.ArtError(error: "No response", message: nil)
        }
        
        if statusCode == 403 {
          throw ArtResponses.ArtError.Forbidden(error: ArtResponses.ArtError(error: "S3 Status code is 403", message: nil))
        }
        
        if statusCode != 200 {
          throw ArtResponses.ArtError.NotFound(error: ArtResponses.ArtError(error: "Unexpected Status Code", message: "Status code was \(statusCode)"))
        }
        
        let url = try await task.value
        
        try Task.checkCancellation()
        
        print("We got \(url)")
        
        return url
        
      } catch let err as CancellationError {
        print("Evidently we were cancelled \(url)")
        throw err
      } catch let err as AFError {
        print("This is an Alamofire error: \(err)")
        throw Errors.httpEror(err)
      } catch {
        print("Well something went wrong \(error)")
        throw error
      }
    }
    
    return task
  }
  
}
