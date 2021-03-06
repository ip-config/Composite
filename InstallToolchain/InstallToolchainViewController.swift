//
//  InstallToolchainViewController.swift
//  SCE-Mac
//
//  Created by Ronald "Danger" Mannak on 9/7/18.
//  Copyright © 2018 A Puzzle A Day. All rights reserved.
//

import Cocoa


/// TODO: Add a forced remove and install option if user holds command or option button
class InstallToolchainViewController: NSViewController {
    
    @IBOutlet weak var platformCollectionView: NSCollectionView!
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    // Framework detail view
    @IBOutlet weak var detailImageView: NSImageView!
    @IBOutlet weak var detailLabel: NSTextField!
    @IBOutlet weak var detailInfoLabel: NSTextField!
    @IBOutlet weak var detailMoreInfoButton: NSButton!
    @IBOutlet weak var detailDocumentationButton: NSButton!
    @IBOutlet weak var detailStatusLabel: NSTextField!
    
    lazy private var console: InstallToolchainConsoleViewController = {
        return (parent as! NSSplitViewController).splitViewItems.last!.viewController as! InstallToolchainConsoleViewController
    }()
    
    /// Queue used to fetch versions (which can be extremely slow)
    let versionQueue: OperationQueue = OperationQueue()
    
    /// Queue used to fetch paths of the dependencies (if installed)
    let fileQueue: OperationQueue = OperationQueue()
    
    /// Queue used to install and update tools
    let installQueue: OperationQueue = OperationQueue()
    
    /// KVO for installQueue.operationCount
    /// If operationCount is greater than zero,
    /// the progress indicator will animate
    private var installCountObserver: NSKeyValueObservation?
    private var totalInstallCount = 0
    
    private var itemShownInDetailView: DependencyFrameworkViewModel? = nil
    
    private var platforms = [DependencyPlatformViewModel]() {
        didSet {
            
            platformCollectionView.reloadData()
            platformCollectionView.selectItems(at: [IndexPath(item: 0, section: 0)], scrollPosition: .top)
            frameworkViewModels = platforms.first?.frameworks ?? [DependencyFrameworkViewModel]()
            
        }
    }
    
    private var frameworkViewModels = [DependencyFrameworkViewModel]() {
        didSet {
            
            assert(Thread.isMainThread)
            
            // Set output
            for framework in frameworkViewModels {
                for dependency in framework.dependencies {
                    dependency.output = { stdout in
                        DispatchQueue.main.async {
                            self.console.output = self.console.output + stdout
                            
                        }
                    }
                }
            }
            
            outlineView.reloadData()
            if let first = frameworkViewModels.first {
                showDetailsFor(first)
            }
            self.fetchFileLocations()       // Set paths to binaries if installed
            self.fetchVersionNumbers()      // Fetch version numbers
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.dependencyChange(notification:)),
            name: NSNotification.Name(rawValue: DependencyViewModel.notificationString),
            object: nil)
        
        
        fileQueue.maxConcurrentOperationCount = 1
        fileQueue.qualityOfService = .userInteractive
        versionQueue.maxConcurrentOperationCount = 1
        versionQueue.qualityOfService = .userInteractive
        installQueue.maxConcurrentOperationCount = 1
        installQueue.qualityOfService = .userInitiated
        
        
        installCountObserver = installQueue.observe(\OperationQueue.operationCount, options: .new) { queue, change in
            DispatchQueue.main.async {
                if queue.operationCount == 0 {
                    self.progressIndicator.stopAnimation(self)
                    self.progressIndicator.isHidden = true
                    self.totalInstallCount = 0
                    self.outlineView.reloadData()
                } else {
                    self.outlineView.reloadData()
                    if queue.operationCount > self.totalInstallCount {
                        self.totalInstallCount = queue.operationCount
                    }
                    self.progressIndicator.doubleValue = (1.0 - (Double(queue.operationCount) / Double(self.totalInstallCount))) * 90.0 + 10
                    self.progressIndicator.startAnimation(self)
                    self.progressIndicator.isHidden = false
                }
            }
        }
    
        // Bug in 10.13 prevents scrolling colletionviews beyond the initial rect.
        // See https://stackoverflow.com/questions/46433652/nscollectionview-does-not-scroll-items-past-initial-visible-rect
//        if #available(OSX 10.13, *) {
//            if let contentSize = self.platformCollectionView.collectionViewLayout?.collectionViewContentSize {
//                self.platformCollectionView.setFrameSize(contentSize)
//            }
//        }
        
