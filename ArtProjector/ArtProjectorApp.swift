//
//  ArtProjectorApp.swift
//  ArtProjector
//
//  Created by Patrick Quinn-Graham on 14/11/2022.
//

import SwiftUI

@main
struct ArtProjectorApp: App {
  @Environment(\.scenePhase) private var scenePhase
  
  @ObservedObject var artProjectorState: ArtProjectorState = .init()

  var body: some Scene {
    WindowGroup {
      NavigationView {
          RootView().environmentObject(artProjectorState)
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
      }
    }.onChange(of: scenePhase) { phase in
      if phase == .background {
        // clean up resources etc
        print("backgrounding now...")
        artProjectorState.becomeBackgrounded()
      } else if phase == .active {
        print("Welcome back!")
        artProjectorState.becomeActive()
      }
    }
  }
}
