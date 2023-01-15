//
//  AuthConfig.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 15/1/2023.
//

import Foundation

enum AuthConfig {
  static let clientID = "YSggLzW0dOBpfGbYIGm8nl690NN4RIIf"
  static let audience = "https://artprojector.p2.network/"
  static let scope = "surface offline_access email"
  static let deviceCodeEndpoint = "https://twopats.au.auth0.com/oauth/device/code"
  static let tokenEndpoint = "https://twopats.au.auth0.com/oauth/token"

  enum Keys {
    static let refreshToken = "auth-refresh-token"
    static let accessToken = "auth-access-token"
    static let accessTokenExpiresAt = "auth-access-token-expires-at"
  }
}
