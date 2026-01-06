import Foundation
import MapKit

// MARK: - Map Marker (Lightweight location data from API)

/// Lightweight map marker returned from the map markers API
/// Contains only location data without full asset details
struct MapMarker: Codable, Identifiable {
    let id: String
    let lat: Double
    let lon: Double
    let city: String?
    let state: String?
    let country: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

/// Response from the map markers API
struct MapMarkersResponse: Codable {
    let markers: [MapMarker]?
    
    // Handle both array response and object with markers property
    init(from decoder: Decoder) throws {
        // First try to decode as array (direct response)
        if let markers = try? [MapMarker](from: decoder) {
            self.markers = markers
            return
        }
        // Then try as object with markers property
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.markers = try container.decodeIfPresent([MapMarker].self, forKey: .markers)
    }
    
    private enum CodingKeys: String, CodingKey {
        case markers
    }
}

// MARK: - Lightweight Cluster (for initial fast loading)

/// Lightweight cluster containing only coordinate and count information
/// Used for fast initial map rendering without loading full asset data
struct LightweightCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let photoCount: Int
    let markerIds: [String]  // IDs of markers in this cluster for later detail fetching
    let representativeMarkerId: String?
    let city: String?
    let state: String?
    let country: String?
    
    init(coordinate: CLLocationCoordinate2D, markers: [MapMarker]) {
        self.id = "\(coordinate.latitude),\(coordinate.longitude)"
        self.coordinate = coordinate
        self.photoCount = markers.count
        self.markerIds = markers.map { $0.id }
        self.representativeMarkerId = markers.first?.id
        // Use location info from first marker
        self.city = markers.first?.city
        self.state = markers.first?.state
        self.country = markers.first?.country
    }
}

// MARK: - Photo Cluster (Full data for detailed view)

/// Represents a cluster of photos at a specific location
struct PhotoCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let photoCount: Int
    let representativeAsset: ImmichAsset?
    let assets: [ImmichAsset]
    
    init(coordinate: CLLocationCoordinate2D, assets: [ImmichAsset]) {
        self.id = "\(coordinate.latitude),\(coordinate.longitude)"
        self.coordinate = coordinate
        self.photoCount = assets.count
        self.assets = assets
        // Use the most recent asset as representative
        self.representativeAsset = assets.sorted { asset1, asset2 in
            let date1 = asset1.fileCreatedAt
            let date2 = asset2.fileCreatedAt
            return date1 > date2
        }.first
    }
    
    /// Create from lightweight cluster with loaded assets
    init(from lightweight: LightweightCluster, assets: [ImmichAsset]) {
        self.id = lightweight.id
        self.coordinate = lightweight.coordinate
        self.photoCount = assets.isEmpty ? lightweight.photoCount : assets.count
        self.assets = assets
        self.representativeAsset = assets.sorted { asset1, asset2 in
            let date1 = asset1.fileCreatedAt
            let date2 = asset2.fileCreatedAt
            return date1 > date2
        }.first
    }
}

// MARK: - Spatial Tile for Efficient Region Queries

/// Represents a spatial tile for efficient region-based queries
/// Uses a simple grid-based spatial indexing system
struct SpatialTile: Hashable {
    let latIndex: Int
    let lonIndex: Int
    
    /// Tile size in degrees (approximately 100km at equator)
    static let tileSize: Double = 1.0  // 1 degree ≈ 111km
    
    static func tileFor(coordinate: CLLocationCoordinate2D) -> SpatialTile {
        let latIndex = Int(floor(coordinate.latitude / tileSize))
        let lonIndex = Int(floor(coordinate.longitude / tileSize))
        return SpatialTile(latIndex: latIndex, lonIndex: lonIndex)
    }
    
    static func tilesInRegion(center: CLLocationCoordinate2D, span: MKCoordinateSpan) -> Set<SpatialTile> {
        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLon = center.longitude - span.longitudeDelta / 2
        let maxLon = center.longitude + span.longitudeDelta / 2
        
        let minLatIndex = Int(floor(minLat / tileSize))
        let maxLatIndex = Int(floor(maxLat / tileSize))
        let minLonIndex = Int(floor(minLon / tileSize))
        let maxLonIndex = Int(floor(maxLon / tileSize))
        
        var tiles = Set<SpatialTile>()
        for lat in minLatIndex...maxLatIndex {
            for lon in minLonIndex...maxLonIndex {
                tiles.insert(SpatialTile(latIndex: lat, lonIndex: lon))
            }
        }
        return tiles
    }
}

// MARK: - Spatial Index for Fast Lookups

/// Spatial index for efficient marker lookups by region
class SpatialMarkerIndex {
    private var tileToMarkers: [SpatialTile: [MapMarker]] = [:]
    private var allMarkers: [MapMarker] = []
    
    var isEmpty: Bool { allMarkers.isEmpty }
    var count: Int { allMarkers.count }
    
    func clear() {
        allMarkers.removeAll()
        tileToMarkers.removeAll()
    }
    
    func index(markers: [MapMarker]) {
        allMarkers = markers
        tileToMarkers.removeAll()
        
        for marker in markers {
            let tile = SpatialTile.tileFor(coordinate: marker.coordinate)
            tileToMarkers[tile, default: []].append(marker)
        }
    }
    
    /// Get all markers (for overview mode)
    func getAllMarkers() -> [MapMarker] {
        return allMarkers
    }
    
