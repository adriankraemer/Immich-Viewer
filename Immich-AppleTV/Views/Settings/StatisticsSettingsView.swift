import SwiftUI

struct StatisticsSettingsView: View {
    @ObservedObject var userManager: UserManager
    @State private var showingStats = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                SettingsSection(title: "Statistics") {
                    AnyView(
                        Button(action: {
                            showingStats = true
                        }) {
                            HStack {
                                Image(systemName: "chart.bar.xaxis")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                    .frame(width: 24)
                                    .padding()
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("View Library Statistics")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text("See detailed stats about your photos, videos, people, and locations")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(16)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .buttonStyle(CardButtonStyle())
                    )
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
        .fullScreenCover(isPresented: $showingStats) {
            StatsView(statsService: createStatsService())
        }
    }
    
    private func createStatsService() -> StatsService {
        let networkService = NetworkService(userManager: userManager)
        let exploreService = ExploreService(networkService: networkService)
        let peopleService = PeopleService(networkService: networkService)
        return StatsService(exploreService: exploreService, peopleService: peopleService, networkService: networkService)
    }
}

