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
import Contacts

enum IntervalType: String {
    case Minute
    case Hour
    case Day
    case Week
    case Month
}

let intervalSeconds: [IntervalType: Double] =
    [
        .Minute: 60.0,
        .Hour: 3600.0,
        .Day: 86400.0,
        .Week: 604800.0,
        .Month: 2592000.0
    ]

class CoreModule: RoutingModule {
    var description: String = NSLocalizedString("CoreDescription")
    var routes: [Route] = []
    let MAXIMUM_CONCURRENT_SENDS = 3
    var currentSends: [String: Int] = [:]
    let scheduleCheckInterval = 30.0 * 60.0
    var sender: MessageSender
    var timer: Timer!
    
    var persistentContainer: PersistentContainer = {
        let container = PersistentContainer(name: "CoreModule")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return container
    }()
    
    required public init(sender: MessageSender) {
        self.sender = sender
        let appsupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Jared").appendingPathComponent("CoreModule")
        try! FileManager.default.createDirectory(at: appsupport, withIntermediateDirectories: true, attributes: nil)
        
        let ping = Route(name:"/ping", comparisons: [.startsWith: ["/ping"]], call: {[weak self] in self?.pingCall($0)}, description: NSLocalizedString("pingDescription"))
        
        let thankYou = Route(name:"Thank You", comparisons: [.startsWith: ["Thank You"]], call: {[weak self] in self?.thanksJared($0)}, description: NSLocalizedString("ThanksJaredResponse"))
        
        let wordleScore = Route(name:"Wordle Score", comparisons: [.startsWith: ["Wordle"]], call: {[weak self] in self?.wordleScore($0)}, description: "Gets Wordle Score From Copy/Paste")
        
        let getMonthly = Route(name:"Monthly", comparisons: [.startsWith: ["Monthly"]], call: {[weak self] in self?.getMonthly($0)}, description: "Get Monthly Leaderboards")
        
        let getWeekly = Route(name:"Weekly", comparisons: [.startsWith: ["Weekly"]], call: {[weak self] in self?.getWeekly($0)}, description: "Get Weekly Leaderboards")
        
        let getDaily = Route(name:"Daily", comparisons: [.startsWith: ["Daily"]], call: {[weak self] in self?.getDaily($0)}, description: "Get Daily Leaderboards")
        
        let version = Route(name: "/version", comparisons: [.startsWith: ["/version"]], call: {[weak self] in self?.getVersion($0)}, description: "Get the version of Jared running")
        
        let whoami = Route(name: "/whoami", comparisons: [.startsWith: ["/whoami"]], call: {[weak self] in self?.getWho($0)}, description: "Get your name")
        
        let initDic = Route(name: "/initDic", comparisons: [.startsWith: ["/initDic"]], call: {[weak self] in self?.initDic($0)}, description: "Initializes Dic Arrays")
        
        let fetchDic = Route(name: "/fetchDic", comparisons: [.startsWith: ["/fetchDic"]], call: {[weak self] in self?.fetchDic($0)}, description: "Fetches Dic Arrays")
        
        let send = Route(name: "/send", comparisons: [.startsWith: ["/send"]], call: {[weak self] in self?.sendRepeat($0)}, description: NSLocalizedString("sendDescription"),parameterSyntax: NSLocalizedString("sendSyntax"))
        
        let name = Route(name: "/name", comparisons: [.startsWith: ["/name"]], call: {[weak self] in self?.changeName($0)}, description: "Change what Jared calls you", parameterSyntax: "/name,[your preferred name]")
        
        let schedule = Route(name: "/schedule", comparisons: [.startsWith: ["/schedule"]], call: {[weak self] in self?.schedule($0)}, description: NSLocalizedString("scheduleDescription"), parameterSyntax: "Must be one of these type of inputs: /schedule,add,1,Week,5,full Message\n/schedule,delete,1\n/schedule,list")
        
        let barf = Route(name: "/barf", comparisons: [.startsWith: ["/barf"]], call: {[weak self] in self?.barf($0)}, description: NSLocalizedString("barfDescription"))
        
        
        
        routes = [ping, thankYou, version, send, whoami, name, schedule, barf, wordleScore, initDic, fetchDic, getWeekly, getDaily, getMonthly]
        
        //Launch background thread that will check for scheduled messages to send
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: {[weak self] (theTimer) in
            self?.scheduleThread()
        })
    }
    
    deinit {
        timer.invalidate()
    }
    
    func pingCall(_ incoming: Message) -> Void {
        sender.send(NSLocalizedString("PongResponse"), to: incoming.RespondTo())
    }
    
    func initDic(_ incoming: Message) -> Void {
        sender.send("Initializing Dictionary", to: incoming.RespondTo())
        
        var userData = [String: [Int: Int]]()
        
        userData["rileybluerobets@gmail.com"] = [576: 4]
        userData["sy.dv@gmail"] = [576:6]
        
        if let filePath = try? getFileURL(fileName: "data.dat").path {
               NSKeyedArchiver.archiveRootObject(userData, toFile: filePath)
        }
    }
    
    func fetchDic(_ incoming: Message) -> Void{
        var userData = [String: [Int: Int]]()
        
        if let filePath = try? getFileURL(fileName: "data.dat").path {
            userData = NSKeyedUnarchiver.unarchiveObject(withFile: filePath) as! [String : [Int : Int]]
        }
        
        sender.send(userData.description, to: incoming.RespondTo())
    }
    
    func barf(_ incoming: Message) -> Void {
        sender.send(String(data: try! JSONEncoder().encode(incoming), encoding: .utf8) ?? "nil", to: incoming.RespondTo())
    }
    
    func getWho(_ message: Message) -> Void {
        if message.sender.givenName != nil {
            sender.send("Your name is \(message.sender.givenName!).", to: message.RespondTo())
        }
        else {
            sender.send("Eat my ass.", to: message.RespondTo())
        }
    }
    
    func thanksJared(_ message: Message) -> Void {
        sender.send(NSLocalizedString("WelcomeResponse"), to: message.RespondTo())
    }
    
    func wordleScore(_ message: Message) -> Void {
        let _ = print(message.getTextBody() ?? "N/A")
        
        let mArray = String(message.getTextBody() ?? "N/A").split(separator: " ")
        let day = Int(mArray[1]) ?? -1
        
        let sArray = mArray[2].split(separator: "/")
        let score = Int(sArray[0]) ?? 8
        
        var userData = [String: [Int: Int]]()
        
        if let filePath = try? getFileURL(fileName: "data.dat").path {
            userData = NSKeyedUnarchiver.unarchiveObject(withFile: filePath) as! [String : [Int : Int]]
        }
        
        var dict = userData[message.sender.handle]
        if userData.index(forKey: message.sender.handle) == nil{
            dict = [:]
        }
        dict?[day] = score
        userData[message.sender.handle] = dict
        
        //Stores current wordle day in handle "curDay"[-1]
        var dayData = userData["curDay"]
        if userData.index(forKey: "curDay") == nil{
            dayData = [:]
        }
        dayData?[-1] = day
        userData["curDay"] = dayData
        
        if let filePath = try? getFileURL(fileName: "data.dat").path {
               NSKeyedArchiver.archiveRootObject(userData, toFile: filePath)
        }
        
        //sender.send("Score Received | day: "+String(day)+" score: "+String(score), to: message.RespondTo())
        
    }
    
    func getDaily(_ message: Message) -> Void {
        var userData = [String: [Int: Int]]()
        
        if let filePath = try? getFileURL(fileName: "data.dat").path {
            userData = NSKeyedUnarchiver.unarchiveObject(withFile: filePath) as! [String : [Int : Int]]
        }
        let curDay = userData["curDay"]
        
        let scores = getTotals(userData: userData, numDays: 1,curDay: curDay?[-1] ?? 0)
        
        let sortedScores = scores.sorted { $0.1 < $1.1 }
        
        var returnString = "\u{1F3C6} Daily Leaderboards \u{1F3C6}\n---------------------------"
        
        var numRanks = 5
        
        if sortedScores.count < 5 {
            numRanks = sortedScores.count
        }
        
        for rank in 0...(numRanks-1) {
            returnString += "\n" + String(rank+1) + ". " + getName(handle: sortedScores[rank].key) + " (" + String(sortedScores[rank].value) + ")"
        }
        
        sender.send(returnString, to: message.RespondTo())
//        sender.send(sortedScores.description, to: message.RespondTo())
//        sender.send(sortedScores[0].key, to: message.RespondTo())
    }
    
    func getWeekly(_ message: Message) -> Void {
        var userData = [String: [Int: Int]]()
        
        if let filePath = try? getFileURL(fileName: "data.dat").path {
            userData = NSKeyedUnarchiver.unarchiveObject(withFile: filePath) as! [String : [Int : Int]]
        }
        let curDay = userData["curDay"]
        
        let scores = getTotals(userData: userData, numDays: 7,curDay: curDay?[-1] ?? 0)
        
        let sortedScores = scores.sorted { $0.1 < $1.1 }
        
        var returnString = "\u{1F3C6} Weekly Leaderboards \u{1F3C6}\n-----------------------------"
        
        var numRanks = 5
        
        if sortedScores.count < 5 {
            numRanks = sortedScores.count
        }
        
        for rank in 0...(numRanks-1) {
            returnString += "\n" + String(rank+1) + ". " + getName(handle: sortedScores[rank].key) + " (" + String(sortedScores[rank].value) + ")"
        }
        
        sender.send(returnString, to: message.RespondTo())
//        sender.send(sortedScores.description, to: message.RespondTo())
//        sender.send(sortedScores[0].key, to: message.RespondTo())
    }
    
    func getMonthly(_ message: Message) -> Void {
        var userData = [String: [Int: Int]]()
        
        if let filePath = try? getFileURL(fileName: "data.dat").path {
            userData = NSKeyedUnarchiver.unarchiveObject(withFile: filePath) as! [String : [Int : Int]]
        }
        let curDay = userData["curDay"]
        
        let scores = getTotals(userData: userData, numDays: 30,curDay: curDay?[-1] ?? 0)
        
        let sortedScores = scores.sorted { $0.1 < $1.1 }
        
        var returnString = "\u{1F3C6} Monthly Leaderboards \u{1F3C6}\n------------------------------"
        
        var numRanks = 5
        
        if sortedScores.count < 5 {
            numRanks = sortedScores.count
        }
        
        for rank in 0...(numRanks-1) {
            returnString += "\n" + String(rank+1) + ". " + getName(handle: sortedScores[rank].key) + " (" + String(sortedScores[rank].value) + ")"
        }
        
        sender.send(returnString, to: message.RespondTo())
//        sender.send(sortedScores.description, to: message.RespondTo())
//        sender.send(sortedScores[0].key, to: message.RespondTo())
    }
    
    func getVersion(_ message: Message) -> Void {
        sender.send(NSLocalizedString("versionResponse"), to: message.RespondTo())
    }
    
    func sendRepeat(_ message: Message) -> Void {
        guard let parameters = message.getTextParameters() else {
            return sender.send("Inappropriate input type.", to: message.RespondTo())
        }
        
        //Validating and parsing arguments
        guard let repeatNum: Int = Int(parameters[1]) else {
            return sender.send("Wrong argument. The first argument must be the number of message you wish to send", to: message.RespondTo())
        }
        
        guard let delay = Int(parameters[2]) else {
            return sender.send("Wrong argument. The second argument must be the delay of the messages you wish to send", to: message.RespondTo())
        }
        
        guard var textToSend = parameters[safe: 3] else {
            return sender.send("Wrong arguments. The third argument must be the message you wish to send.", to: message.RespondTo())
        }
        
        guard (currentSends[message.sender.handle] ?? 0) < MAXIMUM_CONCURRENT_SENDS else {
            return sender.send("You can only have \(MAXIMUM_CONCURRENT_SENDS) send operations going at once.", to: message.RespondTo())
        }
        
        if (currentSends[message.sender.handle] == nil)
        {
            currentSends[message.sender.handle] = 0
        }
        
        //Increment the concurrent send counter for this user
        currentSends[message.sender.handle] = currentSends[message.sender.handle]! + 1
        
        //If there are commas in the message, take the whole message
        if parameters.count > 4 {
            textToSend = parameters[3...(parameters.count - 1)].joined(separator: ",")
        }
        
        //Go through the repeat loop...
        for _ in 1...repeatNum {
            sender.send(textToSend, to: message.RespondTo())
            Thread.sleep(forTimeInterval: Double(delay))
        }
        
        //Decrement the concurrent send counter for this user
        currentSends[message.sender.handle] = (currentSends[message.sender.handle] ?? 0) - 1
    }
    
    @objc func scheduleThread() {
        let posts = getPendingPosts()
        
        //Loop over all posts
        for post in posts {
            guard let handle = post.handle, let text = post.text else {
                continue
            }
            
            let recipient = AbstractRecipient(handle: handle)
            sender.send(text, to: recipient)
            bumpPost(post: post)
        }
    }
    
    func schedule(_ message: Message) {
        // /schedule,add,1,Week,5,full Message
        // /schedule,delete,1
        // /schedule,list
        guard let parameters = message.getTextBody()?.components(separatedBy: ",") else {
            return sender.send("Inappropriate input type", to:message.RespondTo())
        }
        
        guard parameters.count > 1 else {
            return sender.send("More parameters required.", to: message.RespondTo())
        }
        
        switch parameters[1] {
        case "add":
            guard parameters.count > 5 else {
                return sender.send("Incorrect number of parameters specified.", to: message.RespondTo())
            }

            guard let sendIntervalNumber = Int(parameters[2]) else {
                return sender.send("Send interval number must be an integer.", to: message.RespondTo())
            }

            guard let sendIntervalType = IntervalType(rawValue: parameters[3]) else {
                return sender.send("Send interval type must be a valid input (hour, day, week, month).", to: message.RespondTo())
            }

            guard let sendTimes = Int(parameters[4]) else {
                return sender.send("Send times must be an integer.", to: message.RespondTo())
            }

            let sendMessage = parameters[5]

            guard let respondToHandle = message.RespondTo()?.handle else {
                return
            }

            let post = NSEntityDescription.insertNewObject(forEntityName: "SchedulePost", into:  persistentContainer.viewContext) as! SchedulePost
            post.sendIntervalNumber = Int64(sendIntervalNumber)
            post.sendNumberTimes = Int64(sendTimes)
            post.sendIntervalType = sendIntervalType.rawValue
            post.currentSendCount = 0
            post.text = sendMessage
            post.handle = respondToHandle
            post.startDate = Date()
            post.sendNext = getNextSendTime(number: sendIntervalNumber, type: sendIntervalType)
            
            persistentContainer.saveContext()
            sender.send("Your post has been succesfully scheduled.", to: message.RespondTo())
            break
        case "delete":
            guard let respondHandle = message.RespondTo()?.handle else {
                return
            }
            guard parameters.count > 2 else {
                return sender.send("The second parameter must be a valid id.", to: message.RespondTo())
            }

            guard let deleteID = Int(parameters[2]) else {
                return sender.send("The delete ID must be an integer.", to: message.RespondTo())
            }

            guard deleteID > 0 else {
                return sender.send("The delete ID must be an positive integer.", to: message.RespondTo())
            }

            let posts = getPosts(for: respondHandle)
            guard posts.count >= deleteID else {
                return sender.send("The specified post ID is not valid.", to: message.RespondTo())
            }

            persistentContainer.viewContext.delete(posts[deleteID - 1])
            persistentContainer.saveContext()
            sender.send("The specified scheduled post has been deleted.", to: message.RespondTo())

            break
        case "list":
            guard let respondHandle = message.RespondTo()?.handle else {
                return
            }
            let posts = getPosts(for: respondHandle)

            var sendMessage = "\(message.sender.givenName ?? "Hello"), you have \(posts.count) posts scheduled."
            for (index, post) in posts.enumerated() {
                sendMessage += "\n\(index + 1): Send a message every \(post.sendIntervalNumber) \(post.sendIntervalType!)(s) \(post.sendNumberTimes) time(s), starting on \(post.startDate!.description(with: Locale.current))."
            }
            sender.send(sendMessage, to: message.RespondTo())
            break
        default:
            sender.send("Invalid schedule command type. Must be add, delete, or list", to: message.RespondTo())
            break
        }
    }
    
    func changeName(_ message: Message) {
        guard let parsedMessage = message.getTextParameters() else {
            return sender.send("Inappropriate input type", to:message.RespondTo())
        }
        
        if (parsedMessage.count == 1) {
            return sender.send("Wrong arguments.", to: message.RespondTo())
        }
        
        guard (CNContactStore.authorizationStatus(for: CNEntityType.contacts) == .authorized) else {
            return sender.send("Sorry, I do not have access to contacts.", to: message.RespondTo())
        }
        let store = CNContactStore()
        
        let searchPredicate: NSPredicate
        if (!(message.sender.handle.contains("@"))) {
            searchPredicate = CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: message.sender.handle ))
        } else {
            searchPredicate = CNContact.predicateForContacts(matchingEmailAddress: message.sender.handle )
        }
        
        let peopleFound = try! store.unifiedContacts(matching: searchPredicate, keysToFetch:[CNContactFamilyNameKey as CNKeyDescriptor, CNContactGivenNameKey as CNKeyDescriptor])
        
        
        //We need to create the contact
        if (peopleFound.count == 0) {
            // Creating a new contact
            let newContact = CNMutableContact()
            newContact.givenName = parsedMessage[1]
            newContact.note = "Created By jared.app"
            
            //If it contains an at, add the handle as email, otherwise add it as phone
            if (message.sender.handle.contains("@")) {
                let homeEmail = CNLabeledValue(label: CNLabelHome, value: (message.sender.handle) as NSString)
                newContact.emailAddresses = [homeEmail]
            }
            else {
                let iPhonePhone = CNLabeledValue(label: "iPhone", value: CNPhoneNumber(stringValue:message.sender.handle))
                newContact.phoneNumbers = [iPhonePhone]
            }
            
            let saveRequest = CNSaveRequest()
            saveRequest.add(newContact, toContainerWithIdentifier:nil)
            do {
                try store.execute(saveRequest)
            } catch {
                return sender.send("There was an error saving your contact..", to: message.RespondTo())
            }
            
            sender.send("Ok, I'll call you \(parsedMessage[1]) from now on.", to: message.RespondTo())
        }
        //The contact already exists, modify the value
        else {
            let mutableContact = peopleFound[0].mutableCopy() as! CNMutableContact
            mutableContact.givenName = parsedMessage[1]
            
            let saveRequest = CNSaveRequest()
            saveRequest.update(mutableContact)
            try! store.execute(saveRequest)
            
            sender.send("Ok, I'll call you \(parsedMessage[1]) from now on.", to: message.RespondTo())
        }
    }
    
    private func getNextSendTime(number: Int, type: IntervalType) -> Date {
        return Date().addingTimeInterval(Double(number) * (intervalSeconds[type] ?? 0))
    }
    
    private func getPosts(for handle: String) -> [SchedulePost] {
        let postRequest:NSFetchRequest<SchedulePost> = SchedulePost.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "startDate", ascending: false)
        postRequest.sortDescriptors = [sortDescriptor]
        postRequest.predicate = NSPredicate(format: "handle == %@", handle)

        do {
            return try persistentContainer.viewContext.fetch(postRequest)
        } catch {
            return []
        }
    }
    
    private func getPendingPosts() -> [SchedulePost] {
        let postRequest:NSFetchRequest<SchedulePost> = SchedulePost.fetchRequest()
        postRequest.predicate = NSPredicate(format: "sendNext <= %@", NSDate())

        do {
            return try persistentContainer.viewContext.fetch(postRequest)
        } catch {
            return []
        }
    }
    
    private func bumpPost(post: SchedulePost) {
        post.currentSendCount += 1
        
        if (post.currentSendCount == post.sendNumberTimes) {
            persistentContainer.viewContext.delete(post)
        } else {
            post.sendNext = getNextSendTime(number: Int(post.sendIntervalNumber), type: IntervalType(rawValue: post.sendIntervalType!)!)
        }
        persistentContainer.saveContext()
    }
    
    private func getFileURL(fileName: String) throws -> URL {
            let manager = FileManager.default
            let dirURL = try manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            return dirURL.appendingPathComponent(fileName)
     }
    
    private func getTotals(userData: [String: [Int: Int]], numDays: Int, curDay: Int) -> [String: Int]{
        var totals = [String: Int]()
        var sum = 0
        
        for (handle, scores) in userData {
            
            if (handle == "curDay"){continue}
            if (handle == "rileybluerobets@gmail.com" || handle == "sy.dv@gmail"){continue}
            
            sum = 0
            var x = 1
            
            for day in (curDay - (numDays-1))...curDay{
                x += 1
                //If someone missed a day they get a score of 8
                sum += scores[day] ?? 8
            }
            
            totals[handle] = sum
        }
        
        return totals
    }
    
    private func getName(handle: String) -> String{
        
        let dict = [
            "+17472837692": "Riley",
            "+16472416252": "Brian",
            "+16509066690": "Shirley",
            "+16504684100": "Bruce",
            "sosoroberts@icloud.com": "Sophia",
            "mikeyrw2004@yahoo.com": "Mike",
            "+14082420231": "Scott",
            "+16509066630": "Lisa"
        ]
        
        return dict[handle] ?? handle
    }
}
