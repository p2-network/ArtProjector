//
//  ContentView.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 14/11/2022.
//

import SwiftUI

struct ImagePlaybackView: View {
  var currentImage: UIImage
  
  var body: some View {
    ZStack(alignment: .center) {
      Color(white: 0.98)
        .edgesIgnoringSafeArea(.all)
              
      VStack(alignment: .center) {
        Image(uiImage: currentImage)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .border(Color(white: 0.80))
          .focusable()
          
        Spacer()
      }
    }
      .ignoresSafeArea()
      .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
      .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    
  }
}

struct ImagePlaybackView_Previews: PreviewProvider {
  static var previews: some View {
    ImagePlaybackView(currentImage: UIImage(systemName: "photo.artframe")!)
  }
}
