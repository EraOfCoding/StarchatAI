//
//  BodyInfoViewController.swift
//  Graviton
//
//  Created by Sihao Lu on 7/7/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import MathUtil
import Orbits
import SpaceTime
import StarryNight
import UIKit
import XLPagerTabStrip

class BodyInfoViewController: UITableViewController {
    var target: ObserveTarget!
    var ephemerisId: SubscriptionUUID!
    private var information = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "infoCell")
        tableView.tableFooterView = UIView()
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        tableView.separatorColor = Constants.Menu.separatorColor
        tableView.backgroundColor = UIColor.clear
        setUpBlurredBackground()
        
    }

    private func rowForPositionSection(_ row: Int) -> Int {
        if case .nearbyBody = target! {
            return row
        }
        if row < 2 {
            return row
        }
        return row - (ObserverLocationTimeManager.default.observerInfo == nil ? 2 : 0)
    }

    private func relativeCoordinate(fornearbyBody body: Body) -> EquatorialCoordinate {
        let ephemeris = EphemerisManager.default.content(for: ephemerisId)!
        let earth = ephemeris[.majorBody(.earth)]!
        return EquatorialCoordinate(cartesian: (body.heliocentricPosition! - earth.heliocentricPosition!).oblique(by: earth.obliquity))
    }

    // MARK: - Table view data source

    override func numberOfSections(in _: UITableView) -> Int {
        return target.numberOfSections
    }

    override func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "infoCell")
        
        let sectionHeader: String
        switch target! {
        case .star:
            sectionHeader = ["Position", "Designations", "Physical Properties"][section]
        case .nearbyBody:
            sectionHeader = ["Position", "Physical Properties"][section]
        }
        let header = HeaderView()
        header.backgroundColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        header.textLabel.textColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
        header.textLabel.text = sectionHeader
        if let text = cell.textLabel?.text, let detailText = cell.detailTextLabel?.text {
            information += "\(text): \(detailText)\n"
        }
        
        return header
    }

    override func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        return 24
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return target.numberOfRows(in: section)
    }

    override func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt _: IndexPath) {
        cell.backgroundColor = UIColor.clear
        cell.textLabel?.textColor = #colorLiteral(red: 0.9803921569, green: 0.9803921569, blue: 0.9803921569, alpha: 1)
        cell.detailTextLabel?.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
        cell.selectionStyle = .none
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "infoCell")
        configureSharedPosition(forCell: cell, atIndexPath: indexPath)
        switch target! {
        case let .star(star):
            switch (indexPath.section, indexPath.row) {
            case (1, _):
                cell.textLabel?.text = star.identity.contentAtRow(indexPath.row).0
                cell.detailTextLabel?.text = star.identity.contentAtRow(indexPath.row).1
            case (0, rowForPositionSection(4)):
                cell.textLabel?.text = "Constellation"
                cell.detailTextLabel?.text = star.identity.constellation.name
            case (0, rowForPositionSection(5)):
                cell.textLabel?.text = "Distance from Sun"
                let formatter = Formatters.scientificNotationFormatter
                var distanceStr = formatter.string(from: star.physicalInfo.distance as NSNumber)!
                if star.physicalInfo.distance >= 10e6 {
                    distanceStr = "> \(distanceStr) pc"
                } else {
                    distanceStr = "\(distanceStr) pc"
                }
                cell.detailTextLabel?.text = distanceStr
            case (2, 0):
                cell.textLabel?.text = "Visual Magnitude"
                cell.detailTextLabel?.text = stringify(star.physicalInfo.apparentMagnitude)
            case (2, 1):
                cell.textLabel?.text = "Absolute Magnitude"
                cell.detailTextLabel?.text = stringify(star.physicalInfo.absoluteMagnitude)
            case (2, 2):
                cell.textLabel?.text = "Spectral Type"
                cell.detailTextLabel?.text = stringify(star.physicalInfo.spectralType)
            case (2, 3):
                cell.textLabel?.text = "Luminosity (x Sun)"
                cell.detailTextLabel?.text = Formatters.scientificNotationFormatter.string(from: star.physicalInfo.luminosity as NSNumber)
            default:
                break
            }
        case let .nearbyBody(nb):
            let celestialBody = nb as! CelestialBody
            let coord = relativeCoordinate(fornearbyBody: nb)
            switch (indexPath.section, indexPath.row) {
            case (0, rowForPositionSection(4)):
                cell.textLabel?.text = "Constellation"
                cell.detailTextLabel?.text = coord.constellation.name
            case (1, 0):
                cell.textLabel?.text = "Mass (kg)"
                cell.detailTextLabel?.text = Formatters.scientificNotationFormatter.string(from: celestialBody.mass as NSNumber)
            case (1, 1):
                cell.textLabel?.text = "Radius (km)"
                cell.detailTextLabel?.text = Formatters.scientificNotationFormatter.string(from: celestialBody.radius / 1000 as NSNumber)
            case (1, 2):
                cell.textLabel?.text = "Rotation Period (h)"
                cell.detailTextLabel?.text = Formatters.scientificNotationFormatter.string(from: celestialBody.rotationPeriod / 3600 as NSNumber)
            default:
                break
            }
        }
        return cell
    }

    private func configureSharedPosition(forCell cell: UITableViewCell, atIndexPath indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        let coord: EquatorialCoordinate
        switch target! {
        case let .star(star):
            coord = EquatorialCoordinate(cartesian: star.physicalInfo.coordinate)
        case let .nearbyBody(nb):
            coord = relativeCoordinate(fornearbyBody: nb)
        }
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            cell.textLabel?.text = "Right Ascension"
            coord.rightAscension.compoundDecimalNumberFormatter = Formatters.integerFormatter
            cell.detailTextLabel?.text = coord.rightAscension.compoundDescription
        case (0, 1):
            cell.textLabel?.text = "Declination"
            coord.declination.compoundDecimalNumberFormatter = Formatters.integerFormatter
            cell.detailTextLabel?.text = coord.declination.compoundDescription
        case (0, rowForPositionSection(2)):
            cell.textLabel?.text = "Azimuth"
            let hori = HorizontalCoordinate(equatorialCoordinate: coord, observerInfo: ObserverLocationTimeManager.default.observerInfo!)
            hori.azimuth.compoundDecimalNumberFormatter = Formatters.integerFormatter
            cell.detailTextLabel?.text = hori.azimuth.compoundDescription
        case (0, rowForPositionSection(3)):
            cell.textLabel?.text = "Altitude"
            let hori = HorizontalCoordinate(equatorialCoordinate: coord, observerInfo: ObserverLocationTimeManager.default.observerInfo!)
            hori.altitude.compoundDecimalNumberFormatter = Formatters.integerFormatter
            cell.detailTextLabel?.text = hori.altitude.compoundDescription
        default:
            break
        }
    }
}

// MARK: - Info provider

extension BodyInfoViewController: IndicatorInfoProvider {
    func indicatorInfo(for _: PagerTabStripViewController) -> IndicatorInfo {
        switch target! {
        case .star:
            return "Star Info"
        case .nearbyBody:
            return "Body Info"
        }
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

private func stringify(_ str: CustomStringConvertible?) -> String? {
    if str == nil { return nil }
    return String(describing: str!)
}
