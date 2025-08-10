import SwiftUI

struct MovieDetailSheet: View {
    let movie: Movie
    let onAdd: (Movie) -> Void
    let currentList: MovieList?
    
    @Environment(\.dismiss) private var dismiss
    @State private var detailedMovie: Movie?
    @State private var extras: MovieExtras?
    @State private var isLoading = true
    @State private var addingFeedback: String?
    @StateObject private var listsVM = MovieListsViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    metaSection
                    overviewSection
                    castCrewSection
                    addSection
                        .padding(.top, 8)
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Movie Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    async let det = MovieAPI.shared.getDetails(imdbID: movie.id)
                    async let ext = MovieAPI.shared.getExtras(imdbID: movie.id)
                    await listsVM.fetchMovieLists()
                    let d = await det
                    let e = await ext
                    await MainActor.run {
                        self.detailedMovie = d ?? movie
                        self.extras = e
                        self.isLoading = false
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let msg = addingFeedback {
                    Text(msg)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.thinMaterial))
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            if let url = (detailedMovie ?? movie).posterURL {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 180)
                    .overlay(
                        Image(systemName: "film")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text((detailedMovie ?? movie).title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                
                if let year = (detailedMovie ?? movie).year {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text("\(year)")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let minutes = extras?.runtimeMinutes {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("\(minutes) min")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    private var metaSection: some View {
        VStack(spacing: 8) {
            if !(detailedMovie ?? movie).genres.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "theatermasks")
                            .foregroundStyle(.secondary)
                        Text("Genres")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                        ForEach((detailedMovie ?? movie).genres, id: \.self) { genre in
                            Text(genre)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.blue.opacity(0.2)))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                Text("IMDb ID: \((detailedMovie ?? movie).id)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var overviewSection: some View {
        Group {
            if isLoading {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading details...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            } else if let plot = extras?.plot, !plot.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .font(.system(size: 18, weight: .bold))
                    Text(plot)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
    }
    
    private var castCrewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let cast = extras?.cast, !cast.isEmpty {
                Text("Cast")
                    .font(.system(size: 18, weight: .bold))
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(cast.prefix(12), id: \.name) { castMember in
                            Text(castMember.name)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.purple.opacity(0.15)))
                                .foregroundStyle(.purple)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            if let dirs = extras?.directors, !dirs.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.viewfinder")
                        .foregroundStyle(.secondary)
                    Text("Director: \(dirs.joined(separator: ", "))")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            }
            if let wrs = extras?.writers, !wrs.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                    Text("Writer: \(wrs.joined(separator: ", "))")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 6)
    }
    
    private var addSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add to Lists")
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 20)
            
            AddButtonsSection(
                movie: detailedMovie ?? movie,
                currentList: currentList,
                listsVM: listsVM,
                onAddToCurrent: {
                    onAdd(detailedMovie ?? movie)
                    showFeedback("Added to \(currentList?.name ?? "List")")
                    dismiss()
                },
                onAddedOther: { list in
                    showFeedback("Added to \(list.name)")
                }
            )
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }
    
    private func showFeedback(_ text: String) {
        withAnimation {
            addingFeedback = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                addingFeedback = nil
            }
        }
    }
}

struct MovieDetailInfoSheet: View {
    let movie: Movie
    let originList: MovieList?
    
