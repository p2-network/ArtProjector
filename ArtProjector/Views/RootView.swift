//
//  RootView.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 23/12/2022.
//

import Foundation
import SwiftUI

struct RootView: View {
  @EnvironmentObject var artProjectorState: ArtProjectorState

  @ViewBuilder
  var body: some View {
    switch artProjectorState.state {
    case .startup:
      ZStack(alignment: .center) {
        Color(white: 0.12)
          .edgesIgnoringSafeArea(.all)

        VStack(alignment: .center) {
          Spacer()
          Image(systemName: "photo.artframe")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(.horizontal, 100.0)
          Spacer()
          Text("Starting up...")
          Spacer()
        }
      }.frame(width: 1080, height: 1920).rotationEffect(.degrees(270))
    case let .deviceCodeWaiting(response):
      VStack {
        Text("Go to \(response.verificationUri), and enter code")
        Text(response.userCode).font(.largeTitle)
      }
    case .deviceCodeInitFailed:
      VStack {
        Text("Oh oh :(").font(.largeTitle)
        Text("Check the internet connection and auth0 settings")
        Button("Retry") {
          Task {
            await artProjectorState.startDeviceCodeFlow()
          }
        }
      }
    case .deviceCodeClaimed:
      Text("One more moment needed...")
    case .hasRefreshToken:
      Text("You shouldn't see this :shrug:")
    case .registeringSurface:
      Text("Registering surface...")
    case .loadingSurfaceInfo:
      ZStack(alignment: .center) {
        Color(white: 0.12)
          .edgesIgnoringSafeArea(.all)

        VStack(alignment: .center) {
          Spacer()
          Image(systemName: "photo.artframe")
            .resizable()
            .aspectRatio(contentMode: .fit)
          Spacer()
          Text("Starting up...")
          Spacer()
        }
      }
    case let .noPlaylist(state):
      VStack {
        Text(state.surface.name).font(.largeTitle)
        Text("No playlist set")
      }
    case let .loadingPlaylist(state):
      VStack {
        Text(state.surface.name).font(.largeTitle)
        Text("Loading playlist...")
      }.rotationEffect(.degrees(Double(state.surface.rotation)))
    case let .downloadingAssets(state):
      ZStack(alignment: .center) {
//        Color(white: 0.38)
//          .edgesIgnoringSafeArea(.all)
        
        VStack(alignment: .center) {
          Spacer()
          Image(systemName: "photo.artframe")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(.horizontal, 100.0)
          Spacer()
          Text(state.surface.name).font(.largeTitle)
          Text("Playlist: \(state.playlist.name)")
          Spacer()
          Text("Loading assets").font(.footnote)
          Spacer()
        }
      }.frame(width: 1080, height: 1920).rotationEffect(.degrees(Double(state.surface.rotation)))
    case let .playing(state):
      ZStack(alignment: .center) {
//        Color(white: 0.38)
//          .edgesIgnoringSafeArea(.all)
        
        VStack(alignment: .center) {
          Spacer()
          Image(systemName: "photo.artframe")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(.horizontal, 100.0)
          Spacer()
          Text(state.surface.name).font(.largeTitle)
          Text("Playlist: \(state.playlist.name)")
          Spacer()
          Text("All assets ready").font(.footnote)
          Spacer()
        }
      }.frame(width: 1080, height: 1920).rotationEffect(.degrees(Double(state.surface.rotation)))
    }
  }
}

struct StartupView_Previews: PreviewProvider {
  static var previews: some View {
    RootView().environmentObject(ArtProjectorState())
  }
}
