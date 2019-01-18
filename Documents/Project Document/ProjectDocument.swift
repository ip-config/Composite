//
//  ProjectDocument.swift
//  SCE-Mac
//
//  Created by Ronald "Danger" Mannak on 8/1/18.
//  Copyright © 2018 A Puzzle A Day. All rights reserved.
//

import Foundation
import Cocoa

/*
 [NSDocumentController fileExtensionsFromType:] is deprecated, and does not work when passed a uniform type identifier (UTI). If the application didn't invoke it directly then the problem is probably that some other NSDocument or NSDocumentController method is getting confused by a UTI that's not actually declared anywhere. Maybe it should be declared in the UTExportedTypeDeclarations section of this app's Info.plist but is not. The alleged UTI in question is "app.composite.project".
 
 */

final class ProjectDocument: NSDocument {
    
    ///
    private (set) var project: Project?
    
    ///
    private (set) var interface: EditorInterface? = nil
    
    /// URL of the .comp project file E.g. ~/Projects/ProjectName/ProjectName.comp
    var projectFileURL: URL {
        return fileURL!
    }
    
    /// Parent directory of the project, e.g. ~/Projects (not ~/Projects/ProjectName)
    var baseDirectory: URL {
        return workDirectory.deletingLastPathComponent()
    }
    
    /// E.g. ~/Projects/ProjectName
    var workDirectory: URL {
        return projectFileURL.deletingLastPathComponent()
    }
    
    
    var editWindowController: ProjectWindowController? {
        for window in windowControllers {
            if let window = window as? ProjectWindowController, let doc = window.document as? ProjectDocument, doc == self {
                return window
            }
        }
        return nil
    }

    
    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }
    
    convenience init(project: Project, url: URL) {
        self.init()
        fileURL = url
        self.project = project
    }

    
    override class var autosavesInPlace: Bool {
        return true
    }

    
    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("ProjectWindow"), bundle: nil)
        // Note: Changing the storyboard ID "EditWindow" in the storyboard to "ProjectWindow"
        // somehow always get magically rolled back to "EditWindow" by Xcode. So "EditWindow"
        // it is then for now
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("EditWindow")) as! ProjectWindowController
        self.addWindowController(windowController)
        
//        windowController.project = self.project 
    }

    
    override func data(ofType typeName: String) throws -> Data {
        
        guard let editWindowController = editWindowController, let project = editWindowController.project else {
            assertionFailure()
            return Data()
        }
        
        editWindowController.saveEditorFile()
        
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(project)
        return data
    }

    
    override func read(from data: Data, ofType typeName: String) throws {

        let decoder = PropertyListDecoder()
        project = try decoder.decode(Project.self, from: data)
        
        let platformName = project!.platformName
        let frameworkName = project!.frameworkName
        let frameworkVersion = project!.frameworkVersion
        
        guard let platform = Platform.init(rawValue: platformName) else { throw CompositeError.platformNotFound(platformName) }
        
        interface = try EditorInterface.loadInterface(platform: platform, framework: frameworkName, version: frameworkVersion).first
    }

    
}
