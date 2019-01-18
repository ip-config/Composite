//
//  ProjectContentViewController.swift
//  Composite
//
//  Created by Ronald "Danger" Mannak on 1/16/19.
//  Copyright © 2019 A Puzzle A Day. All rights reserved.
//

import Cocoa

final class ProjectContentSplitViewController: NSSplitViewController {

    override var representedObject: Any? {
        
        didSet {
            for viewController in self.children {
                viewController.representedObject = representedObject
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    

}

/// Handle tabview changes of Nagivator and Inspector side panes
extension ProjectContentSplitViewController: TabViewControllerDelegate {
    
    func tabViewController(_ viewController: NSTabViewController, didSelect tabViewIndex: Int) {
        
    }
}
