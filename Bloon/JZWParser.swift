//
//  JZWParser.swift
//  Bloon
//
//  Created by Jacob Weiss on 8/3/14.
//  Copyright (c) 2014 Jacob Weiss. All rights reserved.
//

import Cocoa
import Foundation

class JZWParser
{
    // The name of this parser
    var name : String
    // The path to the input file or pipe
    var inputPath : String = ""
    // The path to the serial port (/dev/...)
    var portPath : String
    // The serial port object
    var port : JZWSerialPort
    // The nsdata for storing all the raw serial data
    var data = JZWData(blockSize: 100000, numBlocks: 10)
    // The file to write the raw data to
    var rawFile : FileHandle? = nil
    // The file to write all the parsed binary data to
    var binFile : FileHandle? = nil
    // The file to write all the ascii sentences to
    var asciiFile : FileHandle? = nil
    // The location to save all data files
    var dataPath : String
    // The baud rate of the serial port
    var baud : Int32
    // The time the port was opened
    var startTime : Date
    // The parser tree
    var parseTree : [JZWParseTree]
    // The list of all sentences in the parse tree
    var sentences : [String: JZWSentence]
    // The indexed parsed to
    var parsedIndex : Int
    // Weather or not the parser saves raw data files in ascii and binary
    var savesAscii = false
    var savesBinary = false
    var tokenLabels : [String]
    
    var stopParsingCallback : (() -> ())? =  nil
    
    var queuedTasks: Int = 0
    
    // The packet filter runs in this queue
    var queue: DispatchQueue
    
    // The packet saving runs in this queue
    var saveQueue: DispatchQueue
    
    var pipeHandle : FileHandle? = nil
    
    var stop : Bool = false
    
