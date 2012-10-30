#!/usr/bin/env ruby

require 'yaml'
require 'mysql'
 
module Jekyll
    module WordPress
        def self.read_posts dir
            Dir.glob("#{dir}/*").each_with_object({}) do |f, h|
                if File.file?(f)
                    data = YAML.load_file(f)
                    data_length = YAML.dump(data).length

                    file = File.open(f)
                    # add the length of the end of YAML separator
                    # "---\n" = 4 chars
                    file.seek(data_length+4)
                    content = file.read
                    if content.respond_to?(:force_encoding)
                        content.force_encoding("UTF-8")
                    end

                    filename = File.basename(f, File.extname(f))
                    date = filename.split('-')[0..2]
                    slugged_title = filename.split('-')[3..-1]

                    data['date'] = date.join('-')
                    data['title'] = slugged_title.join(' ') if data['title'].nil? 

                    h[f] = {
                        :data => data,
                        :data_length => data_length,
                        :content => content,
                    }
                elsif File.directory?(f)
                    h[f] = read_posts(f)
                end
            end
        end

        def self.insert_post( data, content ) 

            px = $config['db']['table_prefix']
            slug = self.sluggify(data['title'])
            status = "draft"
            status = "publish" if data['published'] 

            posts_query = "
                INSERT INTO #{px}posts (
                    ID,
                    post_type,
                    post_status,
                    post_date,
                    post_title,
                    post_name,
                    post_content
                ) VALUES (
                    null,
                    'post',
                    '"+$dbh.quote(status)+"',
                    '"+$dbh.quote(data['date'])+"',
                    '"+$dbh.quote(data['title'])+"',
                    '"+$dbh.quote(slug)+"',
                    '"+$dbh.quote(content)+"'
                )"

            res = $dbh.query(posts_query)
        end

        def self.sluggify( title )
            begin
                require 'unidecode'
                title = title.to_ascii
            rescue LoadError
                STDERR.puts "Could not require 'unidecode'. "
                    +" If your post titles have non-ASCII characters, "
                    +" you could get nicer permalinks by installing unidecode."
            end
            title.downcase.gsub(/[^0-9A-Za-z]+/, " ").strip.gsub(" ", "-")
        end

    end
end

$config = {}
if File.exists?('config.yml') 
    $config = YAML.load_file('config.yml')
else 
    puts "no config.yml file"
end

if $config['db'].nil? && ARGV.length < 2 then
    puts "Usage: "+__FILE__+" <postsdir>"
    exit
end

dir = ARGV[0] 

$dbh = Mysql.real_connect(
    $config['db']['host'], 
    $config['db']['user'], 
    $config['db']['pass'], 
    $config['db']['name'], 
    $config['db']['port'], 
    $config['db']['socket'])

$dbh.query("SET NAMES 'utf8'");

Jekyll::WordPress.read_posts(dir).each do |f,o|
   Jekyll::WordPress.insert_post(o[:data], o[:content]) 
end
