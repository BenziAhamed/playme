#!/usr/bin/swift

//
//  playme.swift
//  convert playgrounds to markdown
//
//  Created by Benzi on 11/03/17.
//  Copyright © 2017 Benzi Ahamed.
//  
//  License: https://github.com/BenziAhamed/playme/blob/master/LICENSE


import Foundation

func error(_ message: @autoclosure () -> String) -> Never  {
    print("error: ", message())
    exit(-1)
}

// validate usage

if CommandLine.arguments.count == 1 {
    print("playme v1.0")
    print("    convert playgrounds to markdown")
    print("usage: playme path_to_playground (--toc)")
    print("")
    print("--toc       prints a GitHub compatible TOC at the start")
    exit(0)
}

let command = CommandLine.arguments.joined(separator: " ")
let debugEnabled = command.contains(" --debug")
let skipConversion = command.contains(" --skip")
let generateTOC = command.contains(" --toc")

func debug(_ message: @autoclosure () -> String) {
    guard debugEnabled else { return }
    print("[DEBUG]", message())
}

func doDebug(actions: () -> ()) {
    guard debugEnabled else { return }
    actions()
}

// validate input file

var playground = CommandLine.arguments[1]

let contentsXML = playground + "/contents.xcplayground"
let fm = FileManager.default

func validateInput(file: String) {
    
    var isDirectory: ObjCBool = false
    let exists = fm.fileExists(atPath: file, isDirectory: &isDirectory)
    
    guard exists else { error("file not found \(file)") }
    guard isDirectory.boolValue else { error("invalid file \(file)") }
    guard fm.isReadableFile(atPath: file) else { error("cannot read \(file)") }
    
    guard fm.fileExists(atPath: contentsXML, isDirectory: &isDirectory) else { error("metadata file not found") }
}

validateInput(file: playground)

// get source files to process

func getSourceFiles() -> [String] {
    let e = error
    do {
        guard let data = fm.contents(atPath: contentsXML) else { error("cannot process metadata file") }
        let xml = try XMLDocument.init(data: data, options: 0)
        let pageNames = try xml.nodes(forXPath: "/playground/pages/page/@name")
        if pageNames.count > 0 {
            let pages = pageNames
                .flatMap { $0.objectValue as? String }
                .map { "\(playground)/Pages/\($0).xcplaygroundpage/Contents.swift" }
            return pages
        }
        else {
            return [playground + "/Contents.swift"]
        }
    }
    catch {
        e("\(error)")
    }
}

let sourceFiles = getSourceFiles()


// process source files
// scan each line of source file
// find out code and markdown blocks
// and output the markdown text

extension String {
    
    func strippingLeadingSpacesForHeaders() -> String {
        guard let regex = try? NSRegularExpression.init(pattern: "^(\\s*)(#+)", options: .caseInsensitive) else { return self }
        if let match = regex.firstMatch(in: self, options: .withoutAnchoringBounds, range: .init(location: 0, length: characters.count)) {
            guard match.numberOfRanges == 3 else { return self }
            let whitespaceCount = match.rangeAt(1).length
            return substring(from: index(startIndex, offsetBy: whitespaceCount))
        }
        return self
    }
    
    func strippingLeadingPattern(_ pattern: String) -> String {
        guard let regex = try? NSRegularExpression.init(pattern: pattern, options: .caseInsensitive) else { return self }
        if let match = regex.firstMatch(in: self, options: .withoutAnchoringBounds, range: .init(location: 0, length: characters.count)) {
            guard match.numberOfRanges >= 2 else { return self }
            let count = match.rangeAt(1).length
            return substring(from: index(startIndex, offsetBy: count))
        }
        return self
    }

}


struct TocEntry {
    let level: Int
    let text: String
}

extension String {
    func getTocEntry() -> TocEntry? {
        guard
            let regex = try? NSRegularExpression.init(pattern: "^(\\s*)(#+)", options: .caseInsensitive),
            let match = regex.firstMatch(in: self, options: .withoutAnchoringBounds, range: .init(location: 0, length: characters.count))
        else { return nil }
        let level = match.rangeAt(2).length
        let header = substring(from: index(startIndex, offsetBy: match.range.length))
        return TocEntry(level: level, text: header)
    }
    
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func kebabCase() -> String {
        return self.components(separatedBy: " ").joined(separator: "-")
    }
}


enum Token {
    
    case code(String)
    case markdownLine(String)
    case markdownBlockLine(String)
    case markdownBlockStart
    case markdownBlockEnd
    case newline
    
    var isMarkdownToken: Bool {
        switch self {
        case .markdownLine, .markdownBlockLine, .markdownBlockEnd, .markdownBlockStart:
            return true
        default:
            return false
        }
    }
    
    var description: String {
        switch self {
        case let .code(code):                   return "CODE: \(code)"
        case let .markdownLine(text):           return "  MD: \(text)"
        case let .markdownBlockLine(text):      return "..MD: \(text)"
        case .markdownBlockStart:               return "++MD:"
        case .markdownBlockEnd:                 return "--MD:"
        case .newline:                          return "  NL:"
        }
    }
    
