import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    // Define grid columns: 3 flexible columns
    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    // State for presenting share sheet
    @State private var showShareSheet = false
    @State private var itemToShare: ShareableItem? = nil

    // Structure to hold item for sharing, conforming to Identifiable for .sheet
    struct ShareableItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    // State for navigating to CameraView
    @State private var navigateToCameraView = false

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) { // ZStack for overlaying button
                VStack(spacing: 0) {
                    // Month Navigation
                    HStack {
                        Button(action: {
                            viewModel.changeMonth(by: -1)
                        }) {
                            Image(systemName: "chevron.left")
                                .padding()
                        }
                        Spacer()
                        Text(viewModel.displayedMonthYearString)
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            viewModel.changeMonth(by: 1)
                        }) {
                            Image(systemName: "chevron.right")
                                .padding()
                        }
                    }
                    .padding(.horizontal)
                    .background(Color(.systemGroupedBackground))

                    ScrollView {
                        VStack(spacing: 15) {
                            // Monthly Recap Banner
                            if let monthlyRecap = viewModel.monthlyRecap {
                                RecapBannerView(
                                    recapInfo: monthlyRecap,
                                    backgroundColor: Color.yellow.opacity(0.2),
                                    iconName: "sparkles",
                                onPlay: { viewModel.selectVideoForPlayback(url: monthlyRecap.url) },
                                    onShare: { self.itemToShare = ShareableItem(url: monthlyRecap.url) }
                                )
                                .padding(.horizontal)
                            }

                            // Weekly Recap Banner
                            if let weeklyRecap = viewModel.weeklyRecap {
                                RecapBannerView(
                                    recapInfo: weeklyRecap,
                                    backgroundColor: Color.purple.opacity(0.2),
                                    iconName: "film.stack",
                                onPlay: { viewModel.selectVideoForPlayback(url: weeklyRecap.url) },
                                    onShare: { self.itemToShare = ShareableItem(url: weeklyRecap.url) }
                                )
                                .padding(.horizontal)
                            }

                            if !viewModel.videosForDisplayedMonth.isEmpty && (viewModel.monthlyRecap != nil || viewModel.weeklyRecap != nil) {
                                Divider().padding(.horizontal)
                            }


                            // Daily Videos Section Title (Optional)
                            if !viewModel.videosForDisplayedMonth.isEmpty {
                                Text("Daily Entries")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .padding(.top)
                                    .padding(.horizontal)
                            }

                            if viewModel.videosForDisplayedMonth.isEmpty {
                                if viewModel.monthlyRecap == nil && viewModel.weeklyRecap == nil {
                                    Spacer(minLength: 50)
                                    Text("No videos recorded this month.")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                } else {
                                    Text("No daily videos for \(viewModel.displayedMonthYearString).")
                                        .foregroundColor(.secondary)
                                        .padding()
                                }
                            } else {
                                LazyVGrid(columns: gridColumns, spacing: 10) {
                                    ForEach(viewModel.videosForDisplayedMonth) { video in
                                        VideoGridItemView(video: video)
                                            .onTapGesture {
                                            viewModel.selectVideoForPlayback(url: video.url) // Use new method
                                            }
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    viewModel.deleteVideo(video)
                                                } label: {
                                                    Label("Delete Video", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                                .padding()
                            }
                             // Add padding to the bottom of ScrollView content to avoid overlap with button
                            Color.clear.frame(height: 80)
                        }
                    }
                }

                // Record Button Area
                VStack(spacing:0) {
                    // Optional: Divider or gradient here
                    Rectangle() // Invisible spacer to push button up if keyboard appears or for safe area
                        .fill(Color.clear)
                        .frame(height: 0) // Adjust as needed, or use actual safe area insets

                    Button(action: {
                        if viewModel.canRecordToday {
                            navigateToCameraView = true
                        }
                    }) {
                        Text(viewModel.recordButtonText)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.canRecordToday ? Color.blue : Color.gray.opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!viewModel.canRecordToday)
                    .padding(.horizontal)
                    .padding(.bottom, 10) // Padding from the very bottom edge
                    .background(Color(.systemBackground).edgesIgnoringSafeArea(.bottom)) // Extend background for button area
                }

                // NavigationLink for CameraView
                NavigationLink(destination: CameraView(), isActive: $navigateToCameraView) {
                    EmptyView()
                }
            }
            .navigationTitle("Bello Dairy")
            .toolbar { // Toolbar still available for other items if needed
                 // Removed the old record button from toolbar
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    NavigationLink(destination: CameraView()) {
//                        Image(systemName: "video.badge.plus")
//                            .font(.title2)
//                    }
//                }
            }
            .onAppear {
                viewModel.fetchAndFilterVideos() // This calls updateRecordButtonState internally
            }
            .onDisappear {
                viewModel.cleanupTimer() // Cleanup timer when view disappears
            }
            .sheet(item: $viewModel.selectedVideoURL, onDismiss: {
                viewModel.deselectVideo()
            }) { videoURL in
                VideoPlayerView(videoURL: videoURL)
            }
            .sheet(item: $itemToShare) { item in
                ActivityView(activityItems: [item.url])
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - RecapBannerView
struct RecapBannerView: View {
    let recapInfo: RecapInfo
    let backgroundColor: Color
    let iconName: String
    let onPlay: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Rectangle()
                    .fill(backgroundColor.opacity(0.5))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(backgroundColor.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recapInfo.title)
                    .font(.headline)
                Text(recapInfo.type == .monthly ? "Monthly Digest" : "Weekly Highlights")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack {
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                }
                .padding(.trailing, 5)

                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.title2)
                }
            }
            .foregroundColor(backgroundColor.opacity(0.8)) // Adjusted for better visibility
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(radius: 3)
    }
}


// MARK: - VideoGridItemView (remains mostly the same)
struct VideoGridItemView: View {
    let video: Video
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter
    }()

    var body: some View {
        VStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1.0, contentMode: .fit)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.white)
                        .font(.largeTitle)
                )
                .cornerRadius(8)

            Text(Self.dateFormatter.string(from: video.date))
                .font(.caption)
                .padding(.top, 2)
        }
    }
}

// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let homeViewModel = HomeViewModel()
        // For previewing specific states, you might need to adjust HomeViewModel's init
        // or directly set its @Published properties here if it were an @ObservedObject passed in.
        // Example:
        // homeViewModel.canRecordToday = false
        // homeViewModel.recordButtonText = "Disponible en 03h 25m"
        HomeView()
    }
}
