//
//  DBHelper.swift
//  Orbits
//
//  Created by Sihao Lu on 1/1/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import SQLite
import SpaceTime
import MathUtil

private let celestialBody = Table("celestial_body")
private let cbId = Expression<Int64>("naifId")
private let cusName = Expression<String?>("customName")
private let obliquityExpr = Expression<Double>("obliquity")
private let gmExpr = Expression<Double>("gm")
private let hillSphereExpr = Expression<Double?>("hillSphere")
private let radiusExpr = Expression<Double>("radius")
private let rotationPeriodExpr = Expression<Double>("rotationPeriod")
private let centerBodyId = Expression<Int64?>("centerBodyNaifId")

private let orbitalMotion = Table("orbital_motion")
private let obId = Expression<Int64>("ob_id")
private let bodyId = Expression<Int64>("body_id")
private let systemGm = Expression<Double?>("system_gm")
private let a = Expression<Double>("a")
private let ec = Expression<Double>("ec")
private let i = Expression<Double>("i")
private let om = Expression<Double>("om")
private let w = Expression<Double>("w")
private let tp = Expression<Double>("tp") // time of periapsis passage, only when mode = 2
private let refJd = Expression<Double>("ref_jd") // reference jd, only when mode = 2

class DBHelper {

    static let shared: DBHelper = setupDatabaseHelper()

    class func setupDatabaseHelper() -> DBHelper {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
            ).first!

        let cb = try! Connection("\(path)/celestialBodies.sqlite3")
        let ob = try! Connection("\(path)/motions.sqlite3")
        let helper = DBHelper(celestialBodies: cb, orbitalMotions: ob)
        helper.prepareTables()
        return helper
    }

    init(celestialBodies: Connection, orbitalMotions: Connection) {
        self.celestialBodies = celestialBodies
        self.orbitalMotions = orbitalMotions
        self.backupCb = try! Connection(Bundle(for: DBHelper.self).path(forResource: "celestialBodies", ofType: "sqlite3")!)
        self.backupOb = try! Connection(Bundle(for: DBHelper.self).path(forResource: "motions", ofType: "sqlite3")!)
    }

    let celestialBodies: Connection
    let orbitalMotions: Connection
    let backupCb: Connection
    let backupOb: Connection

    // EC     Eccentricity, e
    // IN     Inclination w.r.t XY-plane, i (degrees)
    // OM     Longitude of Ascending Node, OMEGA, (degrees)
    // W      Argument of Perifocus, w (degrees)
    // Tp     Time of periapsis (Julian Day Number)
    // MA     Mean anomaly, M (degrees)
    // A      Semi-major axis, a (km)

    func prepareTables() {
        try! orbitalMotions.run(orbitalMotion.create(ifNotExists: true) { t in
            t.column(obId, primaryKey: .autoincrement)
            t.column(bodyId)
            t.column(systemGm)
            t.column(a)
            t.column(ec)
            t.column(i)
            t.column(om)
            t.column(w)
            t.column(tp)
            t.column(refJd)
            t.unique(bodyId, refJd)
        })

        try! celestialBodies.run(celestialBody.create(ifNotExists: true) { t in
            t.column(cbId, primaryKey: true)
            t.column(obliquityExpr)
            t.column(gmExpr)
            t.column(hillSphereExpr)
            t.column(radiusExpr)
            t.column(centerBodyId)
            t.column(rotationPeriodExpr)
            t.column(cusName)
        })
    }

    func saveCelestialBody(_ body: CelestialBody, shouldSaveMotion: Bool) {
        let setters: [Setter] = [cbId <- Int64(body.naifId), gmExpr <- body.gravParam, obliquityExpr <- RadianAngle(degreeAngle: body.obliquity).wrappedValue, radiusExpr <- body.radius, hillSphereExpr <- body.hillSphere, rotationPeriodExpr <- body.rotationPeriod, centerBodyId <- wrapInt(body.centerBody?.naifId)]
        var nameSetter: [Setter] = []
        if NaifCatalog.name(forNaif: body.naifId) == nil {
            nameSetter = [cusName <- body.name]
        }
        try! celestialBodies.run(celestialBody.insert(or: .replace, setters + nameSetter))
        if let obm = body.motion as? OrbitalMotionMoment, shouldSaveMotion {
            obm.save(forBodyId: body.naifId)
        }
    }

    func loadCelestialBody(withNaifId naifId: Int, shouldLoadMotion: Bool = true) -> CelestialBody? {
        if naifId == Sun.sol.naifId {
            return Sun.sol
        }
        func constructResult(_ result: Row) -> CelestialBody {
            if let customName = try! result.get(cusName) {
                return CelestialBody(naifId: Int(try! result.get(cbId)), name: customName, gravParam: try! result.get(gmExpr), radius: try! result.get(radiusExpr), rotationPeriod: try! result.get(rotationPeriodExpr), obliquity: DegreeAngle(radianAngle: RadianAngle(try! result.get(obliquityExpr))), centerBodyNaifId: unwrapInt64(try! result.get(centerBodyId)), hillSphereRadRp: try! result.get(hillSphereExpr))
            }
            let cb = CelestialBody(naifId: Int(try! result.get(cbId)), gravParam: try! result.get(gmExpr), radius: try! result.get(radiusExpr), rotationPeriod: try! result.get(rotationPeriodExpr), obliquity: DegreeAngle(radianAngle: RadianAngle(try! result.get(obliquityExpr))), centerBodyNaifId: unwrapInt64(try! result.get(centerBodyId)), hillSphereRadRp: try! result.get(hillSphereExpr))
            if shouldLoadMotion {
                cb.motion = self.loadOrbitalMotionMoment(bodyId: naifId, optimalJulianDay: JulianDay.now)
            }
            return cb
        }
        let query = celestialBody.filter(cbId == Int64(naifId))
        if let result = try! celestialBodies.pluck(query) {
            return constructResult(result)
        } else if let result = try! backupCb.pluck(query) {
            return constructResult(result)
        } else {
            return nil
        }
    }

    func saveOrbitalMotionMoment(_ moment: OrbitalMotionMoment, forBodyId bid: Int) {
        let db: Connection = self.orbitalMotions
        let identitySetter: [Setter] = [bodyId <- Int64(bid), systemGm <- moment.gm, tp <- moment.timeOfPeriapsisPassage!.value, refJd <- moment.ephemerisJulianDay.value]
        try! db.run(orbitalMotion.insert(or: .replace, identitySetter + moment.orbit.sqlSaveSetters))
    }

    func loadOrbitalMotionMoment(bodyId theBodyId: Int, optimalJulianDay julianDay: JulianDay = JulianDay.now) -> OrbitalMotionMoment? {
        let db: Connection = self.orbitalMotions
        func loadFromRow(_ row: Row) -> OrbitalMotionMoment {
            // km^3/s^2 to m^3/s^2
            let realSystemGm = try! row.get(systemGm) != nil ? try! row.get(systemGm)! : Sun.sol.gravParam
            let (va, vi, vec, vom, vw, vgm) = (try! row.get(a), try! row.get(i), try! row.get(ec), try! row.get(om), try! row.get(w), realSystemGm)
            let orbit = Orbit(semimajorAxis: va, eccentricity: vec, inclination: vi, longitudeOfAscendingNode: vom, argumentOfPeriapsis: vw)
            let bestRefJd = try! row.get(refJd)
            let vtp = try! row.get(tp)
            return OrbitalMotionMoment(orbit: orbit, gm: vgm, julianDay: JulianDay(bestRefJd), timeOfPeriapsisPassage: JulianDay(vtp))
        }
        func pluck(on database: Connection) -> Row? {
            let preQuery = orbitalMotion.filter(bodyId == Int64(theBodyId))
            let query = orbitalMotion.select((refJd - julianDay.value).absoluteValue.min, a, i, ec, om, w, systemGm, refJd, tp).filter(bodyId == Int64(theBodyId))
            guard try! database.pluck(preQuery) != nil else { return nil }
            return try! database.pluck(query)
        }
        if let row = pluck(on: db) {
            if let backupRow = pluck(on: backupOb) {
                let r1 = loadFromRow(row)
                let r2 = loadFromRow(backupRow)
                func diff(_ ob: OrbitalMotionMoment) -> Double {
                    return abs(ob.ephemerisJulianDay - julianDay)
                }
                return diff(r1) > diff(r2) ? r2 : r1
            } else {
                return loadFromRow(row)
            }
        } else if let backupRow = pluck(on: backupOb) {
            return loadFromRow(backupRow)
        }
        return nil
    }
}