    var text: String {
        switch self {
        case let .code(code):               return code
        case let .markdownLine(text):       return text.strippingLeadingPattern("(//:)").strippingLeadingSpacesForHeaders()
        case .markdownBlockStart:           return ""
        case let .markdownBlockLine(text): 	return text.strippingLeadingSpacesForHeaders()
        case .markdownBlockEnd:             return ""
        case .newline:                      return "\n"
        }
    }
}


var tocEntries = [TocEntry]()

func checkTocEntry(_ token: Token) {
    guard let tocEntry = token.text.getTocEntry() else { return }
    tocEntries.append(tocEntry)
}

func convertToMarkdown(file: String) -> [String] {

    let data = fm.contents(atPath: file)!
    let contents = String.init(data: data, encoding: String.Encoding.utf8)!
    
    var tokens = [Token]()
    var inMarkdownBlock = false
    
    // determine the kind of line
    // we are looking at

    for line in contents.components(separatedBy: "\n") {
        
        // skip special lines
        if line.contains("(@previous)") || line.contains("(@next)") {
            continue
        }

        // standalone line
        if !inMarkdownBlock && line.hasPrefix("//:") {
            let token = Token.markdownLine(line)
            tokens.append(token)
            checkTocEntry(token)
        }
        else if line.hasPrefix("/*:") {
            tokens.append(.markdownBlockStart)
            inMarkdownBlock = true
        }
        // very basic end block detection
        else if line == "*/" || line == " */" || line == "  */" {
            tokens.append(.markdownBlockEnd)
            inMarkdownBlock = false
        }
        else if line == "" {
            tokens.append(.newline)
        }
        else {
            if inMarkdownBlock {
                let token = Token.markdownBlockLine(line)
                tokens.append(token)
                checkTocEntry(token)
            }
            else {
                tokens.append(.code(line))
            }
        }
    }
    
    
    // strip trailing new lines
    // but add one
    while let lastLine = tokens.last, case .newline = lastLine {
        tokens.removeLast()
    }
    tokens.append(.newline)

    doDebug {
        debug("-------------")
        debug("FILE: \(file)")
        debug("TOKENS -------------")
        tokens.enumerated().forEach { index, token in
            debug("\(index) \(token.description)")
        }
        debug("END TOKENS -------------")
    }

    enum BlockType {
        case markdown(start:Int, end:Int)
        case code(start:Int, end:Int)
    }
    
    
    // find blocks of mardown and code
    
    func findBlocks(tokens: [Token]) -> [BlockType] {
        var blocks = [BlockType]()
        
        var codeStart = 0
        var codeEnd = 0
        
        var i = 0
        var markdownStart = 0
        
        while i < tokens.count {
            
            if case .code = tokens[i] {
                
                // whatever was before is present was a markdown block
                if i > 0 {
                    let markdown = BlockType.markdown(start: markdownStart, end: i)
                    blocks.append(markdown)
                }
                
                codeStart = i
                codeEnd = i
                while codeEnd < tokens.count {
                    if tokens[codeEnd].isMarkdownToken {
                        break
                    }
                    codeEnd += 1
                }
                // if we are not at the end of the file
                // we move back up
                if codeEnd < tokens.count {
                    while codeEnd > codeStart + 1 {
                        if case .code = tokens[codeEnd-1] {
                            break
                        }
                        codeEnd -= 1
                    }
                }
                
                blocks.append(.code(start: codeStart, end: codeEnd))
                
                // advance markdownStart
                i = codeEnd + 1
                markdownStart = codeEnd
                continue
            }
            
            i += 1
        }
        
        if codeEnd < tokens.count {
            blocks.append(.markdown(start: codeEnd, end: tokens.count))
        }
        
        return blocks
    }
    
    let blocks = findBlocks(tokens: tokens)

    doDebug {
        debug("BLOCKS -------------")
        blocks.forEach {
            debug("\($0)")
        }
        debug("END BLOCKS -------------")
        debug("END FILE: \(file)")
        debug("-------------")
    }
    
    var lines = [String]()
    
    for block in blocks {
        switch block {
        case let .code(start, end):
            lines.append("```swift")
            for i in start..<end {
                lines.append(tokens[i].text)
            }
            lines.append("```\n")
        case let .markdown(start, end):
            for i in start..<end {
                lines.append(tokens[i].text)
            }
        }
    }
    
    return lines
    
}


var allConvertedLines = [String]()
sourceFiles.forEach { allConvertedLines.append(contentsOf: convertToMarkdown(file: $0)) }


if generateTOC {
    print("# Contents")
    tocEntries.forEach { tocEntry in
        let headingBulletLevel = String.init(repeating: " ", count: 4 * (tocEntry.level-1))
        // let headingBulletLevel = String.init(repeating: "\t", count: tocEntry.level-1)
        let header = tocEntry.text.trim()
        let link = header.kebabCase().lowercased()
        print("\(headingBulletLevel)- [\(header)](#\(link))")
    }
}


guard !skipConversion else { exit(0) }
    
allConvertedLines.forEach { 
    if $0 == "\n" {
        print($0, separator: "", terminator: "")
    }
    else {
        print($0) 
    }
}

