//
//  ObserverViewController.swift
//  Graviton
//
//  Created by Sihao Lu on 1/7/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//


import CoreImage
import CoreMedia
import MathUtil
import Orbits
import SceneKit
import SpaceTime
import SpriteKit
import StarryNight
import UIKit

var ephemerisSubscriptionIdentifier: SubscriptionUUID!

class ObserverViewController: SceneController {
    private lazy var overlayScene: ObserverOverlayScene = ObserverOverlayScene(size: self.view.bounds.size)
    private lazy var observerScene = ObserverScene()
    private var observerSubscriptionIdentifier: SubscriptionUUID!
    private var locationSubscriptionIdentifier: SubscriptionUUID!
    private var motionSubscriptionIdentifier: SubscriptionUUID!
    private var timeWarpSpeed: Double?

    private lazy var titleButton: UIButton = {
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 300, height: 44)
        button.setTitleColor(UIColor.white, for: .normal)
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.font = TextStyle.Font.monoLabelFont(size: 16)
//        button.addTarget(self, action: #selector(toggleTimeWarp(sender:)), for: .touchUpInside)
        return button
    }()

    private lazy var titleBlurView: UIVisualEffectView = {
        var blurEffectView = UIVisualEffectView()
        blurEffectView.frame = CGRect(x: 0, y: 0, width: 200, height: self.navigationController!.navigationBar.frame.height - 16)
        blurEffectView.clipsToBounds = true
        blurEffectView.layer.cornerRadius = (self.navigationController!.navigationBar.frame.height - 16) / 2
        blurEffectView.layer.borderWidth = 1
        blurEffectView.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        blurEffectView.contentView.frame = blurEffectView.bounds
        blurEffectView.contentView.addSubview(self.titleButton)
        self.titleButton.center = blurEffectView.center
        return blurEffectView
    }()

    lazy var titleOverlayView: ObserverTitleOverlayView = {
        let overlay = ObserverTitleOverlayView(frame: CGRect.zero)
        overlay.delegate = self
        return overlay
    }()

    private var scnView: SCNView {
        return view as! SCNView
    }

    var target: ObserveTarget? {
        didSet {
            if let target = self.target {
                showTitleOverlay(target: target)
                focusAtTarget()
            } else {
                observerScene.removeFocus()
                hideTitleOverlay()
            }
        }
    }

    var observerCameraController: ObserverCameraController {
        return cameraController as! ObserverCameraController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewElements()
        ephemerisSubscriptionIdentifier = EphemerisManager.default.subscribe(mode: .interval(10), didLoad: observerScene.ephemerisDidLoad(ephemeris:), didUpdate: ephemerisDidUpdate(ephemeris:))
        observerSubscriptionIdentifier = CelestialBodyObserverInfoManager.default.subscribe(didLoad: observerScene.observerInfoUpdate(observerInfo:))
        locationSubscriptionIdentifier = LocationManager.default.subscribe(didUpdate: observerScene.updateLocation(location:))
        motionSubscriptionIdentifier = MotionManager.default.subscribe(didUpdate: observerCameraController.deviceMotionDidUpdate(motion:))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTimeLabel()
        updateAntialiasingMode(Settings.default[.antialiasingMode])
        Settings.default.subscribe(setting: .antialiasingMode, object: self) { [weak self] _, newKey in
            self?.updateAntialiasingMode(newKey)
        }
        
        self.navigationController?.tabBarController?.tabBar.isHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        stopTimeWarp(withAnimationDuration: 0)
        observerScene.removeFocus()
        hideTitleOverlay()
        target = nil
        Timekeeper.default.isWarpActive = false
        super.viewWillDisappear(animated)
    }

    deinit {
        EphemerisManager.default.unsubscribe(ephemerisSubscriptionIdentifier)
        CelestialBodyObserverInfoManager.default.unsubscribe(observerSubscriptionIdentifier)
        MotionManager.default.unsubscribe(motionSubscriptionIdentifier)
        Settings.default.unsubscribe(object: self)
    }

    override var prefersStatusBarHidden: Bool {
        false
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override func loadCameraController() {
        cameraController = ObserverCameraController()
        cameraController?.viewSlideVelocityCap = 500
        cameraController?.cameraNode = observerScene.cameraNode
        cameraController?.cameraInversion = .invertAll
        configurePanSpeed()
    }

    private func setupViewElements() {
        navigationController?.navigationBar.tintColor = Constants.Menu.tintColor
        let gyroItem = UIBarButtonItem(image: #imageLiteral(resourceName: "row_icon_stabilize"), style: .plain, target: self, action: #selector(gyroButtonTapped(sender:)))
        navigationItem.leftBarButtonItem = gyroItem
        navigationItem.titleView = titleBlurView
//        let settingItem = UIBarButtonItem(image: #imageLiteral(resourceName: "menu_icon_settings"), style: .plain, target: self, action: #selector(menuButtonTapped(sender:)))
        let searchItem = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(searchButtonTapped(sender:)))
        navigationItem.rightBarButtonItems = [searchItem]

        titleOverlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleOverlayView)
        view.addConstraints(
            [
                titleOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                titleOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                titleOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ]
        )
        hideTitleOverlay()

        scnView.delegate = self
        scnView.antialiasingMode = .none
        scnView.scene = observerScene
        scnView.pointOfView = observerScene.cameraNode
        scnView.overlaySKScene = overlayScene
        scnView.backgroundColor = UIColor.black
        scnView.isPlaying = true
        scnView.autoenablesDefaultLighting = false

        cameraModifier = observerScene
        view.removeGestureRecognizer(doubleTap)
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(sender:)))
        view.addGestureRecognizer(tapGR)

        let displaylink = CADisplayLink(target: self, selector: #selector(updateTimestampLabel))
        displaylink.add(to: .current, forMode: .defaultRunLoopMode)
    }

    func center(atTarget target: ObserveTarget) {
        let ephemeris = EphemerisManager.default.content(for: ephemerisSubscriptionIdentifier)!
        let coordinate: Vector3
        switch target {
        case let .nearbyBody(body):
            coordinate = ephemeris.observedPosition(of: body as! CelestialBody, fromObserver: ephemeris[.majorBody(.earth)]!)
        case let .star(star):
            coordinate = star.physicalInfo.coordinate
        }
        observerScene.cameraNode.orientation = SCNQuaternion(Quaternion(alignVector: Vector3(1, 0, 0), with: coordinate))
    }

    private var titleOverlayHeightConstraint: NSLayoutConstraint?

    private func animateOverlayTitle(heightConstant: CGFloat) {
        if let prevConstraint = self.titleOverlayHeightConstraint {
            titleOverlayView.removeConstraint(prevConstraint)
        }
        titleOverlayHeightConstraint = titleOverlayView.heightAnchor.constraint(equalToConstant: heightConstant)
        titleOverlayView.addConstraint(titleOverlayHeightConstraint!)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: [], animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    private func showTitleOverlay(target: ObserveTarget) {
        titleOverlayView.title = String(describing: target)
        animateOverlayTitle(heightConstant: view.safeAreaInsets.bottom + 60)
    }

    private func hideTitleOverlay() {
        animateOverlayTitle(heightConstant: 0)
    }

    private func focusAtTarget() {
        guard let target = target else {
            return
        }
        switch target {
        case let .nearbyBody(closeBody):
            observerScene.focus(atCelestialBody: closeBody as! CelestialBody)
        case let .star(star):
            observerScene.focus(atStar: star)
        }
    }

    // MARK: - Button handling

//    @objc func menuButtonTapped(sender _: UIButton) {
//        let menuController = ObserverMenuController(style: .plain)
//        menuController.menu = Menu.main
//        let navigationController = UINavigationController(rootViewController: menuController)
//        navigationController.modalPresentationStyle = .overCurrentContext
//        navigationController.delegate = self
//        tabBarController?.present(navigationController, animated: true, completion: nil)
//    }

    @objc func gyroButtonTapped(sender _: UIBarButtonItem) {
        MotionManager.default.toggleMotionUpdate()
    }

    @objc func searchButtonTapped(sender _: UIBarButtonItem) {
        let targetSearchController = ObserveTargetSearchViewController(style: .plain)
        targetSearchController.delegate = self
        targetSearchController.ephemerisSubscriptionId = ephemerisSubscriptionIdentifier
        let navigationController = UINavigationController(rootViewController: targetSearchController)
        navigationController.modalPresentationStyle = .overCurrentContext
        tabBarController?.present(navigationController, animated: true, completion: nil)
    }

    // MARK: - Gesture handling

    override func pan(sender: UIPanGestureRecognizer) {
        // if there's any pan event, cancel motion updates
        MotionManager.default.stopMotionUpdate()
        if sender.state == .ended {
            timeWarpSpeed = nil
            return
        }
        let location = sender.location(in: view)
        if Timekeeper.default.isWarpActive && CGRect(x: view.bounds.width - 44, y: 0, width: 44, height: view.bounds.height).contains(location) {
            let percentage = Double((view.bounds.height / 2 - sender.location(in: view).y) / (view.bounds.height / 2))
            let warpSpeed = percentage >= 0 ? exp(percentage * 16) : -exp(-percentage * 16)
            timeWarpSpeed = warpSpeed
        } else {
            super.pan(sender: sender)
        }
    }

    @objc func handleTap(sender: UITapGestureRecognizer) {
        let point = sender.location(in: view)
        let vec = SCNVector3(point.x, point.y, 0.5)
        let unitVec = Vector3(scnView.unprojectPoint(vec)).normalized()
        let ephemeris = EphemerisManager.default.content(for: ephemerisSubscriptionIdentifier)!
        if let closeBody = ephemeris.closestBody(toUnitPosition: unitVec, from: ephemeris[.majorBody(.earth)]!, maximumAngularDistance: RadianAngle(degreeAngle: DegreeAngle(3))) {
            target = .nearbyBody(closeBody)
        } else if let star = Star.closest(to: unitVec, maximumMagnitude: Constants.Observer.maximumDisplayMagnitude, maximumAngularDistance: RadianAngle(degreeAngle: DegreeAngle(3))) {
            target = .star(star)
        } else {
            target = nil
        }
    }

    @objc func toggleTimeWarp(sender _: UIBarButtonItem) {
        guard Settings.default[.enableTimeWarp] else { return }
        Timekeeper.default.isWarpActive = !Timekeeper.default.isWarpActive
        updateTimeLabel()
    }

    // MARK: - Updates

    private func updateTimeLabel() {
        if Timekeeper.default.isWarpActive {
            LocationManager.default.unsubscribe(locationSubscriptionIdentifier)
            overlayScene.show(withDuration: 0.25)
            let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.extraLight)
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: [], animations: {
                self.titleBlurView.effect = blurEffect
                self.titleButton.setTitleColor(UIColor.black, for: .normal)
            })
        } else {
            locationSubscriptionIdentifier = LocationManager.default.subscribe(didUpdate: observerScene.updateLocation(location:))
            stopTimeWarp(withAnimationDuration: 0.25)
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: [], animations: {
                self.titleBlurView.effect = nil
                self.titleButton.setTitleColor(UIColor.white, for: .normal)
            })
        }
    }

    private func stopTimeWarp(withAnimationDuration animationDuration: Double) {
        Timekeeper.default.reset()
        ObserverLocationTimeManager.default.julianDay = nil
        overlayScene.hide(withDuration: animationDuration)
    }

    private func configurePanSpeed() {
        let factor = CGFloat(ObserverScene.defaultFov / observerScene.fov)
        cameraController?.viewSlideDivisor = factor * 25000
    }

    @objc func updateTimestampLabel() {
        let requestTimestamp = Timekeeper.default.content ?? JulianDay.now
        titleButton.setTitle(Formatters.dateFormatter.string(from: requestTimestamp.date), for: .normal)
    }

    func ephemerisDidUpdate(ephemeris _: Ephemeris) {
        assertMainThread()
        if let observerInfo = ObserverLocationTimeManager.default.observerInfo {
            observerCameraController.orientCameraNode(observerInfo: observerInfo)
            observerScene.updateStellarContent(observerInfo: observerInfo)
        }
    }

    private func updateAntialiasingMode(_ key: String) {
        scnView.antialiasingMode = SCNAntialiasingMode(rawValue: UInt(["none", "multisampling2X", "multisampling4X"].index(of: key)!))!
    }

    // MARK: - Scene renderer delegate

    override func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        Timekeeper.default.warp(by: timeWarpSpeed)
        if Timekeeper.default.isWarpActive && Timekeeper.default.isWarping == false {
            super.renderer(renderer, didRenderScene: scene, atTime: time)
            return
        }
        if Timekeeper.default.isWarpActive {
            cameraController?.slideVelocity = CGPoint.zero
        } else {
            super.renderer(renderer, didRenderScene: scene, atTime: time)
        }
        let requestTimestamp = Timekeeper.default.content ?? JulianDay.now
        ObserverLocationTimeManager.default.julianDay = requestTimestamp
        EphemerisManager.default.request(at: requestTimestamp, forSubscription: ephemerisSubscriptionIdentifier)
        configurePanSpeed()
        observerScene.rendererUpdate()
    }
}

