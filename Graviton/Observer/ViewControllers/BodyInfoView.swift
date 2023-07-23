//
//  BodyInfoView.swift
//  Graviton
//
//  Created by Yerassyl Abilkassym on 11.07.2023.
//  Copyright © 2023 Ben Lu. All rights reserved.
//

import SwiftUI

struct BodyInfoView: View {
    var target: ObserveTarget
    var ephemerisId: SubscriptionUUID
    @State private var information = ""
    
    var body: some View {
        VStack {
            List {
                ForEach(0..<target.numberOfSections, id: \.self) { section in
                    Section(header: headerView(for: section)) {
                        ForEach(0..<target.numberOfRows(in: section), id: \.self) { row in
                            cellView(for: IndexPath(row: row, section: section))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(BlurView(style: .systemMaterial))
            .onAppear(perform: {
                setUpBlurredBackground()
            })
        }
    }
    
    private func headerView(for section: Int) -> some View {
        let sectionHeader: String
        switch target {
        case .star:
            sectionHeader = ["Position", "Designations", "Physical Properties"][section]
        case .nearbyBody:
            sectionHeader = ["Position", "Physical Properties"][section]
        }
        
        return Text(sectionHeader)
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color(.darkGray))
    }
    
    private func cellView(for indexPath: IndexPath) -> some View {
        let cellText: String
        let detailText: String
        
        switch target {
        case let .star(star):
            switch (indexPath.section, indexPath.row) {
            case (1, _):
                let content = star.identity.contentAtRow(indexPath.row)
                cellText = content.0
                detailText = content.1
            case (0, 4):
                cellText = "Constellation"
                detailText = star.identity.constellation.name
            case (0, 5):
                cellText = "Distance from Sun"
                let formatter = Formatters.scientificNotationFormatter
                var distanceStr = formatter.string(from: star.physicalInfo.distance as NSNumber)!
                if star.physicalInfo.distance >= 10e6 {
                    distanceStr = "> \(distanceStr) pc"
                } else {
                    distanceStr = "\(distanceStr) pc"
                }
                detailText = distanceStr
            case (2, 0):
                cellText = "Visual Magnitude"
                detailText = stringify(star.physicalInfo.apparentMagnitude)
            case (2, 1):
                cellText = "Absolute Magnitude"
                detailText = stringify(star.physicalInfo.absoluteMagnitude)
            case (2, 2):
                cellText = "Spectral Type"
                detailText = stringify(star.physicalInfo.spectralType)
            case (2, 3):
                cellText = "Luminosity (x Sun)"
                detailText = Formatters.scientificNotationFormatter.string(from: star.physicalInfo.luminosity as NSNumber) ?? ""
            default:
                cellText = ""
                detailText = ""
            }
        case let .nearbyBody(nb):
            let celestialBody = nb as! CelestialBody
            let coord = relativeCoordinate(fornearbyBody: nb)
            switch (indexPath.section, indexPath.row) {
            case (0, 4):
                cellText = "Constellation"
                detailText = coord.constellation.name
            case (1, 0):
                cellText = "Mass (kg)"
                detailText = Formatters.scientificNotationFormatter.string(from: celestialBody.mass as NSNumber) ?? ""
            case (1, 1):
                cellText = "Radius (km)"
                detailText = Formatters.scientificNotationFormatter.string(from: celestialBody.radius / 1000 as NSNumber) ?? ""
            case (1, 2):
                cellText = "Rotation Period (h)"
                detailText = Formatters.scientificNotationFormatter.string(from: celestialBody.rotationPeriod / 3600 as NSNumber) ?? ""
            default:
                cellText = ""
                detailText = ""
            }
        }
        
        return HStack {
            Text(cellText)
                .foregroundColor(.white)
            Spacer()
            Text(detailText)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.clear)
    }
    
    private func relativeCoordinate(fornearbyBody body: Body) -> EquatorialCoordinate {
        let ephemeris = EphemerisManager.default.content(for: ephemerisId)!
        let earth = ephemeris[.majorBody(.earth)]!
        return EquatorialCoordinate(cartesian: (body.heliocentricPosition! - earth.heliocentricPosition!).oblique(by: earth.obliquity))
    }
    
    private func setUpBlurredBackground() {
        // Code to set up the blurred background
    }
    
    private func stringify(_ str: CustomStringConvertible?) -> String {
        if let str = str {
            return String(describing: str)
        }
        return ""
    }
}

extension ObserveTarget {
    var numberOfSections: Int {
        switch self {
        case .star:
            return 3
        case .nearbyBody:
            return 2
        }
    }

    func numberOfRows(in section: Int) -> Int {
        switch self {
        case let .star(star):
            switch section {
            case 1: // Identity
                var identityCount = 0
                if star.identity.properName != nil { identityCount += 1 }
                if star.identity.hipId != nil { identityCount += 1 }
                if star.identity.hrId != nil { identityCount += 1 }
                if star.identity.gl != nil { identityCount += 1 }
                if star.identity.rawBfDesignation != nil { identityCount += 1 }
                if star.identity.hdId != nil { identityCount += 1 }
                return identityCount
            case 0: // Position
                return 6
            case 2: // Physical Properties
                return 4
            default:
                return 0
            }
        case .nearbyBody:
            switch section {
            case 0: // Positions
                return 5
            case 1: // Physical Properties
                return 3
            default:
                return 0
            }
        }
    }
}

extension Star.Identity {
    func contentAtRow(_ row: Int) -> (String, String) {
        let titles: [String] = ["Proper Name", "Bayer-Flamsteed", "Gliese catalog", "Harvard Revised", "Henry Draper", "Hipparcos catalog"]
        let properties: [String?] = [properName, bayerFlamsteedDesignation, gl, stringify(hrId), stringify(hdId), stringify(hipId)]
        return (zip(titles, properties)
            .filter { $1 != nil }
            .map { ($0, $1!) })[row]
    }
}