        configurePlatformCollectionView()
        loadPlatforms()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: DependencyViewModel.notificationString), object: nil)
        installCountObserver?.invalidate()
    }
    
    func loadPlatforms() {
        
        do {
            // Load dependencies from disk
            platforms = try DependencyPlatformViewModel.loadPlatforms()
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
    
    // Searches for paths of the dependencies. Should be near-instant
    func fetchFileLocations() {

        for frameworkViewModel in frameworkViewModels {
            for tool in frameworkViewModel.dependencies {
                guard let operation = tool.fileLocationOperation() else { continue }
                fileQueue.addOperation(operation)
            }
        }
    }
    
    func fetchVersionNumbers() {
        
        versionQueue.cancelAllOperations()
        
        for frameworkViewModel in frameworkViewModels {
            for tool in frameworkViewModel.dependencies {
                
                // Fetch version
                guard let operation = tool.versionQueryOperation() else { continue }
                versionQueue.addOperation(operation)
                
                // Check if newer version is available
                guard let outdatedOperation = tool.outdatedOperation() else { continue }
                versionQueue.addOperation(outdatedOperation)
            }
        }
    }
    
    @objc private func dependencyChange(notification: NSNotification){
        
        DispatchQueue.main.async {
            self.outlineView.reloadData()
        }
    }
    
    private func configurePlatformCollectionView() {
        
        assert(Thread.isMainThread)
        view.wantsLayer = true
        
        let nib = NSNib(nibNamed: NSNib.Name("PlatformCollectionViewItem"), bundle: nil)
        platformCollectionView.register(nib, forItemWithIdentifier: NSUserInterfaceItemIdentifier("PlatformCollectionViewItem"))
        
        platformCollectionView.reloadData()
    }
    
    private func showDetailsFor(_ item: DependencyFrameworkViewModel) {
        detailLabel.stringValue = item.name.capitalizedFirstChar()
        detailInfoLabel.stringValue = item.description
        detailImageView.image = item.icon
        detailMoreInfoButton.alternateTitle = item.projectUrl
        detailMoreInfoButton.isHidden = false
        detailDocumentationButton.alternateTitle = item.documentationUrl
        detailDocumentationButton.isHidden = false
        
        switch  item.state {
        case .uptodate, .unknown:
            detailStatusLabel.stringValue = item.displayName + " is installed and up to date"
                        
        case .outdated:
            detailStatusLabel.stringValue = item.displayName + " is outdated"
            
        case .notInstalled:
            detailStatusLabel.stringValue = item.displayName + " is not installed"
        
        case .installing:
            detailStatusLabel.stringValue = item.displayName + " is installing"
            
        case .comingSoon:
            detailStatusLabel.stringValue = item.displayName + " will be added to Composite soon"
        }
        self.itemShownInDetailView = item
    }
    
    @IBAction func done(_ sender: Any) {
        fileQueue.cancelAllOperations()
        versionQueue.cancelAllOperations()
//        fileQueue.qualityOfService = .background
//        versionQueue.qualityOfService = .background
        view.window?.close()
        (DocumentController.shared as! DocumentController).newProject(self)
    }
    
    
    @IBAction func cellButton(_ sender: Any) {
        // NSButton is a subclass of NSView
        guard let sender = sender as? NSView else { return }
        let row = outlineView.row(for: sender)
        if let item = outlineView.item(atRow: row) as? DependencyFrameworkViewModel {
            showDetailsFor(item)
        }
        
        var models = [DependencyViewModel]()
        
        if let framework = outlineView.item(atRow: row) as? DependencyFrameworkViewModel {
            for dependency in framework.dependencies {
                models.append(dependency)
            }
        } else if let dependency = outlineView.item(atRow: row) as? DependencyViewModel {
            models.append(dependency)
        }
        
        for model in models {
            if model.state == .notInstalled, let operations = model.install() {
                _ = operations.map { self.installQueue.addOperation($0) }
            } else if model.state == .outdated, let operations = model.update() {
                _ = operations.map { self.installQueue.addOperation($0) }
            }
        }
    }
    
    @IBAction func platformMoreInfoButtonClicked(_ sender: Any) {
        
        guard let sender = sender as? NSView,
            let itemView = sender.nextResponder?.nextResponder as? PlatformCollectionViewItem,
            let indexPath = platformCollectionView.indexPath(for: itemView)
            else { return }

        // Select cell
        platformCollectionView.deselectAll(self)
        platformCollectionView.reloadData()
        platformCollectionView.selectItems(at: [indexPath], scrollPosition: .top)
        frameworkViewModels = platforms[indexPath.item].frameworks
        
        // Open url
        let platform = platforms[indexPath.item]
        guard let url = URL(string: platform.projectUrl) else { return }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func detailMoreInfo(_ sender: Any) {
        guard let url = URL(string: (sender as! NSButton).alternateTitle) else { return }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func detailDocumentation(_ sender: Any) {
        guard let url = URL(string: (sender as! NSButton).alternateTitle) else { return }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func consoleToggle(_ sender: Any) {
        guard let splitController = (parent as? NSSplitViewController), let splitItem = splitController.splitViewItems.last else { return }

        splitItem.collapseBehavior = .preferResizingSplitViewWithFixedSiblings
        splitController.toggleSidebar(nil)
    }
}

extension InstallToolchainViewController: NSOutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        
        func setButton(_ cellButton: NSButton, state: DependencyState, name: String, newerVersion: String? = nil) {
            
            switch state {
                
            case .notInstalled:
                
                cellButton.isHidden = false
                cellButton.isEnabled = true
                cellButton.title = "Install \(name)"
                
            case .outdated:
                
                cellButton.isHidden = false
                cellButton.isEnabled = true
                if let newerVersion = newerVersion {
                    cellButton.title = "Update to \(newerVersion)"
                } else {
                    cellButton.title = "Update \(name)"
                }                
                
            case .uptodate, .unknown:
                
                cellButton.isHidden = true
                
            case .installing:
                
                cellButton.isHidden = false
                cellButton.isEnabled = false
                cellButton.title = "Installing..."
                
            case .comingSoon:
                
                cellButton.isHidden = true
                cellButton.isEnabled = true
            }
        }
        
        guard let identifier = tableColumn?.identifier.rawValue else { return nil }
        
        guard let view: NSTableCellView = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "NameCell"), owner: self) as? NSTableCellView else {
            return nil
        }
        
        if let item = item as? DependencyFrameworkViewModel {
            
            // If framework is selected, also update detail view.
            // The state could have changed since the last time detail view was updated.
            if let itemShownInDetailView = self.itemShownInDetailView, itemShownInDetailView == item {                
                showDetailsFor(item)
            }
            
            switch identifier {
            case "DependencyColumn":
                
                view.imageView?.image = nil
                view.textField?.stringValue = item.displayName
                
            case "VersionColumn":
                
                view.textField?.stringValue = item.version
                view.textField?.textColor = NSColor.black
                
            case "PathColumn":
                
                view.textField?.stringValue = ""
                
            case "ActionColumn":
                
                // Fetch the button view
                guard let buttonView: NSTableCellView = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ActionCell"), owner: self) as? NSTableCellView else {
                    return nil
                }
                
                let cellButton: NSButton = buttonView.subviews.filter { $0.identifier!.rawValue == "Button1" }.first! as! NSButton
                setButton(cellButton, state: item.state, name: item.name)
                return buttonView
                
            default:
                
                print("Unknown column id: \(identifier)")
                assertionFailure()
            }
            
        } else if let item = item as? DependencyViewModel {
            
            switch identifier {
            case "DependencyColumn":
                
                view.textField?.stringValue = item.displayName
                
            case "VersionColumn":
                
                view.textField?.stringValue = item.version
                view.textField?.textColor = NSColor.gray
                
            case "PathColumn":
                
                view.textField?.stringValue = item.path ?? ""
                view.textField?.textColor = NSColor.gray
                
            case "ActionColumn":
                
                // Fetch the view with two buttons
                guard let buttonView: NSTableCellView = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ActionCell"), owner: self) as? NSTableCellView else {
                    return nil
                }
                
                let cellButton: NSButton = buttonView.subviews.filter { $0.identifier!.rawValue == "Button1" }.first! as! NSButton
                setButton(cellButton, state: item.state, name: item.name, newerVersion: item.newerVersionAvailable)
                return buttonView
                
            default:
                
                print("Unknown column id: \(identifier)")
                assertionFailure()
            }
        }
                
        return view
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        
        // Show framework details
        if let item = item as? DependencyFrameworkViewModel {
            showDetailsFor(item)
        } else if let item = item as? DependencyViewModel {
            for framework in frameworkViewModels {
                for dependency in framework.dependencies {
                    if dependency === item {
                        showDetailsFor(framework)
                        return false
                    }
                }
            }
        }
        
        return false
    }
}

