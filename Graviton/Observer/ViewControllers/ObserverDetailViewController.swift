//
//  ObserverDetailViewController.swift
//  Graviton
//
//  Created by Sihao Lu on 7/6/17.
//  Copyright © 2017 Ben Lu. All rights reserved.
//

import Orbits
import StarryNight
import UIKit
import XLPagerTabStrip
import SwiftUI

protocol ObserverDetailViewControllerDelegate: NSObjectProtocol {
    func observerDetailViewController(viewController: ObserverDetailViewController, dismissTapped sender: UIButton)
}

class ObserverDetailViewController: UIViewController {
    var target: ObserveTarget!
    var ephemerisId: SubscriptionUUID!

    weak var delegate: ObserverDetailViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewElements()
        view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = false
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }

    private func setupViewElements() {
        title = String(describing: target!)
        navigationController?.navigationBar.barStyle = .black
        let doneBarItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped(sender:)))
        navigationItem.rightBarButtonItem = doneBarItem
        view.backgroundColor = UIColor.black
    }

    override var prefersStatusBarHidden: Bool {
        return Device.isiPhoneX == false
    }

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        if segue.identifier == "embedObserverDetail" {
            let innerVc = segue.destination as! ObserverDetailInnerViewController
            innerVc.target = target
            innerVc.ephemerisId = ephemerisId
        }
    }

    @objc func doneButtonTapped(sender: UIButton) {
        delegate?.observerDetailViewController(viewController: self, dismissTapped: sender)
    }
}

class ObserverDetailInnerViewController: ButtonBarPagerTabStripViewController {
    var target: ObserveTarget!
    var ephemerisId: SubscriptionUUID!

    override func viewDidLoad() {
        settings.style.selectedBarBackgroundColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
        settings.style.buttonBarBackgroundColor = UIColor.black
        settings.style.buttonBarItemTitleColor = #colorLiteral(red: 0.9735557437, green: 0.9677678943, blue: 0.978004396, alpha: 1)
        settings.style.buttonBarItemBackgroundColor = UIColor.clear
        
        // Disable scrolling and hide the scroll bar
        buttonBarView.scrollsToTop = false
        buttonBarView.showsHorizontalScrollIndicator = false
        
        super.viewDidLoad()
        
        view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        view.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        view.backgroundColor = UIColor.clear
        view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = false
        
    }

    // MARK: - PagerTabStripDataSource

    override func viewControllers(for _: PagerTabStripViewController) -> [UIViewController] {
        
        var context = ""
        
        switch target! {
        case let .star(star):
            let row0Content = star.identity.contentAtRow(0)
            context = row0Content.0 + ": " + row0Content.1 + ". Constellation: " + star.identity.constellation.name
            context.append(". Distance from Sun: " + (stringify(star.physicalInfo.distance) ?? "0"))
            context.append(". Visual Magnitude: " + (stringify(star.physicalInfo.apparentMagnitude) ?? ""))
            context.append(". Absolute Magnitude: " + (stringify(star.physicalInfo.absoluteMagnitude)  ?? ""))
            context.append(". Spectral Type: " + (stringify(star.physicalInfo.spectralType) ?? ""))
            context.append(". Luminosity (x Sun): " + (stringify(star.physicalInfo.luminosity) ?? ""))
            
            
            
        case .nearbyBody(_):
            context = ""
        }
        
        //        let chatView = ChatView(spaceObject: title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "saturn", context: context.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "You%20are%20a%20space%20object")
        //
        //        let chatController = ChatHostingController(rootView: chatView)
        
        let InfoController = InfoHostingController(rootView: InfoView(target: target, ephemerisId: ephemerisId, context: context))
        
        //        let bodyInfo = BodyInfoViewController(style: .plain)
        //                bodyInfo.target = target
        //                bodyInfo.ephemerisId = ephemerisId
        
        //        let viewControllers = [bodyInfo, chatController]
        
        return [InfoController]
    }
}


private func stringify(_ str: CustomStringConvertible?) -> String? {
    if str == nil { return nil }
    return String(describing: str!)
}
