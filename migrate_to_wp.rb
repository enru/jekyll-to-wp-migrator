#!/usr/bin/env ruby

require 'yaml'

dir = ARGV[0]

def read_posts dir
    Dir.glob("#{dir}/*").each_with_object({}) do |f, h|
        if File.file?(f)
            data = YAML.load_file(f)
            data_length = YAML.dump(data).length

            file = File.open(f)
            file.seek(data_length+4)
            content = file.read
            h[f] = {
                :data => data,
                :data_length => data_length,
                :content => content 
            }
        elsif File.directory?(f)
            h[f] = read_posts(f)
        end
    end
end

read_posts(dir).each do |f,o|
    p f
    p o[:data_length]
    p o[:data]
    p o[:content]
end