// MARK: - Star search view controller delegate

extension ObserverViewController: ObserveTargetSearchViewControllerDelegate {
    func observeTargetViewController(_: ObserveTargetSearchViewController, didSelectTarget target: ObserveTarget) {
        dismiss(animated: true, completion: nil)
        self.target = target
        center(atTarget: self.target!)
    }
}

extension ObserverViewController: ObserverTitleOverlayViewDelegate {
    func titleOverlayTapped(view _: ObserverTitleOverlayView) {
//        guard let detailVc = storyboard?.instantiateViewController(withIdentifier: "ObserverDetailViewController") as? ObserverDetailViewController else {
//            return
//        }
//        detailVc.delegate = self
//        detailVc.target = target
//        detailVc.ephemerisId = ephemerisSubscriptionIdentifier
//        let navigationController = UINavigationController(rootViewController: detailVc)
//        navigationController.modalPresentationStyle = .overCurrentContext
//        navigationController.delegate = self
//        tabBarController?.present(navigationController, animated: true, completion: nil)
        
//
        var context = ""
        
        switch target! {
        case let .star(star):
            let row0Content = star.identity.contentAtRow(0)
            context = row0Content.0 + ": " + row0Content.1 + ". Constellation: " + star.identity.constellation.name
            
        case .nearbyBody(_):
            context = ""
        }
        
        //        let chatView = ChatView(spaceObject: title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "saturn", context: context.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "You%20are%20a%20space%20object")
        //
        //        let chatController = ChatHostingController(rootView: chatView)
        
        let infoView = InfoView(target: target, ephemerisId: ephemerisSubscriptionIdentifier, context: context.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "You%20are%20a%20space%20object")
                
        let infoController = InfoHostingController(rootView: infoView)

        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissInfoController))

        infoController.navigationItem.rightBarButtonItem = doneButton
        infoController.navigationItem.title = String(describing: target!)

        let navigationController = UINavigationController(rootViewController: infoController)
        navigationController.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController.modalPresentationStyle = .fullScreen

        tabBarController?.present(navigationController, animated: true, completion: nil)


    }

    func titleOverlayFocusTapped(view _: ObserverTitleOverlayView) {
        center(atTarget: target!)
    }
    
    @objc private func dismissInfoController() {
        navigationController?.dismiss(animated: true, completion: nil)
    }

}


extension ObserverViewController: UINavigationControllerDelegate {
    func navigationController(_: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from _: UIViewController, to _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PushAsideTransition(presenting: operation == .push)
    }
}

extension ObserverViewController: ObserverDetailViewControllerDelegate {
    func observerDetailViewController(viewController: ObserverDetailViewController, dismissTapped _: UIButton) {
        dismiss(animated: true, completion: nil)
        target = viewController.target
        focusAtTarget()
    }
}

private func stringify(_ str: CustomStringConvertible?) -> String? {
    if str == nil { return nil }
    return String(describing: str!)
}

