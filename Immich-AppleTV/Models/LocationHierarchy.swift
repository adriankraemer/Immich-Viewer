//
//  LocationHierarchy.swift
//  Immich-AppleTV
//
//  Created for hierarchical location organization
//

import Foundation
import SwiftUI

// MARK: - Continent Model
struct Continent: GridDisplayable, Identifiable, Hashable {
    let name: String
    let countries: [Country]
    let representativeAssetId: String?
    
    var id: String { name }
    var primaryTitle: String { name }
    var secondaryTitle: String? { "\(countries.count) \(countries.count == 1 ? "country" : "countries")" }
    var description: String? {
        let totalPhotos = countries.reduce(0) { $0 + ($1.assetCount) }
        return "\(totalPhotos) \(totalPhotos == 1 ? "photo" : "photos")"
    }
    var thumbnailId: String? { representativeAssetId }
    var itemCount: Int? {
        countries.reduce(0) { $0 + ($1.assetCount) }
    }
    var gridCreatedAt: String? { nil }
    var isFavorite: Bool? { nil }
    var isShared: Bool? { false }
    var sharingText: String? { nil }
    var iconName: String { "globe" }
    var gridColor: Color? { continentColor(for: name) }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static func == (lhs: Continent, rhs: Continent) -> Bool {
        lhs.name == rhs.name
    }
    
    private func continentColor(for name: String) -> Color {
        switch name.lowercased() {
        case "asia": return .red.opacity(0.5)
        case "europe": return .blue.opacity(0.5)
        case "north america": return .green.opacity(0.5)
        case "south america": return .yellow.opacity(0.5)
        case "africa": return .orange.opacity(0.5)
        case "oceania": return .purple.opacity(0.5)
        case "antarctica": return .cyan.opacity(0.5)
        default: return .gray.opacity(0.5)
        }
    }
}

// MARK: - Country Model (Lightweight - no assets stored)
struct Country: GridDisplayable, Identifiable, Hashable {
    let name: String
    let continent: String
    let assetCount: Int
    let representativeAssetId: String?
    
    var id: String { "\(continent)_\(name)" }
    var primaryTitle: String { name }
    var secondaryTitle: String? { continent }
    var description: String? { "\(assetCount) \(assetCount == 1 ? "photo" : "photos")" }
    var thumbnailId: String? { representativeAssetId }
    var itemCount: Int? { assetCount }
    var gridCreatedAt: String? { nil }
    var isFavorite: Bool? { nil }
    var isShared: Bool? { false }
    var sharingText: String? { nil }
    var iconName: String { "mappin.circle" }
    var gridColor: Color? { nil }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(continent)
    }
    
    static func == (lhs: Country, rhs: Country) -> Bool {
        lhs.name == rhs.name && lhs.continent == rhs.continent
    }
}

// MARK: - Country to Continent Mapping
struct ContinentMapper {
    static func getContinent(for country: String) -> String {
        // Normalize country name: lowercase, trim, and handle special characters
        var normalizedCountry = country.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Handle common special character variations
        normalizedCountry = normalizedCountry
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "é", with: "e")
            .replacingOccurrences(of: "è", with: "e")
            .replacingOccurrences(of: "ê", with: "e")
            .replacingOccurrences(of: "ë", with: "e")
            .replacingOccurrences(of: "á", with: "a")
            .replacingOccurrences(of: "à", with: "a")
            .replacingOccurrences(of: "â", with: "a")
            .replacingOccurrences(of: "ã", with: "a")
            .replacingOccurrences(of: "ç", with: "c")
            .replacingOccurrences(of: "ñ", with: "n")
            .replacingOccurrences(of: "í", with: "i")
            .replacingOccurrences(of: "î", with: "i")
            .replacingOccurrences(of: "ï", with: "i")
            .replacingOccurrences(of: "ó", with: "o")
            .replacingOccurrences(of: "ô", with: "o")
            .replacingOccurrences(of: "õ", with: "o")
            .replacingOccurrences(of: "ú", with: "u")
            .replacingOccurrences(of: "û", with: "u")
        
