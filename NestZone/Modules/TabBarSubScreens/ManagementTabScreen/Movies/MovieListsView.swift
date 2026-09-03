import SwiftUI

struct MovieListsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.basic
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = MovieListsViewModel()
    
    @State private var showingCreateList = false
    @State private var showingSearchMovies = false
    @State private var selectedList: MovieList?
    
    private var theme: ThemeColors {
        selectedTheme.colors(for: colorScheme)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                RadialGradient(
                    colors: [
                        theme.background,
                        Color.purple.opacity(0.05),
                        Color.pink.opacity(0.03)
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 1200
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerView
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                        
                        presetListsSection
                            .padding(.horizontal, 24)
                        
                        customListsSection
                            .padding(.horizontal, 24)
                        
                        Spacer(minLength: 80)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizationManager.commonClose) { dismiss() }
                        .foregroundStyle(theme.text)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateList = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.fetchMovieLists()
                }
            }
        }
        .fullScreenCover(isPresented: $showingCreateList) {
            CreateMovieListSheet { name, description in
                Task {
                    await viewModel.createCustomList(name: name, description: description)
                }
            }
        }
        .fullScreenCover(item: $selectedList, onDismiss: {
            selectedList = nil
        }) { list in
            MovieListDetailView(movieList: list, viewModel: viewModel)
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizationManager.movieListsTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [theme.text, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text(LocalizationManager.movieListsSubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.2), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: "film.stack")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
        }
    }
    
    private var presetListsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizationManager.movieListsQuickCollections)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
            
            HStack(spacing: 16) {
                PresetListCard(
                    title: LocalizationManager.movieListsWishlistTitle,
                    subtitle: LocalizationManager.movieListsWishlistSubtitle,
                    icon: "heart.fill",
                    colors: [.red, .pink],
                    count: viewModel.wishlistCount
                ) {
                    selectedList = viewModel.wishlist
                }
                
                PresetListCard(
                    title: LocalizationManager.movieListsWatchedTitle,
                    subtitle: LocalizationManager.movieListsWatchedSubtitle,
                    icon: "checkmark.seal.fill",
                    colors: [.green, .mint],
                    count: viewModel.watchedCount
                ) {
                    selectedList = viewModel.watched
                }
            }
        }
    }
    
    private var customListsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizationManager.movieListsCustomLists)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                Spacer()
                if !viewModel.customLists.isEmpty {
                    Text("\(viewModel.customLists.count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.purple.opacity(0.2)))
                }
            }
            
            if viewModel.customLists.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "plus.rectangle.on.folder")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.6), .pink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    VStack(spacing: 8) {
                        Text(LocalizationManager.movieListsNoCustomLists)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        Text(LocalizationManager.movieListsNoCustomListsSubtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button {
                        showingCreateList = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text(LocalizationManager.movieListsCreateFirstList)
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(LinearGradient(colors: [.purple.opacity(0.3), .pink.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    )
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.customLists) { list in
                        CustomListRow(list: list, movieCount: viewModel.movieCounts[list.id] ?? 0) {
                            selectedList = list
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    MovieListsView()
}