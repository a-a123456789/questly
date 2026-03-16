import SwiftUI

@main
struct ToDoPlannerApp: App {
	@StateObject private var viewModel = HomeViewModel()

	var body: some Scene {
		WindowGroup {
			HomeView(viewModel: viewModel)
				.environment(\.appTheme, .default)
		}
	}
}