private func unwrapInt64(_ v: Int64?) -> Int? {
    if v == nil { return nil }
    return Int(v!)
}

private func wrapInt(_ v: Int?) -> Int64? {
    if v == nil { return nil }
    return Int64(v!)
}

extension CelestialBody {

    /// Save physical properties of the celestial body
    public func save(shouldSaveMotion: Bool = true) {
        DBHelper.shared.saveCelestialBody(self, shouldSaveMotion: shouldSaveMotion)
    }

    public class func load(naifId: Int) -> CelestialBody? {
        return DBHelper.shared.loadCelestialBody(withNaifId: naifId)
    }
}

extension OrbitalMotionMoment {
    public func save(forBodyId theBodyId: Int) {
        DBHelper.shared.saveOrbitalMotionMoment(self, forBodyId: theBodyId)
    }

    public class func load(bodyId: Int) -> OrbitalMotionMoment? {
        return DBHelper.shared.loadOrbitalMotionMoment(bodyId: bodyId)
    }
}

private extension Orbit {
    var sqlSaveSetters: [Setter] {
        return [a <- shape.semimajorAxis, ec <- shape.eccentricity, w <- orientation.argumentOfPeriapsis, i <- orientation.inclination, om <- orientation.longitudeOfAscendingNode]
    }
}

extension Connection {
    public var userVersion: Int32 {
        get { return Int32(try! scalar("PRAGMA user_version") as! Int64)}
        set { try! run("PRAGMA user_version = \(newValue)") }
    }
}
