//
//  PlayingView.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 15/1/2023.
//

import Foundation
import SwiftUI

struct PlayingView: View {
  @EnvironmentObject var playbackState: PlaybackState
  
  @ViewBuilder
  var body: some View {
    ZStack(alignment: .center) {
      Color(white: 0.98)
        .edgesIgnoringSafeArea(.all)
      
      VStack(alignment: .center) {
        
        if let firstImage = playbackState.firstImage,
          let uiImage = UIImage(data: firstImage) {
          Image(uiImage: uiImage)
            .resizable()
            .border(Color(white: 0.80))
            .aspectRatio(contentMode: .fit)
            .padding(.horizontal, 50.0)
        } else {
          Image(systemName: "photo.artframe")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .border(Color(white: 0.80))
            .padding(.horizontal, 50.0)
        }
        
      }
    }
  }
}
