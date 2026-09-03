import Foundation
import SwiftUI

@MainActor
class MovieListsViewModel: ObservableObject {
    @Published var wishlist: MovieList?
    @Published var watched: MovieList?
    @Published var customLists: [MovieList] = []
    @Published var movieCounts: [String: Int] = [:] // listId -> count
    @Published var isLoading = false
    
    private let movieListsManager = MovieListsManager.shared
    
    var wishlistCount: Int { movieCounts[wishlist?.id ?? ""] ?? 0 }
    var watchedCount: Int { movieCounts[watched?.id ?? ""] ?? 0 }
    
    func fetchMovieLists() async {
        isLoading = true
        do {
            // Fetch all lists
            let lists = try await movieListsManager.fetchMovieLists()
            
            // Separate preset and custom lists
            customLists = []
            for list in lists {
                switch list.type {
                case .wishlist:
                    wishlist = list
                case .watched:
                    watched = list
                case .custom:
                    customLists.append(list)
                }
            }
            
            // Ensure preset lists exist
            await createMissingPresetLists()
            
            // Fetch movie counts for all lists
            await fetchMovieCounts()
            
        } catch {
            print("Failed to fetch movie lists: \(error)")
        }
        isLoading = false
    }
    
    private func fetchMovieCounts() async {
        let allLists = [wishlist, watched].compactMap { $0 } + customLists
        
        for list in allLists {
            do {
                let count = try await movieListsManager.getMovieCountForList(listId: list.id)
                movieCounts[list.id] = count
            } catch {
                print("Failed to fetch count for list \(list.name): \(error)")
                movieCounts[list.id] = 0
            }
        }
    }
    
    private func createMissingPresetLists() async {
        let presetTypes: [MovieListType] = [.wishlist, .watched]
        
        for type in presetTypes {
            var foundList: MovieList? = nil
            switch type {
            case .wishlist: foundList = wishlist
            case .watched: foundList = watched
            case .custom: break // Should not happen for preset types
            }
            
            let currentLocalizedName = type.displayName
            let currentLocalizedDescription = movieListsManager.getPresetDescription(for: type)
            
            if let existingList = foundList {
                var listNeedsUpdate = false
                var updatedList = existingList
                
                // Check and update name
                if existingList.name != currentLocalizedName {
                    print("Updating preset list '\(existingList.name)' name to '\(currentLocalizedName)'")
                    do {
                        updatedList = try await movieListsManager.updateListName(listId: existingList.id, newName: currentLocalizedName)
                        listNeedsUpdate = true
                    } catch {
                        print("Failed to update preset list name \(type): \(error)")
                    }
                }
                
                // Check and update description
                if existingList.description != currentLocalizedDescription {
                    print("Updating preset list '\(existingList.name)' description to '\(currentLocalizedDescription)'")
                    do {
                        updatedList = try await movieListsManager.updateListDescription(listId: updatedList.id, newDescription: currentLocalizedDescription)
                        listNeedsUpdate = true
                    } catch {
                        print("Failed to update preset list description \(type): \(error)")
                    }
                }
                
                if listNeedsUpdate {
                    switch type {
                    case .wishlist: self.wishlist = updatedList
                    case .watched: self.watched = updatedList
                    case .custom: break
                    }
                }
            } else {
                // List does not exist, create it
                print("Creating missing preset list: \(type)")
                do {
                    let newList = try await movieListsManager.createPresetList(type: type)
                    switch type {
                    case .wishlist: self.wishlist = newList
                    case .watched: self.watched = newList
                    case .custom: break
                    }
                } catch {
                    print("Failed to create preset list \(type): \(error)")
                }
            }
        }
    }
    
    func createCustomList(name: String, description: String) async {
        do {
            let newList = try await movieListsManager.createCustomList(name: name, description: description)
            customLists.append(newList)
            movieCounts[newList.id] = 0
        } catch {
            print("Failed to create custom list: \(error)")
        }
    }
    
    func addMovieToList(_ movie: Movie, listId: String) async {
        do {
            try await movieListsManager.addMovieToList(movie: movie, listId: listId)
            
            // Update the count
            movieCounts[listId] = (movieCounts[listId] ?? 0) + 1
            print("✅ Successfully added \(movie.title) to list and updated count")
        } catch {
            print("❌ Failed to add movie to list: \(error)")
            // You could show an alert here or handle the error appropriately
        }
    }
    
    func removeMovieFromList(movieId: String, listId: String) async {
        do {
            try await movieListsManager.removeMovieFromList(movieId: movieId, listId: listId)
            
            // Update the count
            movieCounts[listId] = max(0, (movieCounts[listId] ?? 0) - 1)
        } catch {
            print("Failed to remove movie from list: \(error)")
        }
    }
    
    func deleteCustomList(_ list: MovieList) async {
        do {
            try await movieListsManager.deleteList(listId: list.id)
            customLists.removeAll { $0.id == list.id }
            movieCounts.removeValue(forKey: list.id)
        } catch {
            print("Failed to delete list: \(error)")
        }
    }
    
    func getMoviesForList(_ list: MovieList) async -> [StoredMovie] {
        do {
            return try await movieListsManager.fetchMoviesForList(listId: list.id)
        } catch {
            print("Failed to fetch movies for list: \(error)")
            return []
        }
    }
    
    func isMovieInList(_ imdbId: String, listId: String) async -> Bool {
        do {
            return try await movieListsManager.isMovieInList(imdbId: imdbId, listId: listId)
        } catch {
            print("Failed to check membership for \(imdbId) in \(listId): \(error)")
            return false
        }
    }
    
    func membershipForMovie(_ imdbId: String) async -> Set<String> {
        do {
            let listIds = try await movieListsManager.getListsForMovie(imdbId: imdbId)
            return Set(listIds)
        } catch {
            print("Failed to get membership for \(imdbId): \(error)")
            return Set()
        }
    }
}