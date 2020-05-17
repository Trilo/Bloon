//
//  JZWMainViewController.swift
//  Bloon
//
//  Created by Jacob Weiss on 1/31/15.
//  Copyright (c) 2015 Jacob Weiss. All rights reserved.
//

import Foundation

let ALL_TOKEN_LABELS = "allTokenLabels"
let ALL_SENTENCES = "allSentences"
let ALL_PARSERS = "allParsers"

class JZWMainViewController: NSViewController, NSWindowDelegate
{
    @IBOutlet var configureParserBG: JZWGradient?
    @IBOutlet var configureParserButton: NSButton?
    @IBOutlet var configureGrapherBG: JZWGradient?
    @IBOutlet var configureGrapherButton: NSButton?
    
    var parserViewController = JZWParserViewController()
    var graphViewController = JZWGraphWindowSetupViewController()
    
    var currentParser: JZWParserStarter? = nil
    var allParsers = [JZWParser]()
    var currentWindows: [NSWindow]? = nil
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // check state here and provide app-specific diagnostic if it's wrong
        self.parserViewController.isRootParser = true
    }
    
    convenience init()
    {
        self.init(nibName: "JZWMainView", bundle: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(JZWMainViewController.updateTokenLabelsNotification(_:)), name: NSNotification.Name(rawValue: TOKEN_LABELS_CHANGED_NOTIFICATION), object: nil)
    }

    required convenience init?(coder: NSCoder)
    {
        self.init()
        
        self.parserViewController = coder.decodeObject(forKey: "parser") as! JZWParserViewController
        self.parserViewController.isRootParser = true

        self.graphViewController = coder.decodeObject(forKey: "grapher") as! JZWGraphWindowSetupViewController
        NotificationCenter.default.post(name: Notification.Name(rawValue: TOKEN_LABELS_CHANGED_NOTIFICATION), object: self, userInfo: nil)
    }
    
    override func encode(with aCoder: NSCoder)
    {
        aCoder.encode(self.parserViewController, forKey: "parser")
        aCoder.encode(self.graphViewController, forKey: "grapher")
    }
            
    @objc func updateTokenLabelsNotification(_ not: Notification)
    {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let labels = self.parserViewController.getAllTokenLabels()
            self.graphViewController.updateTokenLabels(labels)
        }
    }
        
    @IBAction func runClicked(_ sender: AnyObject)
    {
        _ = self.start()
    }
    
    func start(_ shouldSaveData : Bool = true) -> Bool
    {
        var userData: [String: AnyObject]? = [String: AnyObject]()
        userData![ALL_PARSERS] = NSMutableArray()
        
        self.currentParser = self.parserViewController.build("", userData: &userData)! as? JZWParserStarter
        
        self.currentWindows = self.graphViewController.build("", userData: &userData)! as? [NSWindow]
        
        if let parsers = userData![ALL_PARSERS] as! NSMutableArray?
        {
            for parser in parsers
            {
                self.allParsers.append(parser as! JZWParser)
            }
        }
        
        for window in self.currentWindows!
        {
            window.makeKeyAndOrderFront(self)
            window.setFrame(window.screen!.frame, display: true, animate: false)
            window.isReleasedWhenClosed = false
            window.delegate = self
        }
        
        if shouldSaveData
        {
            for parser in self.allParsers
            {
                parser.openFiles()
            }
        }
        
        if let cp = self.currentParser
        {
            return cp.startParser()
        }
        else
        {
            return false
        }
    }
    
    func stop(_ callback : @escaping () -> ())
    {
        let parserStopGroup = DispatchGroup()
        for parser in self.allParsers
        {
            parserStopGroup.enter()
            DispatchQueue.global().async {
                parser.closeParser({ () -> () in
                    parserStopGroup.leave()
                })
            }
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: { () -> Void in
            parserStopGroup.wait()
            let graphStopGroup = DispatchGroup()
            
            if let w = self.currentWindows
            {
                var graphs = [JZWGLGraph]()
                for window in w
                {
                    graphStopGroup.enter()
                    DispatchQueue.global().async {
                        var subviews : [NSView] = []
                        DispatchQueue.main.sync {
                            subviews = window.contentView!.subviews[0].subviews
                        }
                        for v in subviews
                        {
                            (v as! JZWGLGraph).stop()
                        }
                        
                        let graphRemoveGroup = DispatchGroup()
                        for v in subviews
                        {
                            graphs.append((v as! JZWGLGraph))
                            JZWGLGraph.remove((v as! JZWGLGraph))
                            graphRemoveGroup.enter()
                            DispatchQueue.main.async(execute: { () -> Void in
                                v.removeFromSuperview()
                                graphRemoveGroup.leave()
                            });
                        }
                        graphRemoveGroup.wait()
                        DispatchQueue.main.sync(execute: { () -> Void in
                            window.contentView!.subviews[0].removeFromSuperview()
                            window.close()
                        })
                        graphStopGroup.leave()
                    }
                }
                graphStopGroup.wait()
                
                self.allParsers.removeAll()
                self.currentParser = nil
                self.currentWindows = nil
                DispatchQueue.main.sync {
                    graphs.removeAll()
                }
                callback()
            }
        })
    }
    
    @IBAction func configureParserClicked(_ sender: AnyObject)
    {
        let parserTitle = self.parserViewController.getTitle()
        let title = (parserTitle == "") ? "Parser" : parserTitle
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: HISTORYVIEW_PUSH_NOTIFICATION),
            object: self.view.window, userInfo: ["view" : self.parserViewController.view, "title" : title])
    }

    @IBAction func configureGrapherClicked(_ sender: AnyObject)
    {
        NotificationCenter.default.post(name: Notification.Name(rawValue: HISTORYVIEW_PUSH_NOTIFICATION),
            object: self.view.window, userInfo: ["view" : self.graphViewController.view, "title" : "Grapher"])
    }
}
