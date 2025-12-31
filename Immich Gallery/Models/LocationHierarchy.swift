//
//  LocationHierarchy.swift
//  Immich Gallery
//
//  Created for hierarchical location organization
//

import Foundation
import SwiftUI

// MARK: - Continent Model
struct Continent: GridDisplayable, Identifiable, Hashable {
    let name: String
    let countries: [Country]
    let representativeAsset: ImmichAsset?
    
    var id: String { name }
    var primaryTitle: String { name }
    var secondaryTitle: String? { "\(countries.count) \(countries.count == 1 ? "country" : "countries")" }
    var description: String? {
        let totalCities = countries.reduce(0) { $0 + $1.cities.count }
        return "\(totalCities) \(totalCities == 1 ? "city" : "cities")"
    }
    var thumbnailId: String? { representativeAsset?.id }
    var itemCount: Int? {
        countries.reduce(0) { $0 + ($1.itemCount ?? 0) }
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

// MARK: - Country Model
struct Country: GridDisplayable, Identifiable, Hashable {
    let name: String
    let continent: String
    let cities: [City]
    let representativeAsset: ImmichAsset?
    
    var id: String { name }
    var primaryTitle: String { name }
    var secondaryTitle: String? { continent }
    var description: String? { "\(cities.count) \(cities.count == 1 ? "city" : "cities")" }
    var thumbnailId: String? { representativeAsset?.id }
    var itemCount: Int? {
        cities.reduce(0) { $0 + ($1.itemCount ?? 0) }
    }
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

// MARK: - City Model
struct City: GridDisplayable, Identifiable, Hashable {
    let name: String
    let country: String
    let continent: String
    let assets: [ImmichAsset]
    let representativeAsset: ImmichAsset?
    
    var id: String { "\(name)_\(country)" }
    var primaryTitle: String { name }
    var secondaryTitle: String? { country }
    var description: String? { nil }
    var thumbnailId: String? { representativeAsset?.id }
    var itemCount: Int? { assets.count }
    var gridCreatedAt: String? { nil }
    var isFavorite: Bool? { nil }
    var isShared: Bool? { false }
    var sharingText: String? { nil }
    var iconName: String { "building.2" }
    var gridColor: Color? { nil }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(country)
    }
    
    static func == (lhs: City, rhs: City) -> Bool {
        lhs.name == rhs.name && lhs.country == rhs.country
    }
}

// MARK: - Country to Continent Mapping
struct ContinentMapper {
    static func getContinent(for country: String) -> String {
        let normalizedCountry = country.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Comprehensive country to continent mapping
        let mapping: [String: String] = [
            // Asia
            "china": "Asia", "japan": "Asia", "india": "Asia", "south korea": "Asia",
            "north korea": "Asia", "thailand": "Asia", "vietnam": "Asia", "indonesia": "Asia",
            "philippines": "Asia", "malaysia": "Asia", "singapore": "Asia", "taiwan": "Asia",
            "hong kong": "Asia", "macau": "Asia", "macao": "Asia", "bangladesh": "Asia",
            "pakistan": "Asia", "afghanistan": "Asia", "iran": "Asia", "iraq": "Asia",
            "saudi arabia": "Asia", "uae": "Asia", "united arab emirates": "Asia",
            "israel": "Asia", "turkey": "Asia", "russia": "Asia", "kazakhstan": "Asia",
            "mongolia": "Asia", "nepal": "Asia", "sri lanka": "Asia", "myanmar": "Asia",
            "cambodia": "Asia", "laos": "Asia", "brunei": "Asia", "kyrgyzstan": "Asia",
            "tajikistan": "Asia", "uzbekistan": "Asia", "turkmenistan": "Asia",
            "azerbaijan": "Asia", "georgia": "Asia", "armenia": "Asia", "lebanon": "Asia",
            "jordan": "Asia", "syria": "Asia", "yemen": "Asia", "oman": "Asia",
            "kuwait": "Asia", "qatar": "Asia", "bahrain": "Asia", "cyprus": "Asia",
            
            // Europe
            "united kingdom": "Europe", "uk": "Europe", "great britain": "Europe",
            "france": "Europe", "germany": "Europe", "italy": "Europe", "spain": "Europe",
            "portugal": "Europe", "greece": "Europe", "netherlands": "Europe", "belgium": "Europe",
            "switzerland": "Europe", "austria": "Europe", "poland": "Europe", "czech republic": "Europe",
            "hungary": "Europe", "romania": "Europe", "bulgaria": "Europe", "croatia": "Europe",
            "serbia": "Europe", "slovakia": "Europe", "slovenia": "Europe", "denmark": "Europe",
            "sweden": "Europe", "norway": "Europe", "finland": "Europe", "iceland": "Europe",
            "ireland": "Europe", "luxembourg": "Europe", "malta": "Europe", "estonia": "Europe",
            "latvia": "Europe", "lithuania": "Europe", "albania": "Europe", "macedonia": "Europe",
            "bosnia": "Europe", "montenegro": "Europe", "moldova": "Europe", "ukraine": "Europe",
            "belarus": "Europe", "monaco": "Europe", "liechtenstein": "Europe", "andorra": "Europe",
            "san marino": "Europe", "vatican": "Europe", "vatican city": "Europe",
            
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
    
    static func organizeAssets(assets: [ImmichAsset]) -> [Continent] {
        // Group assets by continent -> country -> city
        var continentMap: [String: [String: [String: [ImmichAsset]]]] = [:]
        
        for asset in assets {
            guard let exifInfo = asset.exifInfo,
                  let country = exifInfo.country,
                  !country.isEmpty else {
                continue
            }
            
            let continent = getContinent(for: country)
            let city = exifInfo.city ?? "Unknown City"
            
            if continentMap[continent] == nil {
                continentMap[continent] = [:]
            }
            if continentMap[continent]![country] == nil {
                continentMap[continent]![country] = [:]
            }
            if continentMap[continent]![country]![city] == nil {
                continentMap[continent]![country]![city] = []
            }
            continentMap[continent]![country]![city]!.append(asset)
        }
        
        // Convert to hierarchical models
        var continents: [Continent] = []
        
        for (continentName, countriesMap) in continentMap.sorted(by: { $0.key < $1.key }) {
            var countries: [Country] = []
            
            for (countryName, citiesMap) in countriesMap.sorted(by: { $0.key < $1.key }) {
                var cities: [City] = []
                
                for (cityName, cityAssets) in citiesMap.sorted(by: { $0.key < $1.key }) {
                    let representativeAsset = cityAssets.first { $0.type == .image } ?? cityAssets.first
                    let city = City(
                        name: cityName,
                        country: countryName,
                        continent: continentName,
                        assets: cityAssets,
                        representativeAsset: representativeAsset
                    )
                    cities.append(city)
                }
                
                let representativeAsset = cities.first?.representativeAsset ?? cities.first?.assets.first { $0.type == .image }
                let country = Country(
                    name: countryName,
                    continent: continentName,
                    cities: cities,
                    representativeAsset: representativeAsset
                )
                countries.append(country)
            }
            
            let representativeAsset = countries.first?.representativeAsset ?? countries.first?.cities.first?.representativeAsset
            let continent = Continent(
                name: continentName,
                countries: countries,
                representativeAsset: representativeAsset
            )
            continents.append(continent)
        }
        
        return continents
    }
}

