import SwiftUI
import UIKit

struct MoreView: View {
	@Environment(\.appTheme) private var theme
	@ObservedObject var homeViewModel: HomeViewModel

	var body: some View {
		ZStack {
			theme.background.ignoresSafeArea()

			ScrollView(.vertical, showsIndicators: false) {
				VStack(alignment: .leading, spacing: 16) {
					VStack(alignment: .leading, spacing: 4) {
						Text("More")
							.font(theme.titleFont)
							.foregroundStyle(theme.textPrimary)

						Text("Additional features & tools")
							.font(.system(size: 16, weight: .regular))
							.foregroundStyle(theme.textSecondary)
					}
					.padding(.top, 16)

					VStack(spacing: 12) {
						NavigationLink {
							WishesView()
						} label: {
							MoreRow(
								iconBackground: theme.surfaceAlt,
								iconURL: URL(string: "https://www.figma.com/api/mcp/asset/f63c3094-b9cd-4c18-ba0c-51ba1a027f38")!,
								title: "Wishes",
								subtitle: "Spend your hard-earned points"
							)
						}
						.buttonStyle(.plain)

						NavigationLink {
							InboxView()
						} label: {
							MoreRow(
								iconBackground: Color(red: 0xEE / 255, green: 0xF2 / 255, blue: 0xFF / 255),
								iconURL: URL(string: "https://www.figma.com/api/mcp/asset/b84d4bef-5a44-4557-875a-40b73b156c24")!,
								title: "Inbox",
								subtitle: "Capture & organize later"
							)
						}
						.buttonStyle(.plain)

						NavigationLink {
							SettingsAboutView(homeViewModel: homeViewModel)
						} label: {
							MoreRow(
								iconBackground: Color(red: 0xE9 / 255, green: 0xF5 / 255, blue: 0xEF / 255),
								iconURL: URL(string: "https://www.figma.com/api/mcp/asset/ae4520a7-8ab6-4df9-8559-9e3d5c2fed5a")!,
								title: "Settings & About",
								subtitle: "Version info and local data controls"
							)
						}
						.buttonStyle(.plain)
					}
					.padding(.top, 8)

					ProgressCard()
						.padding(.top, 12)

					Spacer(minLength: 24)
				}
				.padding(.horizontal, 16)
				.padding(.bottom, 120)
			}
		}
	}
}

private struct MoreRow: View {
	@Environment(\.appTheme) private var theme
	let iconBackground: Color
	let iconURL: URL
	let title: String
	let subtitle: String

	var body: some View {
		HStack(spacing: 16) {
			ZStack {
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(iconBackground)
				RemoteIcon(url: iconURL)
					.frame(width: 28, height: 28)
			}
			.frame(width: 56, height: 56)

			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.system(size: 18, weight: .bold))
					.foregroundStyle(theme.textPrimary)
				Text(subtitle)
					.font(.system(size: 14, weight: .medium))
					.foregroundStyle(theme.textSecondary)
			}

			Spacer()

			RemoteIcon(url: URL(string: "https://www.figma.com/api/mcp/asset/ae4520a7-8ab6-4df9-8559-9e3d5c2fed5a")!)
				.frame(width: 24, height: 24)
		}
		.padding(.horizontal, 20)
		.frame(height: 96)
		.background(theme.surface)
		.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		.shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
		.accessibilityElement(children: .combine)
		.accessibilityLabel(Text("\(title). \(subtitle)"))
	}
}

private struct SettingsAboutView: View {
	@Environment(\.appTheme) private var theme
	@Environment(\.openURL) private var openURL
	@ObservedObject var homeViewModel: HomeViewModel
	@State private var showsResetConfirmation = false
	@State private var resetStatusMessage: String?

	var body: some View {
		Form {
			Section("About") {
				HStack {
					Text("App")
					Spacer()
					Text("Questly")
						.foregroundStyle(theme.textSecondary)
				}

				HStack {
					Text("Version")
					Spacer()
					Text(versionBuildText)
						.foregroundStyle(theme.textSecondary)
				}
			}

			Section("Local Data") {
				Button("Reset Local Data", role: .destructive) {
					showsResetConfirmation = true
				}
				.accessibilityHint(Text("Clears all locally stored tasks on this device"))

				Text("This keeps the app local-first. There is no cloud sync yet.")
					.font(.footnote)
					.foregroundStyle(theme.textSecondary)

				if let message = resetStatusMessage {
					Text(message)
						.font(.footnote)
						.foregroundStyle(theme.textSecondary)
				}
			}

			Section("Notifications") {
				HStack {
					Text("Status")
					Spacer()
					Text(homeViewModel.notificationPermissionStatusText)
						.foregroundStyle(notificationStatusColor)
				}

				Text(homeViewModel.notificationPermissionDescription)
					.font(.footnote)
					.foregroundStyle(theme.textSecondary)

				if homeViewModel.shouldShowNotificationSettingsButton {
					Button("Open System Settings") {
						guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
						openURL(settingsURL)
					}
					.accessibilityHint(Text("Opens iOS settings so you can allow Questly notifications"))
				}

				Button("Refresh Permission Status") {
					homeViewModel.refreshNotificationAuthorizationStatus()
				}
			}

			Section("More Settings") {
				Text("Notifications, theme controls, and export options are planned for a future update.")
					.font(.footnote)
					.foregroundStyle(theme.textSecondary)
			}
		}
		.scrollContentBackground(.hidden)
		.background(theme.background.ignoresSafeArea())
		.navigationTitle("Settings")
		.navigationBarTitleDisplayMode(.inline)
		.onAppear {
			homeViewModel.refreshNotificationAuthorizationStatus()
		}
		.confirmationDialog(
			"Reset local data?",
			isPresented: $showsResetConfirmation,
			titleVisibility: .visible
		) {
			Button("Reset Data", role: .destructive) {
				homeViewModel.resetLocalData()
				resetStatusMessage = homeViewModel.persistenceMessage ?? "Local task data was reset."
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("This removes all saved tasks from this device.")
		}
	}

	private var versionBuildText: String {
		let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
		let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
		return "\(version) (\(build))"
	}

	private var notificationStatusColor: Color {
		switch homeViewModel.notificationAuthorizationStatus {
		case .authorized:
			theme.accent
		case .notDetermined:
			theme.textSecondary
		case .denied:
			theme.warning
		}
	}
}

private struct ProgressCard: View {
	@Environment(\.appTheme) private var theme

	var body: some View {
		ZStack(alignment: .topLeading) {
			LinearGradient(
				colors: [
					theme.accent,
					Color(red: 0x4A / 255, green: 0x6A / 255, blue: 0xEE / 255),
				],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

			VStack(alignment: .leading, spacing: 12) {
				Text("YOUR PROGRESS")
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(Color.white.opacity(0.8))
					.tracking(0.6)

				HStack {
					ProgressStat(value: "1,874", label: "Points")
					Spacer()
					ProgressStat(value: "3/3", label: "Habits")
					Spacer()
					ProgressStat(value: "31", label: "Active Days")
				}
			}
			.padding(24)
		}
		.frame(height: 128)
		.shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
	}
}

private struct ProgressStat: View {
	let value: String
	let label: String

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(value)
				.font(.system(size: 24, weight: .bold))
				.foregroundStyle(.white)
			Text(label)
				.font(.system(size: 12, weight: .regular))
				.foregroundStyle(Color.white.opacity(0.7))
		}
	}
}
