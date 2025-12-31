//
//  MapModels.swift
//  Immich Gallery
//
//  Models for map view data
//

import Foundation
import MapKit

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
}

/// Helper to cluster nearby photos together
struct MapClusterer {
    /// Clusters photos by location, grouping nearby photos together
    /// - Parameter assets: Array of assets with location data
    /// - Parameter clusterRadius: Radius in meters for clustering (default: 50000 = 50km)
    /// - Returns: Array of PhotoCluster objects
    static func clusterPhotos(_ assets: [ImmichAsset], clusterRadius: Double = 50000) -> [PhotoCluster] {
        guard !assets.isEmpty else { return [] }
        
        var clusters: [PhotoCluster] = []
        var processedAssets: Set<String> = []
        
        for asset in assets {
            // Skip if already processed
            if processedAssets.contains(asset.id) {
                continue
            }
            
            guard let exifInfo = asset.exifInfo,
                  let latitude = exifInfo.latitude,
                  let longitude = exifInfo.longitude else {
                continue
            }
            
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let location = CLLocation(latitude: latitude, longitude: longitude)
            
            // Find all nearby assets within cluster radius
            var nearbyAssets: [ImmichAsset] = [asset]
            processedAssets.insert(asset.id)
            
            for otherAsset in assets {
                if processedAssets.contains(otherAsset.id) {
                    continue
                }
                
                guard let otherExifInfo = otherAsset.exifInfo,
                      let otherLatitude = otherExifInfo.latitude,
                      let otherLongitude = otherExifInfo.longitude else {
                    continue
                }
                
                let otherLocation = CLLocation(latitude: otherLatitude, longitude: otherLongitude)
                let distance = location.distance(from: otherLocation)
                
                if distance <= clusterRadius {
                    nearbyAssets.append(otherAsset)
                    processedAssets.insert(otherAsset.id)
                }
            }
            
            // Calculate center coordinate of cluster
            let avgLatitude = nearbyAssets.compactMap { $0.exifInfo?.latitude }.reduce(0, +) / Double(nearbyAssets.count)
            let avgLongitude = nearbyAssets.compactMap { $0.exifInfo?.longitude }.reduce(0, +) / Double(nearbyAssets.count)
            let clusterCoordinate = CLLocationCoordinate2D(latitude: avgLatitude, longitude: avgLongitude)
            
            let cluster = PhotoCluster(coordinate: clusterCoordinate, assets: nearbyAssets)
            clusters.append(cluster)
        }
        
        return clusters
    }
}

