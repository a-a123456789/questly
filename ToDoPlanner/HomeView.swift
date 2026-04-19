import SwiftUI

struct HomeView: View {
	@Environment(\.appTheme) private var theme
	@ObservedObject var viewModel: HomeViewModel

	var body: some View {
		ZStack(alignment: .bottom) {
			theme.background.ignoresSafeArea()

			VStack(spacing: 0) {
				header
					.padding(.horizontal, 16)
					.padding(.top, 16)

				dateStrip
					.padding(.horizontal, 16)
					.padding(.top, 16)

					ScrollView(.vertical, showsIndicators: false) {
						VStack(spacing: 24) {
							ForEach(viewModel.sections) { section in
								dayPartSection(section)
							}
						}
					.padding(.horizontal, 16)
					.padding(.top, 24)
					.padding(.bottom, 120)
				}
			}

			fab
				.padding(.trailing, 24)
				.padding(.bottom, 104)
				.frame(maxWidth: .infinity, alignment: .trailing)
		}
			.onAppear {
				viewModel.loadIfNeeded()
			}
			.sheet(item: $viewModel.newTaskViewModel) { newTaskViewModel in
				NewTaskSheet(viewModel: newTaskViewModel)
					.presentationDetents([.medium])
					.presentationDragIndicator(.hidden)
			}
	}

	private var header: some View {
		HStack(alignment: .top) {
			VStack(alignment: .leading, spacing: 4) {
				Text(viewModel.weekdayText)
					.font(theme.titleFont)
					.foregroundStyle(theme.textPrimary)

				Text(viewModel.fullDateText)
					.font(.system(size: 16, weight: .regular))
					.foregroundStyle(theme.textSecondary)
			}

			Spacer(minLength: 12)

			HStack(spacing: 8) {
				Text("⚡")
					.font(.system(size: 14))
					.baselineOffset(1)
					Text(viewModel.pointsText)
						.font(.system(size: 16, weight: .semibold))
			}
			.foregroundStyle(theme.warning)
			.padding(.horizontal, 12)
			.frame(height: 36)
			.background(theme.surfaceAlt)
			.clipShape(Capsule())
		}
		.frame(height: 60)
	}

	private var dateStrip: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				ForEach(viewModel.dayItems) { day in
					VStack(spacing: 4) {
						Text(day.weekdayText)
							.font(.system(size: 12, weight: .regular))
							.foregroundStyle(day.isSelected ? .white : theme.textSecondary)

						Text(day.dayText)
							.font(.system(size: 18, weight: .semibold))
							.foregroundStyle(day.isSelected ? .white : theme.textPrimary)
					}
					.frame(width: 50, height: 64)
					.background(day.isSelected ? theme.accent : Color.clear)
					.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
					.contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
					.onTapGesture {
						viewModel.selectDate(day.date)
					}
				}
			}
			.padding(.vertical, 4)
		}
	}

	private func dayPartSection(_ section: HomeSectionModel) -> some View {
		VStack(spacing: 12) {
			HStack {
				HStack(spacing: 8) {
					Image(systemName: partSymbolName(section.part))
						.font(.system(size: 18, weight: .semibold))
						.foregroundStyle(theme.textSecondary)
					Text(section.title)
						.font(theme.subtitleFont)
						.foregroundStyle(theme.textPrimary)
				}

				Spacer()

				Text(section.timeRangeText)
					.font(.system(size: 14, weight: .regular))
					.foregroundStyle(theme.textSecondary)
			}

			VStack(spacing: 10) {
				if !section.entries.isEmpty {
					ForEach(section.entries) { entry in
						switch entry {
						case .task(let item):
							TaskRow(item: item, currentPart: section.part) {
								viewModel.toggleDone(item.id)
							} onMove: { dayPart in
								viewModel.moveTask(item.id, to: dayPart)
							}
						case .event(let event):
							EventRow(event: event)
						}
					}
				}

				Button {
					viewModel.presentNewTask(for: section.part)
				} label: {
					HStack(spacing: 8) {
						Image(systemName: "plus")
							.font(.system(size: 18, weight: .semibold))
						Text("Add task")
							.font(.system(size: 16, weight: .medium))
							.foregroundStyle(theme.textSecondary)
					}
					.frame(maxWidth: .infinity)
					.frame(height: 76)
					.background(theme.surface)
					.overlay(
						RoundedRectangle(cornerRadius: theme.cornerRadiusMedium, style: .continuous)
							.stroke(theme.divider, style: StrokeStyle(lineWidth: 1.8, dash: [5, 4]))
					)
					.clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusMedium, style: .continuous))
				}
				.buttonStyle(.plain)
			}
		}
	}

	private var fab: some View {
		Button {
			viewModel.presentNewTask(for: .morning)
		} label: {
			ZStack {
				Circle().fill(theme.accent)
				Image(systemName: "plus")
					.font(.system(size: 20, weight: .bold))
					.foregroundStyle(.white)
			}
			.frame(width: 56, height: 56)
			.shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
		}
		.buttonStyle(.plain)
		.accessibilityLabel(Text("Add task"))
		.accessibilityHint(Text("Opens the New Task sheet"))
	}
}