extension InstallToolchainViewController: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        
        // If item is nil, return number of frameworks
        guard let item = item as? DependencyFrameworkViewModel else { return frameworkViewModels.count }
        
        // If item is a framework, return number of dependencies in framework
        return item.dependencies.count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        
        // Only frameworks are expandable
        guard let item = item as? DependencyFrameworkViewModel else { return false }
        
        // Return true if framework has dependencies
        return !item.dependencies.isEmpty
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        
        if item == nil {
            
            // If item is nil, this is the root
            return frameworkViewModels[index]
            
        } else if let framework = item as? DependencyFrameworkViewModel {
            
            // Return number of dependencies of the framework
            return framework.dependencies[index]
            
        } else {

            assertionFailure()
            return 0
        }
    }
}

extension InstallToolchainViewController: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        
        guard let index = indexPaths.first?.item else { return }
        frameworkViewModels = platforms[index].frameworks
    }
}

extension InstallToolchainViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return platforms.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        guard let cell = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("PlatformCollectionViewItem"), for: indexPath) as? PlatformCollectionViewItem else {
            return NSCollectionViewItem()
        }
        
        let platform = platforms[indexPath.item]
        cell.platformLabel.stringValue = platform.platform.description
        cell.logoImageView.image = NSImage(named: NSImage.Name(platform.platform.description))
        return cell
    }

}
