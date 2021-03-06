//
//  AppDelegate.swift
//  SCE-Mac
//
//  Created by Ronald "Danger" Mannak on 8/1/18.
//  Copyright © 2018 A Puzzle A Day. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private lazy var preferencesWindowController = NSWindowController.instantiate(storyboard: "PreferencesWindow")
    private lazy var toolchainWindowController = NSWindowController.instantiate(storyboard: "InstallToolchain")
    private lazy var templateWindowController = NSWindowController.instantiate(storyboard: "Template")
    
//    let installToolchainStoryboard = NSStoryboard(name: NSStoryboard.Name("InstallToolchain"), bundle: nil)
//    let installWizard = installToolchainStoryboard.instantiateInitialController() as? NSWindowController
    
//    @IBOutlet private weak var encodingsMenu: NSMenu?
    @IBOutlet private weak var syntaxStylesMenu: NSMenu?
    @IBOutlet private weak var themesMenu: NSMenu?
//    @IBOutlet private weak var whatsNewMenuItem: NSMenuItem?
    
    override func awakeFromNib() {
        
        super.awakeFromNib()
        
        // store key bindings in MainMenu.xib before menu is modified
        MenuKeyBindingManager.shared.scanDefaultMenuKeyBindings()
        
        // append the current version number to "What’s New" menu item
//        let shortVersionRange = Bundle.main.shortVersion.range(of: "^[0-9]+\\.[0-9]+", options: .regularExpression)!
//        let shortVersion = String(Bundle.main.shortVersion[shortVersionRange])
//        self.whatsNewMenuItem?.title = String(format: "What’s New in CotEditor %@".localized, shortVersion)
        
        // build menus
//        self.buildEncodingMenu()
        self.buildSyntaxMenu()
        self.buildThemeMenu()
//        ScriptManager.shared.buildScriptMenu()
        
        // manually insert Share menu on macOS 10.12 and earlier
//        if NSAppKitVersion.current < .macOS10_13 {
//            (DocumentController.shared as? DocumentController)?.insertLegacyShareMenu()
//        }
        
        // observe setting list updates
//        NotificationCenter.default.addObserver(self, selector: #selector(buildEncodingMenu), name: didUpdateSettingListNotification, object: EncodingManager.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(buildSyntaxMenu), name: didUpdateSettingListNotification, object: SyntaxManager.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(buildThemeMenu), name: didUpdateSettingListNotification, object: ThemeManager.shared)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        if UserDefaults.standard[.showInstallToolchainOnStartup] == true {
            showInstallToolchains(self)
        } else {
            (DocumentController.shared as! DocumentController).newProject(self)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    override init() {
        
        // register default setting values
        let defaults = DefaultSettings.defaults.mapKeys { $0.rawValue }
        UserDefaults.standard.register(defaults: defaults)
        NSUserDefaultsController.shared.initialValues = defaults
        
        // instantiate DocumentController
        _ = DocumentController.shared
        
        // wake text finder up
        _ = TextFinder.shared
        
        // register transformers
        ValueTransformer.setValueTransformer(HexColorTransformer(), forName: HexColorTransformer.name)
        
        super.init()
    }
    
    // Prevent showing empty untitled project window at startup
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }
    
    /// show preferences window
    @IBAction func showPreferences(_ sender: Any?) {
        self.preferencesWindowController.showWindow(sender)
    }

    
    @IBAction func showInstallToolchains(_ sender: AnyObject) {
        self.toolchainWindowController.showWindow(sender)
    }
    
    @IBAction func showProjectTemplates(_ sender: AnyObject) {
        self.templateWindowController.showWindow(sender)
    }
    
    /// build syntax style menu in the main menu
    @objc private func buildSyntaxMenu() {
        
        let menu = self.syntaxStylesMenu!
        
        menu.removeAllItems()
        
        // add None
        menu.addItem(withTitle: BundledStyleName.none, action: #selector(SyntaxHolder.changeSyntaxStyle), keyEquivalent: "")
        menu.addItem(.separator())
        
        // add syntax styles
        for styleName in SyntaxManager.shared.settingNames {
            menu.addItem(withTitle: styleName, action: #selector(SyntaxHolder.changeSyntaxStyle), keyEquivalent: "")
        }
        menu.addItem(.separator())
        
        // add item to recolor
        let recolorAction = #selector(SyntaxHolder.recolorAll)
        let shortcut = MenuKeyBindingManager.shared.shortcut(for: recolorAction)
        let recoloritem = NSMenuItem(title: "Re-Color All".localized, action: recolorAction, keyEquivalent: shortcut.keyEquivalent)
        recoloritem.keyEquivalentModifierMask = shortcut.modifierMask  // = default: Cmd + Opt + R
        menu.addItem(recoloritem)
    }
    
    
    /// build theme menu in the main menu
    @objc private func buildThemeMenu() {
        
        let menu = self.themesMenu!
        
        menu.removeAllItems()
        
        for themeName in ThemeManager.shared.settingNames {
            menu.addItem(withTitle: themeName, action: #selector(ThemeHolder.changeTheme), keyEquivalent: "")
        }
    }
    
}

// CotEditor extension
extension AppDelegate {
    
    /// open a specific page in Help contents
    @IBAction func openHelpAnchor(_ sender: AnyObject) {

        guard let identifier = (sender as? NSUserInterfaceItemIdentification)?.identifier else { return assertionFailure() }

        NSHelpManager.shared.openHelpAnchor(identifier.rawValue, inBook: Bundle.main.helpBookName)
    }

    
    
}