private struct TaskRow: View {
	@Environment(\.appTheme) private var theme
	let item: HomeTaskRowModel
	let currentPart: DayPart
	let onToggle: () -> Void
	let onMove: (DayPart) -> Void

	var body: some View {
		HStack(spacing: 10) {
			Button(action: onToggle) {
				HStack(spacing: 10) {
					Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
						.foregroundStyle(item.isDone ? theme.accent : theme.textSecondary)
					Text(item.title)
						.font(theme.bodyFont)
						.foregroundStyle(theme.textPrimary)
					Spacer()
				}
			}
			.buttonStyle(.plain)

			Menu {
				ForEach(DayPart.plannerParts.filter { $0 != currentPart }) { part in
					Button {
						onMove(part)
					} label: {
						Label("Move to \(part.title)", systemImage: partSymbolName(part))
					}
				}
			} label: {
				Image(systemName: "ellipsis.circle")
					.font(.system(size: 18, weight: .semibold))
					.foregroundStyle(theme.textSecondary)
					.frame(width: 28, height: 28)
			}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.background(theme.surface)
		.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
	}
}

private struct EventRow: View {
	@Environment(\.appTheme) private var theme
	let event: HomeEventRowModel

	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: "calendar")
				.foregroundStyle(theme.textSecondary)
				VStack(alignment: .leading, spacing: 2) {
					Text(event.title)
						.font(theme.bodyFont)
						.foregroundStyle(theme.textPrimary)
						.lineLimit(1)
					Text(event.timeText)
						.font(.system(size: 12, weight: .regular))
						.foregroundStyle(theme.textSecondary)
				}
			Spacer()
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.background(theme.surface)
		.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
	}

}

private struct NewTaskSheet: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.appTheme) private var theme

	@ObservedObject var viewModel: NewTaskViewModel

	var body: some View {
		VStack(spacing: 0) {
			ScrollView(.vertical, showsIndicators: false) {
				VStack(alignment: .leading, spacing: 24) {
					Capsule()
						.fill(Color(red: 0xD1 / 255, green: 0xD5 / 255, blue: 0xDC / 255))
						.frame(width: 48, height: 5)
						.frame(maxWidth: .infinity)
						.padding(.top, 12)

					Text("New Task")
						.font(.system(size: 28, weight: .bold))
						.foregroundStyle(theme.textPrimary)

					VStack(alignment: .leading, spacing: 18) {
						LabeledInput(label: "TITLE") {
							TextField("What do you need to do?", text: $viewModel.title)
						}

						LabeledInput(label: "DESCRIPTION (OPTIONAL)") {
							TextField("Add details...", text: $viewModel.description, axis: .vertical)
								.lineLimit(3, reservesSpace: true)
						}

							SheetSection(label: "WHEN") {
								LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
									ForEach(viewModel.whenOptions) { option in
										PillButton(
										title: option.title,
										iconURL: whenIconURL(for: option),
										isSelected: viewModel.selectedWhen == option,
										selectedBackground: theme.accent,
										unselectedBackground: pillBackgroundColor
									) {
											viewModel.selectedWhen = option
										}
									}
								}
								.frame(maxWidth: 320)
								.frame(maxWidth: .infinity, alignment: .center)
							}

						SheetSection(label: "PRIORITY") {
							HStack(spacing: 12) {
								ForEach(viewModel.priorityOptions) { option in
									PillButton(
										title: option.title,
										isSelected: viewModel.selectedPriority == option,
										selectedBackground: theme.warning,
										unselectedBackground: pillBackgroundColor
									) {
										viewModel.selectedPriority = option
									}
								}
							}
						}

						SheetSection(label: "POINTS REWARD") {
							HStack(spacing: 12) {
								ForEach(viewModel.pointsOptions) { option in
									PointsPillButton(
										points: option.rawValue,
										isSelected: viewModel.selectedPoints == option,
										selectedBackground: theme.warning,
										unselectedBackground: pillBackgroundColor
									) {
										viewModel.selectedPoints = option
									}
								}
							}
						}
					}
				}
				.padding(.horizontal, 24)
				.padding(.bottom, 24)
			}

			PrimaryButton(title: "Add Task", isEnabled: viewModel.isSubmissionEnabled) {
				guard viewModel.addTask() else { return }
				dismiss()
			}
			.padding(.horizontal, 24)
			.padding(.top, 16)
			.padding(.bottom, 20)
			.background(theme.surface)
		}
		.background(theme.surface)
		.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
	}

	private var pillColumns: [GridItem] {
		[
			GridItem(.flexible(), spacing: 12),
			GridItem(.flexible(), spacing: 12),
		]
	}

	private var pillBackgroundColor: Color {
		Color(red: 0xF0 / 255, green: 0xF2 / 255, blue: 0xF8 / 255)
	}
}

