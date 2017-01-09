//
//  CoordinateTest.swift
//  Graviton
//
//  Created by Sihao Lu on 1/6/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import XCTest
@testable import SpaceTime
import CoreLocation

class CoordinateTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testNearEpochSphericalToCylindricalConversion() {
        let sph = SphericalCoordinate(
            rightAscension: radians(hours: 11, minutes: 3, seconds: 43),
            declination: radians(degrees: 61, minutes: 45, seconds: 3.72),
            distance: 1)
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(calendar: calendar, timeZone: TimeZone(abbreviation: "PST"), year: 2000, month: 1, day: 1, hour: 5)
        let date = calendar.date(from: components)!
        let obs = ObserverInfo(location: CLLocationCoordinate2DMake(CLLocationDegrees(degrees(degrees: 37, minutes: 46, seconds: 51)), CLLocationDegrees(-degrees(degrees: 122, minutes: 24, seconds: 47))), time: date)
        let cyl = CylindricalCoordinate(sphericalCoordinate: sph, observerInfo: obs)
        XCTAssertEqualWithAccuracy(cyl.azimuth, radians(degrees: 351, minutes: 45, seconds: 21.84), accuracy: 1e-3)
        XCTAssertEqualWithAccuracy(cyl.altitude, radians(degrees: 65, minutes: 37, seconds: 8.28), accuracy: 1e-3)

    }
    
    func testSphericalToCylindricalConversion() {
        // at 2017.1.6, 1:31 AM PT
        // Dubhe is at RA 11h 03m 43s, DEC +61° 45' 3.72''
        // Azm +32° 41' 21.16'', Alt 55° 55' 30.18''
        // Current location 37° 46' 51'' N, 122° 24' 47'' W
        let sph = SphericalCoordinate(
            rightAscension: radians(hours: 11, minutes: 3, seconds: 43),
            declination: radians(degrees: 61, minutes: 45, seconds: 3.72),
            distance: 1)
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(calendar: calendar, timeZone: TimeZone(abbreviation: "PST"), year: 2017, month: 1, day: 6, hour: 1, minute: 31, second: 30)
        let date = calendar.date(from: components)!
        let obs = ObserverInfo(location:
            CLLocationCoordinate2DMake(
                CLLocationDegrees(degrees(degrees: 37, minutes: 46, seconds: 51)),
                CLLocationDegrees(-degrees(degrees: 122, minutes: 24, seconds: 47))
            ),
            time: date
        )
        let cyl = CylindricalCoordinate(sphericalCoordinate: sph, observerInfo: obs)
        XCTAssertEqualWithAccuracy(cyl.azimuth, radians(degrees: 32, minutes: 41, seconds: 21.16), accuracy: 5e-3)
        XCTAssertEqualWithAccuracy(cyl.altitude, radians(degrees: 55, minutes: 55, seconds: 30.18), accuracy: 5e-3)
    }
    
    func testSouthernSphericalToCylindricalConversion() {
        // Sirius
        let sph = SphericalCoordinate(
            rightAscension: radians(hours: 6, minutes: 45, seconds: 8),
            declination: -radians(degrees: 16, minutes: 42, seconds: 58.02),
            distance: 1)
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(calendar: calendar, timeZone: TimeZone(abbreviation: "PST"), year: 2017, month: 1, day: 6, hour: 2, minute: 27)
        let date = calendar.date(from: components)!
        let obs = ObserverInfo(location:
            CLLocationCoordinate2DMake(
                CLLocationDegrees(-33.9249),
                CLLocationDegrees(18.4241)
            ),
                               time: date
        )
        let cyl = CylindricalCoordinate(sphericalCoordinate: sph, observerInfo: obs)
        XCTAssertEqualWithAccuracy(cyl.azimuth, radians(degrees: 180, minutes: 3, seconds: 48.13), accuracy: 5e-3)
        XCTAssertEqualWithAccuracy(cyl.altitude, -radians(degrees: 39, minutes: 20, seconds: 54.56), accuracy: 5e-3)
    }
    
}