    @Environment(\.dismiss) private var dismiss
    @State private var detailedMovie: Movie?
    @State private var extras: MovieExtras?
    @State private var isLoading = true
    @State private var addingFeedback: String?
    @StateObject private var listsVM = MovieListsViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    posterSection
                    titleSection
                    genresSection
                    overviewSection
                    castCrewSection
                    addSection
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("Movie Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    async let det = MovieAPI.shared.getDetails(imdbID: movie.id)
                    async let ext = MovieAPI.shared.getExtras(imdbID: movie.id)
                    await listsVM.fetchMovieLists()
                    let d = await det
                    let e = await ext
                    await MainActor.run {
                        self.detailedMovie = d ?? movie
                        self.extras = e
                        self.isLoading = false
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let msg = addingFeedback {
                    Text(msg)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.thinMaterial))
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    private var posterSection: some View {
        Group {
            if let url = (detailedMovie ?? movie).posterURL {
                AsyncImage(url: url) { img in
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(2/3, contentMode: .fit)
                        .overlay(ProgressView().scaleEffect(1.2))
                }
                .frame(maxWidth: 220, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Rectangle()
                    .fill(LinearGradient(colors: [.purple.opacity(0.2), .pink.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                    .aspectRatio(2/3, contentMode: .fit)
                    .frame(maxWidth: 220, maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        Image(systemName: "film")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.7))
                    )
            }
        }
        .padding(.top, 10)
    }
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text((detailedMovie ?? movie).title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
            
            if let year = (detailedMovie ?? movie).year {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text("\(year)")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }
            
            if let minutes = extras?.runtimeMinutes {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text("\(minutes) min")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var genresSection: some View {
        let currentGenres = (detailedMovie ?? movie).genres
        return Group {
            if !currentGenres.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "theatermasks")
                            .foregroundStyle(.secondary)
                        Text("Genres")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(currentGenres, id: \.self) { genre in
                            Text(genre)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.blue.opacity(0.2)))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var overviewSection: some View {
        Group {
            if isLoading {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading additional details...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            } else if let plot = extras?.plot, !plot.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .font(.system(size: 18, weight: .bold))
                    Text(plot)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var castCrewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let cast = extras?.cast, !cast.isEmpty {
                Text("Cast")
                    .font(.system(size: 18, weight: .bold))
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(cast.prefix(12), id: \.name) { castMember in
                            Text(castMember.name)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.purple.opacity(0.15)))
                                .foregroundStyle(.purple)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            if let dirs = extras?.directors, !dirs.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.viewfinder")
                        .foregroundStyle(.secondary)
                    Text("Director: \(dirs.joined(separator: ", "))")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            }
            if let wrs = extras?.writers, !wrs.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                    Text("Writer: \(wrs.joined(separator: ", "))")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 6)
    }
    
    private var addSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add to Lists")
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 20)
            
            AddButtonsSection(
                movie: detailedMovie ?? movie,
                currentList: originList,
                listsVM: listsVM,
                onAddToCurrent: {
                    if let list = originList {
                        Task {
                            await listsVM.addMovieToList(detailedMovie ?? movie, listId: list.id)
                            showFeedback("Added to \(list.name)")
                        }
                    }
                },
                onAddedOther: { list in
                    showFeedback("Added to \(list.name)")
                }
            )
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }
    
    private func showFeedback(_ text: String) {
        withAnimation {
            addingFeedback = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                addingFeedback = nil
            }
        }
    }
}

struct AddButtonsSection: View {
    let movie: Movie
    let currentList: MovieList?
    @ObservedObject var listsVM: MovieListsViewModel
    let onAddToCurrent: () -> Void
    let onAddedOther: (MovieList) -> Void
    
    @State private var addedListIDs: Set<String> = []
    @State private var loadingMembership = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let primary = currentList {
                let isAdded = addedListIDs.contains(primary.id)
                Button {
                    if !isAdded {
                        addedListIDs.insert(primary.id)
                        onAddToCurrent()
                    }
                } label: {
                    HStack {
                        Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                        Text(isAdded ? "Added to \(primary.name)" : "Add to \(primary.name)")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(colors: primaryColors(for: primary), startPoint: .topLeading, endPoint: .bottomTrailing).opacity(isAdded ? 0.6 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isAdded)
            }
            
            HStack(spacing: 10) {
                if let wishlist = listsVM.wishlist, wishlist.id != currentList?.id {
                    addChip(list: wishlist, colors: [.red, .pink])
                }
                if let watched = listsVM.watched, watched.id != currentList?.id {
                    addChip(list: watched, colors: [.green, .mint])
                }
            }
            
            if !listsVM.customLists.filter({ $0.id != currentList?.id }).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(listsVM.customLists.filter { $0.id != currentList?.id }) { list in
                            addChip(list: list, colors: [.purple, .pink])
                        }
                    }
                }
            }
        }
        .task {
            let membership = await listsVM.membershipForMovie(movie.id)
            print("🎬 Membership for \(movie.title) (\(movie.id)): \(membership)")
            print("🎬 Current list ID: \(currentList?.id ?? "nil")")
            await MainActor.run {
                self.addedListIDs = membership
                self.loadingMembership = false
            }
        }
    }
    
    private func addChip(list: MovieList, colors: [Color]) -> some View {
        let isAdded = addedListIDs.contains(list.id)
        return Button {
            if !isAdded {
                Task {
                    await listsVM.addMovieToList(movie, listId: list.id)
                    await MainActor.run {
                        addedListIDs.insert(list.id)
                    }
                    onAddedOther(list)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon(for: list))
                    .font(.system(size: 14, weight: .bold))
                Text(list.name)
                    .font(.system(size: 13, weight: .semibold))
                if isAdded {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: colors.map { $0.opacity(isAdded ? 0.12 : 0.18) }, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .foregroundStyle(isAdded ? .secondary : .primary)
            .overlay(
                Group {
                    if !isAdded {
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                            .mask(
                                HStack(spacing: 6) {
                                    Image(systemName: icon(for: list))
                                        .font(.system(size: 14, weight: .bold))
                                    Text(list.name)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            )
                    }
                }
            )
            .clipShape(Capsule())
            .opacity(isAdded ? 0.7 : 1)
        }
        .disabled(isAdded)
    }
    
    private func icon(for list: MovieList) -> String {
        switch list.type {
        case .wishlist: return "heart.fill"
        case .watched: return "checkmark.seal.fill"
        case .custom: return "rectangle.stack.fill"
        }
    }
    
    private func primaryColors(for list: MovieList) -> [Color] {
        switch list.type {
        case .wishlist: return [.red, .pink]
        case .watched: return [.green, .mint]
        case .custom: return [.purple, .pink]
        }
    }
}