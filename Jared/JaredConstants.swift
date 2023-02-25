//
//  JaredConstants.swift
//  Jared
//
//  Created by Zeke Snider on 8/16/20.
//  Copyright © 2020 Zeke Snider. All rights reserved.
//

import Foundation

struct JaredConstants {
    static let restApiIsDisabled = "RestApiIsDisabled"
    static let jaredIsDisabled = "JaredIsDisabled"
    static let contactsAccess = "ContactsAccess"
    static let sendMessageAccess = "SendMessageAccess"
    static let fullDiskAccess = "FullDiskAccess"
    static let fullDiskAcccessUrl = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    static let contactsAccessUrl = "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts"
    static let automationAccessUrl = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    static let messagesUrl = "messages://"
}
