//
//  withCustomRotation.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 15/1/2023.
//

import Foundation
import SwiftUI

extension View {
  
  func withCustomRotation(rotation: Int32) -> some View {
    let screenSize = UIScreen.main.bounds.size
    
    var width = screenSize.width
    var height = screenSize.height
    
    if rotation == 90 || rotation == 270 {
      width = screenSize.height
      height = screenSize.width
    }
    
    return self.frame(width: width, height: height).rotationEffect(.degrees(Double(rotation)))
  }
  
}