    init(portName name: String, dataPath: String, portPath port: String, baud: Int32, sentences: [JZWSentence])
    {
        self.portPath = port
        self.name = name
        self.port = JZWSerialPort()
        self.rawFile = nil
        self.asciiFile = nil
        self.baud = baud
        self.startTime = Date()
        self.parsedIndex = 0
        self.parseTree = JZWParseTree.build(sentences)!

        self.sentences = [String: JZWSentence]()
        self.tokenLabels = [String]()
        
        self.queue = DispatchQueue(label: self.name, qos: DispatchQoS.utility, attributes: DispatchQueue.Attributes(), autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        self.saveQueue = DispatchQueue(label: self.name + "SaveQueue", qos: DispatchQoS.utility, attributes: DispatchQueue.Attributes(), autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
                
        if (dataPath.hasSuffix("/"))
        {
            self.dataPath = dataPath
        }
        else
        {
            self.dataPath = dataPath + "/"
        }
        
        self.startTime = Date()
        
        for s in sentences
        {
            s.data = self.data
            self.sentences[s.name] = s
            
            let tl = s.getTokenLabels()
            
            for label in tl
            {
                if !label.hasSuffix(".") && label != ""
                {
                    self.tokenLabels.append(label)
                }
            }
        }
    }
        
    deinit
    {
        self.sentences.removeAll()
    }
    
    func errorReport() -> String
    {
        var errors = ""
        for sentence in self.sentences
        {
            errors = "\(errors)\r\n\(sentence.value.errorReport())"
        }
        return errors
    }
    
    func getAllSentences() -> [String: JZWSentence]
    {
        var allSentences = [String: JZWSentence]()
        self.getAllSentences(&allSentences)
        return allSentences;
    }

    func getAllSentences(_ allSentences: inout [String: JZWSentence])
    {
        for (key, sent) in self.sentences
        {
            allSentences[key] = sent
            sent.getAllSentences(&allSentences)
        }
    }
        
    func openSerialPort() -> Bool
    {        
        self.queue.async(execute: {self.parseDataAsync()})
        
        return (self.port.open(self.portPath, baud: self.baud) { (fileHandle: FileHandle?) in
            self.readData(fileHandle)
        }) > 0
    }
    
    func openFiles()
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd.HH.mm.ss"
        let timeString = formatter.string(from: self.startTime)
        
        let basePath = (self.dataPath + timeString + "_" + self.name)

        let pathTorawFile = basePath + "_raw.dat"
        FileManager.default.createFile(atPath: pathTorawFile, contents: nil, attributes: nil)
        self.rawFile = FileHandle(forWritingAtPath:pathTorawFile)

        if self.savesBinary
        {
            let pathToBinFile = basePath + ".dat"
            FileManager.default.createFile(atPath: pathToBinFile, contents: nil, attributes: nil)
            self.binFile = FileHandle(forWritingAtPath:pathToBinFile)
        }
        
        if self.savesAscii
        {
            let pathToAsciiFile = basePath + ".txt"
            FileManager.default.createFile(atPath: pathToAsciiFile, contents: nil, attributes: nil)
            self.asciiFile = FileHandle(forWritingAtPath:pathToAsciiFile)
        }
    
        for s in self.sentences
        {
            s.1.createSaveFiles(basePath)
        }
    }
    
    func closeParser(_ callback : @escaping () -> ())
    {
        let myCallback = { [weak self] () -> () in
            if let sself = self
            {
                if let pipe = sself.pipeHandle
                {
                    pipe.closeFile()
                }

                if let rf = sself.rawFile
                {
                    rf.closeFile()
                    sself.rawFile = nil
                }
                if let bf = sself.binFile
                {
                    bf.closeFile()
                    sself.binFile = nil
                }
                if let af = sself.asciiFile
                {
                    af.closeFile()
                    sself.asciiFile = nil
                }
                
                for (_, s) in sself.sentences
                {
                    s.closeSaveFiles()
                }
                
                sself.parseTree = []
                
                callback()
            }
        }
        
        objc_sync_enter(self)
        self.stop = true
        self.port.close()
        if self.queuedTasks > 0
        {
            self.stopParsingCallback = myCallback
        }
        else
        {
            myCallback()
        }
        objc_sync_exit(self)
    }
    
    @objc(readDataFromHandle:)
    func readData(_ handle: FileHandle!)
    {
        let exception = tryBlock {
            let newData = handle.availableData
            self.readData(newData)
        }
        
        if let _ = exception
        {
            self.port.close()
            repeat
            {
                Thread.sleep(forTimeInterval: 1.0)
                
            } while (!self.stop && self.port.open(self.portPath, baud: self.baud, read: { (handle : FileHandle?) in
                self.readData(handle)
            }) == -1);
        }
    }

    class func isPipe(_ path : String) -> Bool
    {
        let unsafePath = UnsafePointer<Int8>(path.cString(using: String.Encoding.ascii)!)
        var st : stat = stat()
        stat(unsafePath, &st)
        let isPipe = (st.st_mode & S_IFMT) == S_IFIFO
        return isPipe;
    }

    func presentErrorAlert(withMessage message : String)
    {
        let errorAlert : NSAlert = NSAlert()
        errorAlert.messageText = message
        errorAlert.alertStyle = NSAlert.Style.critical
        errorAlert.addButton(withTitle: "OK")
        print(message)
        errorAlert.runModal()
    }
    
    @objc(readDataFromFile:)
    func readData(_ file: String) -> Bool
    {
        let path = (file as NSString).expandingTildeInPath
        self.inputPath = path
        
        // Check to see if the path is a named FIFO pipe
        let pathIsPipe = JZWParser.isPipe(path)
        
        //If there is a file, but it isn't a FIFO pipe...
        if FileManager.default.fileExists(atPath: path) && !pathIsPipe
        {
            // If the file isn't a "regular" file, then return and log an error
            do
            {
                let attributes = try FileManager.default.attributesOfItem(atPath: path)
                if attributes[FileAttributeKey.type] as! String != FileAttributeType.typeRegular.rawValue
                {
                    self.presentErrorAlert(withMessage: "Error: Attempting to parse abnormal file.")
                    return false
                }
            }
            catch
            {
                self.presentErrorAlert(withMessage: "Error: Could not read attributes of file.")
                return false
            }
            
            // Read the data
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path))
            {
                self.readData(data)
            }
            else
            {
                self.presentErrorAlert(withMessage: "Error: Could not open file.")
                return false
            }
        }
        else // There is either no file, or the file is a FIFO pipe
        {
            let cpath = path.cString(using: String.Encoding.ascii)!
            
            // If there isn't a pipe, then make one
            if !pathIsPipe
            {
                umask(0000)
                if mkfifo(path, S_IRUSR | S_IWUSR | S_IWGRP | S_IWOTH) > 0
                {
                    self.presentErrorAlert(withMessage: "Error: Could create FIFO pipe.")
                    return false
                }
            }
            
            let fd = open(cpath, O_RDWR)
            self.pipeHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            print("Wat");
            self.pipeHandle!.readabilityHandler = { (fh : FileHandle) -> () in
                let data = fh.availableData
                self.readData(data)
            }
        }
        
