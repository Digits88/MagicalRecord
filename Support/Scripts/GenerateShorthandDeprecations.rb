#!/usr/bin/env ruby
#
#  ProcessHeader.rb
#  Magical Record
#
#  Created by Saul Mora on 11/14/11.
#  Copyright 2011 Magical Panda Software LLC. All rights reserved.
#

require 'pp'

def processImplementation(headerFile)
    unless headerFile.end_with? ".h"
        puts "#{headerFile} not a header"
        return
    end

    puts "Reading #{headerFile}"

    method_match_expression = /^(?<Start>[\+|\-]\s*\([a-zA-Z\s\*]*\)\s*)(?<MethodName>\w+)(?<End>\:?.*)/
    category_match_expression = /^\s*(?<Interface>@[[:alnum:]]+)\s*(?<ObjectName>[[:alnum:]]+)\s*(\((?<Category>\w+)\))?/

    lines = File.readlines(headerFile)
    non_prefixed_methods = []
    processed_methods_count = 0
    objects_to_process = ["NSManagedObject", "NSManagedObjectContext", "NSManagedObjectModel", "NSPersistentStoreCoordinator", "NSPersistentStore"]

    lines.each { |line|
        processed_line = nil
        if line.start_with?("@interface")
            matches = category_match_expression.match(line)
            if objects_to_process.include?(matches[:ObjectName])
                processed_line = "\n@implementation #{matches[:ObjectName]} (#{matches[:Category]}ShortHand)\n"
            else
                puts "Skipping #{headerFile}"
                non_prefixed_methods = nil
                return
            end
        end

        if processed_line == nil
            matches = method_match_expression.match(line)

            if matches

                if matches[:MethodName].start_with?("MR_")
                    ++processed_methods_count
                    methodName = matches[:MethodName].sub("MR_", "")
                    methodStart = matches[:Start].gsub(/^[\-|\+].*/, '')
                    methodEnd = matches[:End].gsub(/\sNS_[^\s]+/, '').gsub(/\sMRDeprecated.*$/, '')

                    selfcall = "#{methodStart}#{matches[:MethodName]}#{methodEnd}"

                    pp selfcall
                    selfcall = selfcall.gsub(/;$/, '')
                    selfcall = selfcall.gsub(/(\([^\)]+\)+)/, '')

                    processed_line = <<EOS
#{matches[:Start]}#{methodName}#{methodEnd}
{
    return [self #{selfcall}];
}
EOS

                  if processed_line.include? "NSFetchedResultsController"
                    processed_line = "#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR\n\n#{processed_line}\n#endif /* TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR */\n"
                  end
                else
                    puts "Skipping #{headerFile}"
                    non_prefixed_methods = nil
                    return
                end
            end
        end

        if processed_line == nil
            if line.start_with?("@end")
                processed_line = "@end\n"
            end
        end

        unless processed_line == nil
            non_prefixed_methods << processed_line
        end
    }

    non_prefixed_methods.compact
end