        // Comprehensive country to continent mapping
        let mapping: [String: String] = [
            // Asia
            "china": "Asia", "peoples republic of china": "Asia", "prc": "Asia", "japan": "Asia", "india": "Asia", "south korea": "Asia", "republic of korea": "Asia", "korea": "Asia",
            "north korea": "Asia", "democratic peoples republic of korea": "Asia", "dprk": "Asia", "thailand": "Asia", "vietnam": "Asia", "indonesia": "Asia",
            "philippines": "Asia", "malaysia": "Asia", "singapore": "Asia", "taiwan": "Asia", "republic of china": "Asia",
            "hong kong": "Asia", "hongkong": "Asia", "macau": "Asia", "macao": "Asia", "bangladesh": "Asia",
            "pakistan": "Asia", "afghanistan": "Asia", "iran": "Asia", "islamic republic of iran": "Asia", "iraq": "Asia",
            "saudi arabia": "Asia", "kingdom of saudi arabia": "Asia", "uae": "Asia", "united arab emirates": "Asia",
            "israel": "Asia", "state of israel": "Asia", "turkey": "Asia", "turkiye": "Asia", "turkish": "Asia", "republic of turkey": "Asia",
            "russia": "Asia", "russian federation": "Asia", "kazakhstan": "Asia", "republic of kazakhstan": "Asia",
            "mongolia": "Asia", "nepal": "Asia", "sri lanka": "Asia", "srilanka": "Asia", "myanmar": "Asia", "burma": "Asia",
            "cambodia": "Asia", "kingdom of cambodia": "Asia", "laos": "Asia", "lao peoples democratic republic": "Asia",
            "brunei": "Asia", "brunei darussalam": "Asia", "kyrgyzstan": "Asia", "kyrgyz republic": "Asia",
            "tajikistan": "Asia", "republic of tajikistan": "Asia", "uzbekistan": "Asia", "republic of uzbekistan": "Asia",
            "turkmenistan": "Asia", "azerbaijan": "Asia", "republic of azerbaijan": "Asia",
            "georgia": "Asia", "armenia": "Asia", "republic of armenia": "Asia", "lebanon": "Asia", "lebanese republic": "Asia",
            "jordan": "Asia", "hashemite kingdom of jordan": "Asia", "syria": "Asia", "syrian arab republic": "Asia",
            "yemen": "Asia", "republic of yemen": "Asia", "oman": "Asia", "sultanate of oman": "Asia",
            "kuwait": "Asia", "state of kuwait": "Asia", "qatar": "Asia", "state of qatar": "Asia",
            "bahrain": "Asia", "kingdom of bahrain": "Asia", "cyprus": "Asia", "republic of cyprus": "Asia",
            
            // Europe
            "united kingdom": "Europe", "uk": "Europe", "great britain": "Europe", "britain": "Europe", "england": "Europe", "scotland": "Europe", "wales": "Europe",
            "france": "Europe", "french republic": "Europe", "germany": "Europe", "federal republic of germany": "Europe", "deutschland": "Europe",
            "italy": "Europe", "italian republic": "Europe", "spain": "Europe", "kingdom of spain": "Europe", "espana": "Europe",
            "portugal": "Europe", "portuguese republic": "Europe", "greece": "Europe", "hellenic republic": "Europe",
            "netherlands": "Europe", "holland": "Europe", "kingdom of the netherlands": "Europe", "belgium": "Europe", "kingdom of belgium": "Europe",
            "switzerland": "Europe", "swiss confederation": "Europe", "austria": "Europe", "republic of austria": "Europe",
            "poland": "Europe", "republic of poland": "Europe", "czech republic": "Europe", "czechia": "Europe",
            "hungary": "Europe", "romania": "Europe", "bulgaria": "Europe", "republic of bulgaria": "Europe",
            "croatia": "Europe", "republic of croatia": "Europe", "serbia": "Europe", "republic of serbia": "Europe",
            "slovakia": "Europe", "slovak republic": "Europe", "slovenia": "Europe", "republic of slovenia": "Europe",
            "denmark": "Europe", "kingdom of denmark": "Europe", "sweden": "Europe", "kingdom of sweden": "Europe",
            "norway": "Europe", "kingdom of norway": "Europe", "finland": "Europe", "republic of finland": "Europe",
            "iceland": "Europe", "republic of iceland": "Europe", "ireland": "Europe", "republic of ireland": "Europe", "eire": "Europe",
            "luxembourg": "Europe", "grand duchy of luxembourg": "Europe", "malta": "Europe", "republic of malta": "Europe",
            "estonia": "Europe", "republic of estonia": "Europe", "latvia": "Europe", "republic of latvia": "Europe",
            "lithuania": "Europe", "republic of lithuania": "Europe", "albania": "Europe", "republic of albania": "Europe",
            "macedonia": "Europe", "north macedonia": "Europe", "republic of north macedonia": "Europe",
            "bosnia": "Europe", "bosnia and herzegovina": "Europe", "montenegro": "Europe", "moldova": "Europe", "republic of moldova": "Europe",
            "ukraine": "Europe", "belarus": "Europe", "republic of belarus": "Europe",
            "monaco": "Europe", "principality of monaco": "Europe", "liechtenstein": "Europe", "principality of liechtenstein": "Europe",
            "andorra": "Europe", "principality of andorra": "Europe", "san marino": "Europe", "republic of san marino": "Europe",
            "vatican": "Europe", "vatican city": "Europe", "holy see": "Europe",
            
            // North America
            "united states": "North America", "usa": "North America", "us": "North America",
            "canada": "North America", "mexico": "North America", "cuba": "North America",
            "jamaica": "North America", "haiti": "North America", "dominican republic": "North America",
            "guatemala": "North America", "belize": "North America", "honduras": "North America",
            "el salvador": "North America", "nicaragua": "North America", "costa rica": "North America",
            "panama": "North America", "bahamas": "North America", "barbados": "North America",
            "trinidad and tobago": "North America", "puerto rico": "North America",
            
            // South America
            "brazil": "South America", "argentina": "South America", "chile": "South America",
            "peru": "South America", "colombia": "South America", "venezuela": "South America",
            "ecuador": "South America", "bolivia": "South America", "paraguay": "South America",
            "uruguay": "South America", "guyana": "South America", "suriname": "South America",
            "french guiana": "South America",
            
            // Africa
            "south africa": "Africa", "egypt": "Africa", "nigeria": "Africa", "kenya": "Africa",
            "morocco": "Africa", "tunisia": "Africa", "algeria": "Africa", "ethiopia": "Africa",
            "ghana": "Africa", "tanzania": "Africa", "uganda": "Africa", "zimbabwe": "Africa",
            "zambia": "Africa", "mozambique": "Africa", "madagascar": "Africa", "cameroon": "Africa",
            "ivory coast": "Africa", "senegal": "Africa", "sudan": "Africa", "angola": "Africa",
            "libya": "Africa", "mauritania": "Africa", "mali": "Africa", "niger": "Africa",
            "chad": "Africa", "burkina faso": "Africa", "guinea": "Africa", "sierra leone": "Africa",
            "liberia": "Africa", "togo": "Africa", "benin": "Africa", "gambia": "Africa",
            "guinea-bissau": "Africa", "cape verde": "Africa", "são tomé and príncipe": "Africa",
            "equatorial guinea": "Africa", "gabon": "Africa", "congo": "Africa",
            "democratic republic of the congo": "Africa", "central african republic": "Africa",
            "rwanda": "Africa", "burundi": "Africa", "eritrea": "Africa", "djibouti": "Africa",
            "somalia": "Africa", "comoros": "Africa", "seychelles": "Africa", "mauritius": "Africa",
            "reunion": "Africa", "mayotte": "Africa", "saint helena": "Africa",
            
            // Oceania
            "australia": "Oceania", "new zealand": "Oceania", "fiji": "Oceania",
            "papua new guinea": "Oceania", "samoa": "Oceania", "tonga": "Oceania",
            "vanuatu": "Oceania", "new caledonia": "Oceania", "french polynesia": "Oceania",
            "guam": "Oceania", "micronesia": "Oceania", "palau": "Oceania", "marshall islands": "Oceania",
            "solomon islands": "Oceania", "kiribati": "Oceania", "nauru": "Oceania", "tuvalu": "Oceania",
            
            // Antarctica
            "antarctica": "Antarctica"
        ]
        