    /// Get markers in a specific region
    func markers(in region: MKCoordinateRegion) -> [MapMarker] {
        let tiles = SpatialTile.tilesInRegion(center: region.center, span: region.span)
        var result: [MapMarker] = []
        
        for tile in tiles {
            if let tileMarkers = tileToMarkers[tile] {
                result.append(contentsOf: tileMarkers)
            }
        }
        
        // Filter to exact bounds
        let bounds = calculateBounds(for: region)
        return result.filter { marker in
            isCoordinateInBounds(marker.coordinate, bounds: bounds)
        }
    }
    
    private func calculateBounds(for region: MKCoordinateRegion) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let center = region.center
        let span = region.span
        return (
            center.latitude - span.latitudeDelta / 2,
            center.latitude + span.latitudeDelta / 2,
            center.longitude - span.longitudeDelta / 2,
            center.longitude + span.longitudeDelta / 2
        )
    }
    
    private func isCoordinateInBounds(_ coordinate: CLLocationCoordinate2D, bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)) -> Bool {
        coordinate.latitude >= bounds.minLat &&
        coordinate.latitude <= bounds.maxLat &&
        coordinate.longitude >= bounds.minLon &&
        coordinate.longitude <= bounds.maxLon
    }
}

// MARK: - Optimized Map Clusterer

/// Helper to cluster nearby photos together with optimized algorithms
struct MapClusterer {
    
    /// Minimum cluster radius in meters (100km as per requirement)
    static let minimumClusterRadius: Double = 100_000
    
    /// Clusters markers by location using grid-based clustering (O(n) complexity)
    /// - Parameter markers: Array of map markers
    /// - Parameter clusterRadius: Radius in meters for clustering
    /// - Returns: Array of LightweightCluster objects
    static func clusterMarkers(_ markers: [MapMarker], clusterRadius: Double = 100_000) -> [LightweightCluster] {
        guard !markers.isEmpty else { return [] }
        
        // Use grid-based clustering for O(n) performance
        // Convert radius to approximate degrees (1 degree ≈ 111km at equator)
        let gridSize = clusterRadius / 111_000.0
        
        // Group markers by grid cell
        var gridCells: [String: [MapMarker]] = [:]
        
        for marker in markers {
            let cellX = Int(floor(marker.lon / gridSize))
            let cellY = Int(floor(marker.lat / gridSize))
            let cellKey = "\(cellX),\(cellY)"
            gridCells[cellKey, default: []].append(marker)
        }
        
        // Create clusters from grid cells
        var clusters: [LightweightCluster] = []
        
        for (_, cellMarkers) in gridCells {
            // Calculate center coordinate of cluster
            let avgLatitude = cellMarkers.map { $0.lat }.reduce(0, +) / Double(cellMarkers.count)
            let avgLongitude = cellMarkers.map { $0.lon }.reduce(0, +) / Double(cellMarkers.count)
            let clusterCoordinate = CLLocationCoordinate2D(latitude: avgLatitude, longitude: avgLongitude)
            
            let cluster = LightweightCluster(coordinate: clusterCoordinate, markers: cellMarkers)
            clusters.append(cluster)
        }
        
        return clusters
    }
    
    /// Clusters photos by location, grouping nearby photos together
    /// - Parameter assets: Array of assets with location data
    /// - Parameter clusterRadius: Radius in meters for clustering (default: 50000 = 50km)
    /// - Returns: Array of PhotoCluster objects
    static func clusterPhotos(_ assets: [ImmichAsset], clusterRadius: Double = 50000) -> [PhotoCluster] {
        guard !assets.isEmpty else { return [] }
        
        // Use grid-based clustering for O(n) performance
        let gridSize = clusterRadius / 111_000.0
        
        // Group assets by grid cell
        var gridCells: [String: [ImmichAsset]] = [:]
        
        for asset in assets {
            guard let exifInfo = asset.exifInfo,
                  let latitude = exifInfo.latitude,
                  let longitude = exifInfo.longitude else {
                continue
            }
            
            let cellX = Int(floor(longitude / gridSize))
            let cellY = Int(floor(latitude / gridSize))
            let cellKey = "\(cellX),\(cellY)"
            gridCells[cellKey, default: []].append(asset)
        }
        
        // Create clusters from grid cells
        var clusters: [PhotoCluster] = []
        
        for (_, cellAssets) in gridCells {
            let avgLatitude = cellAssets.compactMap { $0.exifInfo?.latitude }.reduce(0, +) / Double(cellAssets.count)
            let avgLongitude = cellAssets.compactMap { $0.exifInfo?.longitude }.reduce(0, +) / Double(cellAssets.count)
            let clusterCoordinate = CLLocationCoordinate2D(latitude: avgLatitude, longitude: avgLongitude)
            
            let cluster = PhotoCluster(coordinate: clusterCoordinate, assets: cellAssets)
            clusters.append(cluster)
        }
        
        return clusters
    }
    
    /// Calculates optimal cluster radius based on zoom level
    /// Ensures minimum 100km radius for overview, smaller for zoomed views
    static func calculateClusterRadius(for span: MKCoordinateSpan) -> Double {
        let avgSpan = (span.latitudeDelta + span.longitudeDelta) / 2
        
        // Cluster radius proportional to view span, with minimum of 100km
        if avgSpan >= 50.0 {
            // Overview mode - use large clusters (100km+)
            return max(minimumClusterRadius, 200_000)
        } else if avgSpan >= 20.0 {
            // Continental view - use 100km clusters
            return minimumClusterRadius
        } else if avgSpan >= 5.0 {
            // Country view - use 50km clusters
            return 50_000
        } else if avgSpan >= 1.0 {
            // Regional view - use 20km clusters
            return 20_000
        } else {
            // City view - use 5km clusters
            return 5_000
        }
    }
}