private struct SheetSection<Content: View>: View {
	@Environment(\.appTheme) private var theme
	let label: String
	@ViewBuilder let content: Content

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(label)
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(theme.textSecondary)
				.tracking(0.3)

			content
		}
	}
}

private struct LabeledInput<Content: View>: View {
	@Environment(\.appTheme) private var theme
	let label: String
	@ViewBuilder let content: Content

	var body: some View {
		SheetSection(label: label) {
			content
				.font(.system(size: 16, weight: .regular))
				.foregroundStyle(theme.textPrimary)
				.padding(.horizontal, 16)
				.padding(.vertical, 14)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Color(red: 0xF8 / 255, green: 0xF9 / 255, blue: 0xFB / 255))
				.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		}
	}
}

private struct PillButton: View {
	@Environment(\.appTheme) private var theme
	let title: String
	var iconURL: URL? = nil
	let isSelected: Bool
	let selectedBackground: Color
	let unselectedBackground: Color
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(spacing: 8) {
				if let iconURL {
					RemoteIcon(url: iconURL)
						.frame(width: 16, height: 16)
				}

				Text(title)
					.font(.system(size: 16, weight: .medium))
					.lineLimit(1)
					.minimumScaleFactor(0.9)
			}
			.foregroundStyle(isSelected ? .white : theme.textSecondary)
			.frame(maxWidth: .infinity)
			.frame(height: 44)
			.background(isSelected ? selectedBackground : unselectedBackground)
			.clipShape(Capsule())
		}
		.buttonStyle(.plain)
	}
}

private struct PointsPillButton: View {
	@Environment(\.appTheme) private var theme
	let points: Int
	let isSelected: Bool
	let selectedBackground: Color
	let unselectedBackground: Color
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(spacing: 8) {
				Image(systemName: "bolt.fill")
					.font(.system(size: 14, weight: .semibold))
				Text("\(points)")
					.font(.system(size: 16, weight: .medium))
					.lineLimit(1)
					.minimumScaleFactor(0.9)
			}
			.foregroundStyle(isSelected ? .white : theme.textSecondary)
			.frame(maxWidth: .infinity)
			.frame(height: 40)
			.background(isSelected ? selectedBackground : unselectedBackground)
			.clipShape(Capsule())
		}
		.buttonStyle(.plain)
	}
}

private struct PrimaryButton: View {
	@Environment(\.appTheme) private var theme
	let title: String
	let isEnabled: Bool
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(spacing: 10) {
				Image(systemName: "plus")
					.font(.system(size: 18, weight: .semibold))

				Text(title)
					.font(.system(size: 18, weight: .semibold))
					.lineLimit(1)
					.minimumScaleFactor(0.9)
			}
			.foregroundStyle(.white)
			.frame(maxWidth: .infinity)
			.frame(height: 60)
			.background(theme.accent)
			.clipShape(Capsule())
		}
		.buttonStyle(.plain)
		.disabled(!isEnabled)
		.opacity(isEnabled ? 1 : 0.6)
	}
}

private func partIconName(_ part: DayPart) -> String {
	switch part {
	case .morning:
		"planner_morning"
	case .midday:
		"planner_midday"
	case .evening:
		"planner_evening"
	case .inbox:
		"inbox_empty"
	}
}

private func partSymbolName(_ part: DayPart) -> String {
	switch part {
	case .morning:
		"sun.and.horizon"
	case .midday:
		"sun.max"
	case .evening:
		"moon.stars"
	case .inbox:
		"tray"
	}
}

private func whenIconURL(for part: DayPart) -> URL {
	switch part {
	case .morning:
		whenIconMorningURL
	case .midday:
		whenIconMiddayURL
	case .evening:
		whenIconEveningURL
	case .inbox:
		whenIconInboxURL
	}
}

private let plusIconURL = URL(string: "https://www.figma.com/api/mcp/asset/989cbe21-9303-4195-8d60-245831ac6b20")!
private let fabIconURL = URL(string: "https://www.figma.com/api/mcp/asset/14333ba5-662d-4194-9a97-d376a1640048")!

private let whenIconMorningURL = URL(string: "https://www.figma.com/api/mcp/asset/e5544835-578d-43cb-a150-c9664727a984")!
private let whenIconMiddayURL = URL(string: "https://www.figma.com/api/mcp/asset/bdd8c1df-09c7-4c74-981a-0a3d6e2cb4de")!
private let whenIconEveningURL = URL(string: "https://www.figma.com/api/mcp/asset/358ae451-3bd8-4f72-bd37-59cee23ffd21")!
private let whenIconInboxURL = URL(string: "https://www.figma.com/api/mcp/asset/90131a9e-37e6-4d41-a19c-ec59ab7c4047")!

#if DEBUG
#Preview("Planner") {
	HomeView(viewModel: HomeViewModel())
		.environment(\.appTheme, .default)
}
#endif