        // Direct lookup
        if let continent = mapping[normalizedCountry] {
            return continent
        }
        
        // Try partial matches for common variations
        for (key, value) in mapping {
            if normalizedCountry.contains(key) || key.contains(normalizedCountry) {
                return value
            }
        }
        
        // Default to "Unknown" if not found
        return "Unknown"
    }
    
    // Normalize country name for grouping (same normalization as getContinent)
    private static func normalizeCountryName(_ country: String) -> String {
        var normalized = country.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Handle common special character variations
        normalized = normalized
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "é", with: "e")
            .replacingOccurrences(of: "è", with: "e")
            .replacingOccurrences(of: "ê", with: "e")
            .replacingOccurrences(of: "ë", with: "e")
            .replacingOccurrences(of: "á", with: "a")
            .replacingOccurrences(of: "à", with: "a")
            .replacingOccurrences(of: "â", with: "a")
            .replacingOccurrences(of: "ã", with: "a")
            .replacingOccurrences(of: "ç", with: "c")
            .replacingOccurrences(of: "ñ", with: "n")
            .replacingOccurrences(of: "í", with: "i")
            .replacingOccurrences(of: "î", with: "i")
            .replacingOccurrences(of: "ï", with: "i")
            .replacingOccurrences(of: "ó", with: "o")
            .replacingOccurrences(of: "ô", with: "o")
            .replacingOccurrences(of: "õ", with: "o")
            .replacingOccurrences(of: "ú", with: "u")
            .replacingOccurrences(of: "û", with: "u")
        
        return normalized
    }
    
    // Get canonical country name from normalized name (for display)
    static func getCanonicalCountryName(from normalized: String, original: String) -> String {
        // Map of normalized names to canonical display names
        let canonicalMap: [String: String] = [
            "turkey": "Turkey", "turkiye": "Turkey", "turkish": "Turkey",
            "united states": "United States", "usa": "United States", "us": "United States",
            "united kingdom": "United Kingdom", "uk": "United Kingdom", "great britain": "United Kingdom", "britain": "United Kingdom",
            "england": "United Kingdom", "scotland": "United Kingdom", "wales": "United Kingdom",
            "netherlands": "Netherlands", "holland": "Netherlands",
            "czech republic": "Czech Republic", "czechia": "Czech Republic",
            "south korea": "South Korea", "republic of korea": "South Korea", "korea": "South Korea",
            "north korea": "North Korea", "democratic peoples republic of korea": "North Korea", "dprk": "North Korea",
            "russia": "Russia", "russian federation": "Russia",
            "hong kong": "Hong Kong", "hongkong": "Hong Kong",
            "macau": "Macau", "macao": "Macau",
            "sri lanka": "Sri Lanka", "srilanka": "Sri Lanka",
            "myanmar": "Myanmar", "burma": "Myanmar",
            "bosnia": "Bosnia and Herzegovina", "bosnia and herzegovina": "Bosnia and Herzegovina",
            "macedonia": "North Macedonia", "north macedonia": "North Macedonia", "republic of north macedonia": "North Macedonia",
            "ivory coast": "Ivory Coast",
            "cape verde": "Cape Verde",
            "sao tome and principe": "São Tomé and Príncipe", "são tomé and príncipe": "São Tomé and Príncipe",
            "papua new guinea": "Papua New Guinea",
            "marshall islands": "Marshall Islands",
            "solomon islands": "Solomon Islands",
            "trinidad and tobago": "Trinidad and Tobago",
            "puerto rico": "Puerto Rico",
            "costa rica": "Costa Rica",
            "el salvador": "El Salvador",
            "south africa": "South Africa",
            "new zealand": "New Zealand",
            "french guiana": "French Guiana",
            "french polynesia": "French Polynesia",
            "new caledonia": "New Caledonia",
            "central african republic": "Central African Republic",
            "democratic republic of the congo": "Democratic Republic of the Congo",
            "burkina faso": "Burkina Faso",
            "sierra leone": "Sierra Leone",
            "guinea-bissau": "Guinea-Bissau",
            "equatorial guinea": "Equatorial Guinea",
            "saint helena": "Saint Helena"
        ]
        
        // Check if we have a canonical name
        if let canonical = canonicalMap[normalized] {
            return canonical
        }
        
        // Otherwise, capitalize the original properly (title case)
        return original.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
    
    /// Organize location summaries into continent hierarchy (lightweight, no full assets)
    static func organizeLocationSummaries(_ summaries: [LocationSummary]) -> [Continent] {
        // Group summaries by continent
        var continentMap: [String: [LocationSummary]] = [:]
        
        for summary in summaries {
            let continent = getContinent(for: summary.country)
            if continentMap[continent] == nil {
                continentMap[continent] = []
            }
            continentMap[continent]!.append(summary)
        }
        
        // Convert to hierarchical models
        var continents: [Continent] = []
        
        for (continentName, countrySummaries) in continentMap.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }) {
            // Merge summaries with same normalized country name
            var mergedCountries: [String: (displayName: String, count: Int, representativeAssetId: String?)] = [:]
            
            for summary in countrySummaries {
                let normalizedName = normalizeCountryName(summary.country)
                let displayName = getCanonicalCountryName(from: normalizedName, original: summary.country)
                
                if let existing = mergedCountries[normalizedName] {
                    mergedCountries[normalizedName] = (
                        displayName: existing.displayName,
                        count: existing.count + summary.count,
                        representativeAssetId: existing.representativeAssetId ?? summary.representativeAssetId
                    )
                } else {
                    mergedCountries[normalizedName] = (
                        displayName: displayName,
                        count: summary.count,
                        representativeAssetId: summary.representativeAssetId
                    )
                }
            }
            
            let countries: [Country] = mergedCountries
                .sorted(by: { $0.value.displayName.localizedCaseInsensitiveCompare($1.value.displayName) == .orderedAscending })
                .map { (_, value) in
                    Country(
                        name: value.displayName,
                        continent: continentName,
                        assetCount: value.count,
                        representativeAssetId: value.representativeAssetId
                    )
                }
            
            let representativeAssetId = countries.first?.representativeAssetId
            let continent = Continent(
                name: continentName,
                countries: countries,
                representativeAssetId: representativeAssetId
            )
            continents.append(continent)
        }
        
        return continents
    }
}

// MARK: - Location Summary (lightweight structure for initial load)
struct LocationSummary {
    let country: String
    let count: Int
    let representativeAssetId: String?
}

