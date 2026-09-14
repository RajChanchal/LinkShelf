//
//  ContentView.swift
//  LinkShelf
//
//  Created by Chanchal Raj on 18/12/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        LinkListView()
    }
}

#Preview {
    ContentView()
        .environmentObject(LinkManager())
}
