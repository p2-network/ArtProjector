//
//  File.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 15/1/2023.
//

import Foundation

struct DeviceCodeWaiting {
  let verificationUri: String
  let userCode: String
  let expiresAt: Date
  let refreshInterval: TimeInterval
  let deviceCode: String
}
