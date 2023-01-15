//
//  ImageType.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 14/1/2023.
//  Copied from https://stackoverflow.com/questions/29644168/get-image-file-type-programmatically-in-swift

import ImageIO
import UIKit

struct ImageHeaderData {
  static var PNG: UInt8 = 0x89
  static var JPEG: UInt8 = 0xFF
  static var GIF: UInt8 = 0x47
  static var TIFF_01: UInt8 = 0x49
  static var TIFF_02: UInt8 = 0x4D
}

enum ImageFormat {
  case Unknown, PNG, JPEG, GIF, TIFF
  
  var fileExtension: String {
    switch self {
    case .Unknown:
      return "data"
    case .TIFF:
      return "tiff"
    case .GIF:
      return "gif"
    case .JPEG:
      return "jpeg"
    case .PNG:
      return "png"
    }
  }
}

extension FileHandle {
  var imageFormat: ImageFormat {
    get throws {
      let expected = MemoryLayout<UInt8>.size
      
      var ch: UInt8 = 0
      
      guard let data = try self.read(upToCount: expected) else {
        return .Unknown
      }
      
      data.copyBytes(to: &ch, count: expected)
      
      if ch == ImageHeaderData.PNG {
        return ImageFormat.PNG
      }
      if ch == ImageHeaderData.JPEG {
        return ImageFormat.JPEG
      }
      if ch == ImageHeaderData.GIF {
        return ImageFormat.GIF
      }
      if ch == ImageHeaderData.TIFF_01 || ch == ImageHeaderData.TIFF_02 {
        return ImageFormat.TIFF
      }
      
      return .Unknown
    }
  }
}
