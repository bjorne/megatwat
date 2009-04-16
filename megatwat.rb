require 'twitter'
require 'time'
require 'yaml'
require 'htmlentities'
require 'iconv'

@coder = HTMLEntities.new

config = YAML.load_file('config.yml')
@config = config['config']

unless @config['username'] and @config['password'] and @config['timestamp_file'] and @config['interval']
  puts "ERROR: username or password or timestamp_file or interval not set in config.yml"
  exit 
end

# read a timestamp if the timestamp file exists, otherwise set timestamp to past time
# 2*interval, not too long ago (to stop it from answering very old replies)
@last_timestamp = File.exists?(@config['timestamp_file']) ? Time.parse(File.new(@config['timestamp_file'], 'r').gets) : Time.now - 2*@config['interval']

puts ">> Last timestamp: #{@last_timestamp}"
puts ">> Bot loaded."

io = open("|./megahal-9.1.1/megahal -bwp 2> /dev/null", 'r+')

puts ">> MegaHAL greeting: #{io.gets}" 
puts ">> MegaHAL possibly loaded." 

# io.write("roine roine mrscream\n\n")
# puts "waited"
# puts io.gets

while true
  
  if @last_timestamp > Time.now - @config['interval']
    puts ">> Sleeping #{@config['interval']} seconds."
    sleep @config['interval']
  end

  puts ">> Checking new replies."

  httpauth = Twitter::HTTPAuth.new(@config['username'], @config['password'])
  base = Twitter::Base.new(httpauth)

  base.replies.each do |tweet| 
    next if Time.parse(tweet.created_at) < @last_timestamp
    
    puts ">> Answering reply by #{tweet.user.screen_name}: #{tweet.text}."
    
    # tell megahal about the text
    puts ">> debug: response text: '" + tweet.text.gsub(/\@#{@config['username']}/, '') + "\n\n" + "'"
    io.write(tweet.text.gsub(/^\@#{@config['username']} /, '') + "\n\n")
    # get response and reply
    reply = io.gets
    File.open('last_reply.txt', 'w') {|f| f.write(reply) }
    retweet = base.update("@#{tweet.user.name} #{Iconv.iconv('ISO-8859-1//IGNORE//TRANSLIT', 'UTF-8', reply)}", { :in_reply_to_status_id => tweet.id })
    
    puts ">> Answered with tweet #{retweet.id}."
  end
  
  @last_timestamp = Time.now
  File.open(@config['timestamp_file'], 'w') {|f| f.write(@last_timestamp) }
  
end
#base.update('Updating from ruby, yay!')

io.puts '#QUIT'
io.close