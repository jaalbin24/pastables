#!/usr/bin/env ruby
class Target
  @@all = []
  attr_accessor :num, :port, :ip, :username, :password, :source, :destinations
  def initialize
    @@all << self
    self.destinations = []
  end
  def to_s
    "T#{num.nil? ? "?" : num} (#{ip.nil? ? "??.??.??.??" : ip}:#{port.nil? ? "??" : port}) // #{username.nil? ? "???????" : username}::#{password.nil? ? "????????" : password}"
  end
  def connects_to(target)
    self.destinations.append target
    target.source = self
  end
  def disconnect()
    og_source = self.source
    self.source = nil
    return if og_source.nil?
    og_source.destinations.delete(self)
  end
  def remove()
    self.disconnect
    self.destinations.each do |target|
      target.source = nil
    end
    Target.all.delete self
  end
  def self.all
    @@all
  end
  def self.find_by_num(i)
    Target.all.select{ |target| target.num.to_s == i.to_s }[0]
  end
end

def main_menu()
  header "Main Menu", show_targets: true, show_scheme: true
  puts "What do you want to do?"
  puts "1) Add a new target"
  puts "2) Remove a target" unless Target.all.empty?
  puts "3) Add an SSH connection" if Target.all.size >= 2
  puts "4) Remove an SSH connection" unless Target.all.select { |target| target.source != nil }[0].nil?
  # puts "finished) All done! Build my cutsheet now.\n\n"
  get_user_choice "Enter a number to choose an option#{" or type 'finished' to generate your cutsheet" unless Target.all.empty? }." do |user_choice|
    case user_choice
    when "1"
      add_target_menu
    when "2"
      raise StandardError.new "That is not a valid choice." if Target.all.empty?
      remove_target_menu
    when "3"
      raise StandardError.new "That is not a valid choice." unless Target.all.size >= 2
      add_connection_menu
    when "4"
      raise StandardError.new "That is not a valid choice." if Target.all.select { |target| target.source != nil }[0].nil?
      remove_connection_menu
    when "finished"
      print_cutsheet
      return "ALL DONE"
    else
      main_menu
      raise StandardError.new "That is not a valid choice."
    end
  end
end

