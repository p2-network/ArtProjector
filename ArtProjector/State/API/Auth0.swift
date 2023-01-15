//
//  Auth0.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 28/12/2022.
//

import Foundation
import Alamofire


// {
//   "error": "authorization_pending" | "slow_down" | "expired_token" | "access_denied",
//   "error_description:": "..."
// }
// _OR_
// {
//  "access_token":"eyJz93a...k4laUWw",
//  "refresh_token":"GEbRxBN...edjnXbL",
//  "id_token": "eyJ0XAi...4faeEoQ",
//  "token_type":"Bearer",
//  "expires_in":86400
// }

enum TokenResponse: Decodable {
  case accessToken(Access)
  case refreshToken(Refresh)
  case error(Error)
  case invalidResponse
  
  struct Error: Decodable {
    let error: String
    let error_description: String
  }

  struct Access: Decodable {
    let accessToken: String
    let idToken: String?
    let tokenType: String
    let expiresIn: Int32
        
    enum CodingKeys: String, CodingKey {
      case accessToken = "access_token"
      case idToken = "id_token"
      case tokenType = "token_type"
      case expiresIn = "expires_in"
    }
  }

  struct Refresh: Decodable {
    let accessToken: String
    let refreshToken: String
    let idToken: String?
    let tokenType: String
    let expiresIn: Int32
    
    enum CodingKeys: String, CodingKey {
      case accessToken = "access_token"
      case refreshToken = "refresh_token"
      case idToken = "id_token"
      case tokenType = "token_type"
      case expiresIn = "expires_in"
    }

    var accessOnly: Access {
      Access(accessToken: accessToken, idToken: idToken, tokenType: tokenType, expiresIn: expiresIn)
    }
  }
}

extension TokenResponse {
  init(from decoder: Decoder) throws {
    
    do {
      let value = try Refresh(from: decoder)
      self = .refreshToken(value)
    } catch {
      print("We didn't get a refresh token: \(error)")
      do {
        let value = try Access(from: decoder)
        self = .accessToken(value)
      } catch {
        print("We didn't get an access token: \(error)")
        do {
          let value = try Error(from: decoder)
          self = .error(value)
        } catch {
          print("We got here because \(error)")
          self = .invalidResponse
        }
      }
    }
  }
}

enum Auth0 {
  //  curl --request POST \
  //    --url 'https://twopats.au.auth0.com/oauth/token' \
  //    --header 'content-type: application/x-www-form-urlencoded' \
  //    --data grant_type=refresh_token \
  //    --data "client_id=${ART_CLIENT_ID}" \
  //    --data "refresh_token=${ART_REFRESH_TOKEN}" \
  //    --silent | jq > .auth/bearer-token.json

  //  {
  //    "access_token": "...,
  //    "scope": "surface offline_access",
  //    "expires_in": 86400,
  //    "token_type": "Bearer"
  //  }
  
  enum Errors: Error {
    case unexpectedServerResponse
    case unableToGetToken(TokenResponse.Error)
    case httpEror(AFError)
  }

  static func refreshToken(token: String) async throws -> TokenResponse.Access {
    let authRequest = ["grant_type": "refresh_token", "client_id": AuthConfig.clientID, "refresh_token": token] as! [String: String]

    let request = AF.request(AuthConfig.tokenEndpoint, method: .post, parameters: authRequest, encoder: JSONParameterEncoder.default)
    do {
      
      let task = request.serializingDecodable(TokenResponse.self)
      
//      let response = await task.response
//      print(response.data.map { String(decoding: $0, as: UTF8.self) } ?? "No data.")
      
      let value = try await task.value

      switch value {
      case.refreshToken:
        print("We have been given a refresh token, but this is not expected when we perform a refresh")
        throw Errors.unexpectedServerResponse
      case .invalidResponse:
        print("We have an invalidResponse (um?)")
        throw Errors.unexpectedServerResponse
      case let .error(error):
        print("Error from the server? \(error)")
        throw ArtProjectorState.Errors.unableToGetToken(error)
        
      case let .accessToken(token):
        print("Got token...")
        return token
      }
    } catch let err as Errors {
      // this is one of ours, just pass it on
      print("this is one of our errors: \(err)")
      throw err
    } catch let err as AFError {
      print("this is an Alamofire error: \(err)")
      throw Errors.httpEror(err)
    } catch {
      print("failed to get device code stuff \(error)")
      
      throw error
    }
  }
}