def processHeader(headerFile)
    unless headerFile.end_with? ".h"
        puts "#{headerFile} not a header"
        return
    end

    puts "Reading #{headerFile}"

    method_match_expression = /^(?<Start>[\+|\-]\s*\([a-zA-Z\s\*]*\)\s*)(?<MethodName>\w+)(?<End>\:?.*)/
    category_match_expression = /^\s*(?<Interface>@[[:alnum:]]+)\s*(?<ObjectName>[[:alnum:]]+)\s*(\((?<Category>\w+)\))?/

    lines = File.readlines(headerFile)
    non_prefixed_methods = []
    processed_methods_count = 0
    objects_to_process = ["NSManagedObject", "NSManagedObjectContext", "NSManagedObjectModel", "NSPersistentStoreCoordinator", "NSPersistentStore"]

    lines.each { |line|
        processed_line = nil
        if line.start_with?("@interface")
            matches = category_match_expression.match(line)
            if objects_to_process.include?(matches[:ObjectName])
                processed_line = "\n#{matches[:Interface]} #{matches[:ObjectName]} (#{matches[:Category]}ShortHand)\n"
            else
                puts "Skipping #{headerFile}"
                non_prefixed_methods = nil
                return
            end
        end

        if processed_line == nil
            matches = method_match_expression.match(line)

            if matches
                if matches[:MethodName].start_with?("MR_")
                    ++processed_methods_count
                    methodName = matches[:MethodName].sub("MR_", "")
                    methodStart = matches[:Start].gsub(/^([\-|\+]).*/, '\1')
                    methodEnd = matches[:End]

                    methodSuffix = nil
                    unless methodEnd.include? "MRDeprecated"
                      methodEnd = methodEnd.sub(";", '')
                      deprecationNoticeMethod = methodEnd.gsub(/:(\([^\)]+\)[\w]+)|:(\(.+)/, ':')
                      deprecationNoticeMethod = deprecationNoticeMethod.gsub(/:\s/, ':')
                      deprecationNoticeMethod = deprecationNoticeMethod.gsub(/ NS_[^\s]+/, '')
                      deprecationNoticeMethod = deprecationNoticeMethod.gsub(/;$/, '')

                      methodSuffix = " MRDeprecated(\"Use #{methodStart}#{matches[:MethodName]}#{deprecationNoticeMethod} instead\");"
                    end

                    processed_line = "#{matches[:Start]}#{methodName}#{methodEnd}#{methodSuffix}"

                    if processed_line.include? "NSFetchedResultsController"
                      processed_line = "\n#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR\n\n#{processed_line}\n\n#endif /* TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR */"
                    end
                else
                    puts "Skipping #{headerFile}"
                    non_prefixed_methods = nil
                    return
                end
            end
        end

        if processed_line == nil
            if line.start_with?("@end")
                processed_line = "\n@end\n"
            end
        end

        unless processed_line == nil
            non_prefixed_methods << processed_line
        end
    }

    non_prefixed_methods.compact
end

def processDirectoryForHeaders(path)

    headers = File.join(path, "**", "*+*.h")
    processedHeaders = []

    Dir.glob(headers).each { |file|
        puts "Processing #{file}"

        processDirectory(file) if File.directory?(file)
        if file.end_with?(".h")
            processedHeaders << processHeader(file)
        end
    }

    processedHeaders
end

def processDirectoryForImplementations(path)

    headers = File.join(path, "**", "*+*.h")
    processedHeaders = []

    Dir.glob(headers).each { |file|
        puts "Processing #{file}"

        processDirectory(file) if File.directory?(file)
        if file.end_with?(".h")
            processedHeaders << processImplementation(file)
        end
    }

    processedHeaders
end


def generateHeaders(startingPoint)

    processedHeaders = []
    if startingPoint
        path = File.expand_path(startingPoint)

        if path.end_with?(".h")
            processedHeaders << processHeader(path)
        else
            puts "Processing Headers in #{path}"
            processedHeaders << processDirectoryForHeaders(path)
        end

    else
        processedHeaders << processDirectoryForHeaders(startingPoint || Dir.getwd())
    end

    processedHeaders
end

def generateImplementations(startingPoint)

    processedHeaders = []
    if startingPoint
        path = File.expand_path(startingPoint)

        if path.end_with?(".h")
            processedHeaders << processImplementation(path)
        else
            puts "Processing Headers in #{path}"
            processedHeaders << processDirectoryForImplementations(path)
        end

    else
        processedHeaders << processDirectoryForImplementations(startingPoint || Dir.getwd())
    end

    processedHeaders
end


puts "Input dir: #{File.expand_path(ARGV[0])}"

output_file = ARGV[1]
puts "Output file: #{File.expand_path(output_file)}"

unless output_file
    puts "Need an output file specified"
    return
else
    puts "Generating shorthand headers"
end

headers = generateHeaders(ARGV[0]).collect &:compact
implementations = generateImplementations(ARGV[0]).collect &:compact

File.open("#{output_file}.h", "w") { |file|
    file.write("#ifdef MR_SHORTHAND\n\n")
    file.write("#import \"MagicalRecordDeprecated.h\"\n")
    file.write("#import \"NSManagedObjectContext+MagicalSaves.h\"\n\n")
    file.write(headers.compact.join("\n"))
    file.write("#endif\n")
}

File.open("#{output_file}.m", "w") { |file|
    file.write("#ifdef MR_SHORTHAND\n\n")
    file.write("#import \"#{output_file}.h\"\n")
    file.write("#import \"CoreData+MagicalRecord.h\"\n\n")
    file.write(implementations.compact.join("\n"))
    file.write("#endif\n")
}