def add_target_menu()
  target = {}
  header "Add a Target", show_targets: true
  get_user_choice "What is the TARGET NUMBER?" do |user_choice|
    raise StandardError.new "You must enter a number." unless user_choice.match /\A\d+\z/
    raise StandardError.new "That target already exists" unless Target.find_by_num(user_choice).nil?
    target[:num] = user_choice.to_i
    get_user_choice "What is the IP ADDRESS of target #{target[:num]}?" do |user_choice|
      raise StandardError.new "That is not a valid IP address." unless user_choice.match /\b(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/
      target[:ip] = user_choice
      get_user_choice "What PORT does target #{target[:num]} use for SSH?" do |user_choice|
        raise StandardError.new "You must enter a number." unless user_choice.match /\A\d+\z/
        target[:port] = user_choice
        get_user_choice "What USERNAME will you use to SSH to target #{target[:num]}?" do |user_choice|
          raise StandardError.new "You must enter a username." if user_choice.strip.empty?
          target[:username] = user_choice
          get_user_choice "What PASSWORD will you use to SSH to target #{target[:num]}?" do |user_choice|
            raise StandardError.new "You must enter a password." if user_choice.strip.empty?
            target[:password] = user_choice
          end
        end
      end
    end
  end
  unless target.values.select { |v| v.nil?}.empty?
    Target.new.tap { |t| t.num = target[:num]; t.port = target[:port]; t.ip = target[:ip]; t.username = target[:username]; t.password = target[:password] }
  end
end

def remove_target_menu()
  header "Remove a Target", show_targets: true
  puts "Which target do you want to remove?"
  print_targets
  get_user_choice "Enter a number." do |user_choice|
    target = Target.find_by_num(user_choice)
    raise StandardError.new "You must enter a valid target number." if target.nil?
    target.remove
  end
end

def add_connection_menu()
  connection = { source: nil, destination: nil}
  header "Add a Connection", show_scheme: true
  puts "What target will you connect from?"
  print_targets
  get_user_choice "Enter a number." do |user_choice|
    connection[:source] = user_choice
  end
  puts "What target will you connect to?"
  print_targets
  get_user_choice "Enter a number." do |user_choice|
    connection[:destination] = user_choice
  end
  Target.find_by_num(connection[:source]).connects_to(Target.find_by_num(connection[:destination]))
end

def remove_connection_menu()
  header "Remove a Connection", show_scheme: true
  puts "Which connection do you want to remove?"
  Target.all.each_with_index do |target, i|
    puts "#{i+1}) #{target.source.nil? ? "OPS" : "T#{target.source.num}"} =========> T#{target.num}"
  end
  get_user_choice "Enter a number." do |user_choice|
    raise StandardError.new "That is not a valid number." if user_choice.to_i > Target.all.size
    Target.all.each_with_index do |target, i|
      if i+1 == user_choice.to_i
        target.disconnect
        break
      end
    end
  end
end

def print_targets(opts={numbered: true, detailed: false})
  if opts[:numbered]
    Target.all.sort_by{ |t| t.num.nil? ? 99999 : t.num }.each_with_index { |t, i| puts "#{t.num}) T#{t.num}" }
  elsif opts[:detailed]
    Target.all.sort_by{ |t| t.num.nil? ? 99999 : t.num }.each { |t| puts t }
  else
    Target.all.sort_by{ |t| t.num.nil? ? 99999 : t.num }.each { |t| puts "T#{t.num}" }
  end
end

def banner(title)
  banner_length = 60
  padded_title_length = title.length + 2
  side_length = (banner_length - padded_title_length) / 2
  puts "#" * side_length + " #{title} " + "#" * side_length + "#" * (banner_length % 2)
end

def header(title, opts={show_targets: false, show_scheme: false})
  system("clear")
  if opts[:show_scheme]
    scheme = recursively_build_scheme
    unless scheme.nil?
      banner "YOUR CURRENT SCHEME OF MANEUVER"
      print_scheme scheme
    end
  end
  if opts[:show_targets]
    unless Target.all.empty?
      banner "YOUR TARGETS"
      print_targets detailed: true
    end
  end
  banner title
end

def get_user_choice(prompt, *error_message, &block)
  puts
  puts error_message if error_message
  puts "#{prompt} ('b' to go back)"
  print "> "
  user_choice = gets.chomp
  return if user_choice.downcase == "b"
  if block_given?
    begin
      yield user_choice
    rescue => e
      get_user_choice prompt, "ERROR: #{e.message}", &block
    end
  end
end

def recursively_build_scheme(targets=Target.all, parent=nil)
  return nil if targets.empty?
  children = targets.sort_by{ |t| t.num.nil? ? 99999 : t.num }.select { |target| target.source ==  parent }
  if children.empty?
    return nil
  else
    scheme = {}
    children.sort_by{ |t| t.num.nil? ? 99999 : t.num }.each do |child|
      scheme[child&.num] = recursively_build_scheme(targets - children, child)
    end
    scheme
  end
end

def print_scheme(scheme, depth=0)
  return if scheme.nil? || scheme.empty?
  scheme.each do |k, v|
    target = Target.find_by_num(k)
    puts "#{"=" * depth}> T#{k} (#{target.ip}:#{target.port}) // #{target.username}::#{target.password}"
    print_scheme(v, depth + 1) if v.is_a?(Hash)
  end
end

def recursively_generate_cutsheet(target=nil)
  commands = ""
  if target.nil? # there is no target
    # find the targets that connect to the ops station
    children = Target.all.select { |t| t.source.nil? }
    children.each do |child|
      commands += recursively_generate_cutsheet child
    end
  else
    # Connect to it
    commands += "# CONNECT TO T#{target.num}\n"
    commands += "KALI> ssh -M -S /tmp/T#{target.num} #{target.username}@#{target.source.nil? ? target.ip : "127.0.0.1"} -p #{target.source.nil? ? target.port : "1000#{target.num}"} -o StrictHostKeyChecking=no and -o UserKnownHostsFile=/dev/null\n"
    commands += "# ENTRY VET T#{target.num}\n"
    commands += "# PERFORM T#{target.num} ACTIONS\n"
    unless target.destinations.empty? # if the target has children
      target.destinations.each do |child|
        commands += "# CONFIGURE FORWARD TO T#{child.num}\n"
        commands += "KALI> ssh -S /tmp/T#{child.source.num} dummy -O forward -L 127.0.0.1:1000#{child.num}:#{child.ip}:#{child.port}\n"
        commands += recursively_generate_cutsheet child
      end
    end
    commands += "# EXIT VET T#{target.num}\n"
    commands += "# DISCONNECT FROM T#{target.num}\n"
    commands += "T#{target.num}> exit\n"
    commands += "KALI> ssh -S /tmp/T#{target.source.num} dummy -O cancel -L 127.0.0.1:1000#{target.num}:#{target.ip}:#{target.port}\n" unless target.source.nil?
  end
  commands
end

def print_cutsheet
  cutsheet = recursively_generate_cutsheet
  filename = "cutsheet_#{Time.now.strftime("%d%b%y")}_#{Time.now.to_i}.txt"
  File.open(filename, "w") do |file|
    file.puts "# BEGIN OPERATION"
    file.puts cutsheet
    file.puts "# END OPERATION"
  end
  puts cutsheet
  puts "Your cutsheet has been saved at ./#{filename}"
end

#### Uncomment and edit these lines to auto-populate some targets (useful for protecting against accidental loss while running) ######
t1 = Target.new.tap { |t| t.num = 1; t.port = 22; t.ip = "192.168.0.1"; t.username = "student"; t.password = "password" }
t2 = Target.new.tap { |t| t.num = 2; t.port = 22; t.ip = "192.168.0.2"; t.username = "student"; t.password = "password" }
t3 = Target.new.tap { |t| t.num = 3; t.port = 22; t.ip = "192.168.0.3"; t.username = "student"; t.password = "password" }
t4 = Target.new.tap { |t| t.num = 4; t.port = 22; t.ip = "192.168.0.4"; t.username = "student"; t.password = "password" }
t5 = Target.new.tap { |t| t.num = 5; t.port = 22; t.ip = "192.168.0.5"; t.username = "student"; t.password = "password" }

t1.connects_to t2
t2.connects_to t3
t3.connects_to t4
t2.connects_to t5
#### Uncomment and edit these lines to auto-populate some targets (useful for protecting against accidental loss while running) ######

exit_condition = "NOT DONE"
while exit_condition != "ALL DONE" do
  exit_condition = main_menu
end
