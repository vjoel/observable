require 'observable'

# Let's just include Observable globally. Conservatively, one would do:
#
#   class C
#     extend Observable
#     include Observable::Match   # if desired
#     ...
#   end

include Observable
include Observable::Match

module VerySimpleSignalExample
  # compare with VerySimpleExample in examples.rb

  class Observee
    signal :reaches_target
    
    def initialize
      @clicks = 0
    end

    def run n
      n.times do
        @clicks += 1
        if @clicks == 3 or @clicks == 7
          self.reaches_target = @clicks
          # observee decides when to signal
        end
      end
    end
  end

  class Observer
    def initialize observee, target_clicks
      observee.when_reaches_target target_clicks do |n|
        puts "Reached target of #{n} clicks."
      end
    end
  end

  observee = Observee.new

  Observer.new(observee, 3)
  Observer.new(observee, 7)

  observee.run 10

  # Output:
  # Reached target of 3 clicks.
  # Reached target of 7 clicks.

end

module OpenFileExample
# A more typical use of signals
  
  class FilePicker
    signal :file_chosen
    def run
      self.file_chosen = "foo"
    end
  end
  
  class FileOpener
    def initialize file_picker
      file_picker.when_file_chosen do |file|
        puts "FileOpener: opening file #{file}."
      end
    end
  end
  
  picker = FilePicker.new
  opener = FileOpener.new(picker)
  picker.run
  p picker.file_chosen  # signal has passed by now
  
  # Output:
  # FileOpener: opening file foo.
  # nil
  
end
