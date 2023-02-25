//
//  CoreModule.swift
//  Jared 3.0 - Swiftified
//
//  Created by Zeke Snider on 4/3/16.
//  Copyright © 2016 Zeke Snider. All rights reserved.
//

import Foundation
import Cocoa
import JaredFramework

extension RoutingModule {
    var fullDescription: String {
        var documentation = ""
        documentation += String(describing: type(of: self))
        documentation += ": "
        documentation += self.description
        documentation += "\n==============\n"
        
        documentation += self.routes
            .map{route in route.condenseDocumentation}
            .joined(separator: "\n")
        
        return documentation
    }
}

extension Route {
    var condenseDocumentation: String {
        var documentation = ""
        documentation += self.name
        documentation += ": "
        
        if let aRouteDescription = self.description {
            documentation += aRouteDescription
        }
        return documentation
    }
    var fullDescription: String {
        get {
            var documentation = NSLocalizedString("commandPrefix")
            documentation += self.name
            documentation += "\n===========\n"
            if self.description != nil {
                documentation += self.description!
            }
            else {
                documentation += NSLocalizedString("noDescription")
            }
            documentation += "\n\n"
            if let parameterString = self.parameterSyntax {
                documentation += NSLocalizedString("parametersPrefix")
                documentation += parameterString
            }
            else {
                documentation += NSLocalizedString("noDescriptionBody")
            }
            
            return documentation
        }
    }
}

class InternalModule: RoutingModule {
    var description: String = NSLocalizedString("InternalModule")
    var routes: [Route] = []
    var defaults: UserDefaults
    var pluginManager: PluginManagerDelegate?
    var sender: MessageSender
    
    required public convenience init(sender: MessageSender) {
        self.init(sender: sender, pluginManager: nil)
    }
    
    init(sender: MessageSender, pluginManager: PluginManagerDelegate?) {
        self.sender = sender
        self.pluginManager = pluginManager
        defaults = UserDefaults.standard
        
        let enable = Route(name:"/enable", comparisons: [.startsWith: ["/enable"]], call: {[weak self] in self?.enable($0)}, description: NSLocalizedString("enableDescription"))
        let disable = Route(name:"/disable", comparisons: [.startsWith: ["/disable"]], call: {[weak self] in self?.disable($0)}, description: NSLocalizedString("disableDescription"))
        let documentation = Route(name:"/help", comparisons: [.startsWith: ["/help"]], call: {[weak self] in self?.sendDocumentation($0)}, description: NSLocalizedString("helpDescription"))
        let reload = Route(name:"/reload", comparisons: [.startsWith: ["/reload"]], call: {[weak self] in self?.self.reload($0)}, description: NSLocalizedString("reloadDescription"))
        
        routes = [enable, disable, documentation, reload]
    }
    
    func enable(_ message: Message) -> Void {
        defaults.set(false, forKey: JaredConstants.jaredIsDisabled)
        sender.send(NSLocalizedString("enabledMessage"), to: message.RespondTo())
    }
    
    func disable(_ message: Message) -> Void {
        defaults.set(true, forKey: JaredConstants.jaredIsDisabled)
        sender.send(NSLocalizedString("disabledMessage"), to: message.RespondTo())
    }
    
    func reload(_ message: Message) -> Void {
        pluginManager?.reload()
        sender.send(NSLocalizedString("reloadMessage"), to: message.RespondTo())
    }
    
    func sendDocumentation(_ message: Message) {
        let parameters = message.getTextParameters()
        if parameters?.count == 2 {
            sender.send(singleDocumentation(parameters![1]), to: message.RespondTo())
            return
        }
        
        let documentation = pluginManager!.getAllModules()
            .map{ module in module.fullDescription }
            .joined(separator: "\n\n")
        
        sender.send(documentation, to: message.RespondTo())
    }
    
    private func singleDocumentation(_ routeName: String) -> String {
        return pluginManager!.getAllRoutes()
            .first(where: { route in route.name.lowercased() == routeName.lowercased() })?
            .fullDescription ?? ""
    }
}
