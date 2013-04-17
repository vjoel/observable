  require 'observable'

  class Speaker
    extend Observable
    observable :foo
    def run
      self.foo = "1"
      self.foo = "2"
      self.foo = "3"
    end
  end

  class Listener
    def initialize(speaker)
      speaker.when_foo /2/ do |v|
        puts "#{self} saw a 2 in #{v.inspect}"
      end
      speaker.when_foo /\d/ do |v|
        puts "#{self} saw a digit in #{v.inspect}"
      end
      # This would override the first when_foo clause
      #speaker.when_foo /2/ do |v|
      #  puts "#{self} overridden"
      #end
    end
  end

  spk = Speaker.new
  2.times {Listener.new(spk)}

  spk.run
