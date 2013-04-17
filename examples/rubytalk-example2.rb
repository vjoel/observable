  require 'observable'

  # A prexisting class with a method that doesn't expect to be observed.
  class Base
    attr_writer :foo
  end
  
  class Speaker < Base
    extend Observable
    
    # make the inherited method :foo be observable and define an
    # additional observable attribute, :bar.
    observable :foo, :bar
    
    def run
      self.foo = "1"
      self.bar = [4,5,6]
      self.foo = "2"
      self.bar << 7 # Caution: no notification here!
      self.bar += [8] # notification
      self.foo = "3"
      @foo = "4" # No notification here, since writer wasn't called
    end
  end

  class Listener
    def initialize(speaker)
      speaker.when_foo /2/ do |v|
        puts "#{self} saw foo change to have a 2 in #{v.inspect}"
      end
      
      speaker.when_foo /\d/ do |v|
        puts "#{self} saw foo change to have a digit in #{v.inspect}"
      end
      
      # This would override the first when_foo clause
      #speaker.when_foo /2/ do |v|
      #  puts "#{self} saw foo change to have a 2 in #{v.inspect} [overridden]"
      #end
      
      # listen for _any_ changes (note that #=== is used to match value,
      # so Object matches everything, including the initial nil)
      speaker.when_bar Object do |v, old_v|
        puts "#{self} saw bar change from #{old_v.inspect} to #{v.inspect}"
      end
    end
  end

  sp = Speaker.new
  Listener.new(sp)
  sp.run
  
__END__

Output:

#<Listener:0xb7a56628> saw bar change from nil to nil
#<Listener:0xb7a56628> saw foo change to have a digit in "1"
#<Listener:0xb7a56628> saw bar change from nil to [4, 5, 6]
#<Listener:0xb7a56628> saw foo change to have a 2 in "2"
#<Listener:0xb7a56628> saw foo change to have a digit in "2"
#<Listener:0xb7a56628> saw bar change from [4, 5, 6, 7] to [4, 5, 6, 7, 8]
#<Listener:0xb7a56628> saw foo change to have a digit in "3"
