import Foundation
import SwiftUI

@MainActor
class PeopleGridViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var people: [Person] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPerson: Person?
    
    // MARK: - Dependencies
    private let peopleService: PeopleService
    private let authService: AuthenticationService
    
    // MARK: - Initialization
    
    init(
        peopleService: PeopleService,
        authService: AuthenticationService
    ) {
        self.peopleService = peopleService
        self.authService = authService
    }
    
    // MARK: - Public Methods
    
    /// Loads all people from the service
    func loadPeople() {
        debugLog("PeopleGridViewModel: loadPeople called - isAuthenticated: \(authService.isAuthenticated)")
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        debugLog("PeopleGridViewModel: Loading people - isAuthenticated: \(authService.isAuthenticated), baseURL: \(authService.baseURL)")
        
        isLoading = true
        errorMessage = nil
        debugLog("PeopleGridViewModel: Set loading state to true")
        
        Task {
            do {
                let fetchedPeople = try await peopleService.getAllPeople()
                debugLog("PeopleGridViewModel: Successfully fetched \(fetchedPeople.count) people")
                self.people = fetchedPeople
                self.isLoading = false
                debugLog("PeopleGridViewModel: Updated UI with \(self.people.count) people, isLoading: \(self.isLoading)")
            } catch {
                debugLog("PeopleGridViewModel: Error fetching people: \(error)")
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                debugLog("PeopleGridViewModel: Set error state, isLoading: \(self.isLoading)")
            }
        }
    }
    
    /// Selects a person
    func selectPerson(_ person: Person) {
        debugLog("PeopleGridViewModel: Person selected: \(person.id)")
        selectedPerson = person
    }
    
    /// Clears the selected person
    func clearSelection() {
        selectedPerson = nil
    }
    
    /// Retries loading people
    func retry() {
        loadPeople()
    }
    
    /// Loads people if not already loaded
    func loadPeopleIfNeeded() {
        debugLog("PeopleGridViewModel: View appeared, people count: \(people.count), isLoading: \(isLoading), errorMessage: \(errorMessage ?? "nil")")
        if people.isEmpty && !isLoading {
            loadPeople()
        }
    }
}