        return true
    }
    
    func readData(_ newData: Data)
    {
        objc_sync_enter(self)
        self.data.appendData(newData)
        
        // Increment queuedTasks (shared among threads)
        self.queuedTasks += 1
        if self.queuedTasks == 1 // If 1 here, then it was 0 before the increment
        {
            self.queue.async(execute: {self.parseDataAsync()})
        }
        if let rf = self.rawFile
        {
            rf.write(newData)
        }
        objc_sync_exit(self)
    }
    
    func parseDataAsync()
    {
        while (self.queuedTasks > 0)
        {
            loop: while self.stopParsingCallback == nil
            {
                var shouldBreak = false
                
                autoreleasepool(
                invoking: {
                    //Thread.sleep(forTimeInterval:0.001) // To slow down the parsing (looks more real time)
                    var increment = Int.max
                    for tree in self.parseTree
                    {
                        let (p, s, i, blocks) = tree.parse(self.data, start: self.parsedIndex, index: self.parsedIndex)
                            
                        if (i < increment)
                        {
                            increment = i
                        }
                        
                        if p != nil
                        {
                            JZWParsedSentenceData_setIndex(p!, UInt32(self.parsedIndex))

                            self.parsedIndex += i
                            
                            let parsedSentenceSentence = s!
                            
                            if (self.savesBinary && self.binFile != nil) ||
                               (self.savesAscii  && self.asciiFile != nil) ||
                               (parsedSentenceSentence.savesBinary && parsedSentenceSentence.binFile != nil) ||
                               (parsedSentenceSentence.savesAscii && parsedSentenceSentence.asciiFile != nil)
                            {
                                let (raw, parsed) = JZWParsedSentence.saveData(p!, sentence: parsedSentenceSentence, forceSaveAscii: self.savesAscii && self.asciiFile != nil)
                                
                                if self.savesBinary && self.binFile != nil
                                {
                                    self.binFile!.write(raw as Data)
                                }
                                if self.savesAscii && self.asciiFile != nil
                                {
                                    self.asciiFile!.write(parsed as Data)
                                }
                            }
                            
                            if let b = blocks
                            {
                                for block in b
                                {
                                    block()
                                }
                            }
                            
                            return
                        }
                    }
                    
                    if increment == 0
                    {
                        shouldBreak = true
                        return
                    }
                                
                    self.parsedIndex += increment
                })
                
                if (shouldBreak)
                {
                    break
                }
            }
            
            
            if let stopParsing = self.stopParsingCallback
            {
                stopParsing()
                self.stopParsingCallback = nil
                return
            }
            
            objc_sync_enter(self)
            self.queuedTasks -= 1
            objc_sync_exit(self)
        }
    }
        
    class func getPorts() -> [String]
    {
        return try! FileManager().contentsOfDirectory(atPath: "/dev/").filter({$0.hasPrefix("tty.")}).map({"/dev/\($0)"})
    }
}

func shell(_ args: String...) -> (Int32, String)
{
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = args
    task.standardOutput = Pipe()
    task.launch()
    task.waitUntilExit()
    let output = NSString(data: (task.standardOutput as! Pipe).fileHandleForReading.availableData, encoding: String.Encoding.utf8.rawValue)
    return (task.terminationStatus, output! as String)
}
