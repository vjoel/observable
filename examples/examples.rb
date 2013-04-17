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

module VerySimpleExample

  class Observee
    observable :clicks

    def initialize
      @clicks = 0
    end

    def run n
      n.times do
        self.clicks += 1    # invoke the writer method
      end
    end
  end

  class Observer
    def initialize observee, target_clicks
      observee.when_clicks target_clicks do |n|
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

module MatchingExample

  class Observee
    observable :name
  end

  class Observer
    def initialize observee, pattern
      observee.when_name pattern do |name|
        puts "Hello, #{name}"
      end
    end
  end

  observee = Observee.new

  smith_observer = Observer.new observee, / Smith$/
  joe_observer   = Observer.new observee, /^Joe /

  observee.name = "Fred Smith"
  observee.name = "Fred Flintstone"
  observee.name = "Joe Flintstone"

  # Output:
  # Hello, Fred Smith
  # Hello, Joe Flintstone

end

module ExtendedMatchingExample

  class Observee
    observable :clicks

    def initialize
      @clicks = 0
    end

    def run n
      n.times do
        self.clicks += 1    # invoke the writer method
      end
    end
  end

  class Observer
    def initialize observee
      observee.when_clicks(MatchProc.new) do |n|
        puts "Reached target of #{n} clicks."
      end
    end
  end

  observee = Observee.new

  Observer.new(observee) {|n| n > 2 && n < 5}

  observee.run 10

  # Output:
  # Reached target of 3 clicks.
  # Reached target of 4 clicks.

end

module WindowToggleExample

  class Window
    observable :visible # true or false
  end

  class WindowVisibleMenuCmd
    def initialize window
      window.when_visible true do
        @checked = true
      end
      window.when_visible false do
        @checked = false
      end
      @window = window
    end

    def do_command
      @window.visible = !@checked
    end

    def inspect
      "menu is #{"not " if not @checked}checked" +
      " and window is #{"not " if not @window.visible}visible"
    end
  end

  window = Window.new
  window.visible = true

  menu_cmd = WindowVisibleMenuCmd.new window

  puts "Before command, " + menu_cmd.inspect
  menu_cmd.do_command
  puts "After command, " + menu_cmd.inspect

  # Output:
  # Before command, menu is checked and window is visible
  # After command, menu is not checked and window is not visible

end

module CycleExample

  class Gossip
    attr_accessor :friends
    observable :news

    def initialize
      @friends = []
      @news = "No news."
      when_news CHANGES do |new_value|
        @friends.each {|friend| friend.news = new_value}
      end
    end
  end

  g = (0..8).collect {Gossip.new}

  # make a complex network with cycles

  g[0].friends = [g[1], g[2]]
  g[1].friends = [g[3], g[4]]
  g[2].friends = [g[4], g[5]]
  g[3].friends = [g[0]]
  g[4].friends = [g[2]]
  g[5].friends = [g[3], g[6]]
  g[6].friends = [] # doesn't tell anyone (not strongly connected)
  g[7].friends = [] # nobody tells g[7] (not connected at all)
  g[8].friends = [g[0]] # nobody tells g[8], but g[8] would tell g[0]

  g[0].news = "I've got a girl and Ruby is her name."

  puts (0..g.size-1).map {|i| "g[#{i}].news = #{g[i].news.inspect}"}

  # Output:
  # g[0].news = "I've got a girl and Ruby is her name."
  # g[1].news = "I've got a girl and Ruby is her name."
  # g[2].news = "I've got a girl and Ruby is her name."
  # g[3].news = "I've got a girl and Ruby is her name."
  # g[4].news = "I've got a girl and Ruby is her name."
  # g[5].news = "I've got a girl and Ruby is her name."
  # g[6].news = "I've got a girl and Ruby is her name."
  # g[7].news = "No news."
  # g[8].news = "No news."

end

module ObserverScopeExample

  class Thing
    observable :x
    def initialize
      when_x CHANGES do |value|
        puts "#{self} notices that x changed to #{value.inspect}"
      end
    end
  end

  thing = Thing.new
  thing.when_x CHANGES do |value|
    puts "#{self} notices that x changed to #{value.inspect}"
  end

  thing.x = 2
  puts thing.x

  # Output:
  # #<ObserverScopeExample::Thing:0x401cab2c> notices that x changed to nil
  # ObserverScopeExample notices that x changed to nil
  # ObserverScopeExample notices that x changed to 2
  # #<ObserverScopeExample::Thing:0x401cab2c> notices that x changed to 2
  # 2

end

module ObservableMethodExample

  class Rectangle
    attr_reader :width, :height

    def initialize(w,h)
      @width, @height = w, h

      when_area CHANGES do
        puts "#{width} * #{height} = #{area}"
      end
    end

    def area
      @width * @height
    end

    # Keep proportions but change area.
    def area=(a)
      area_ratio = a.to_f/area
      side_ratio = Math.sqrt(area_ratio)
      @width  *= side_ratio
      @height *= side_ratio
      a
    end
    observable :area # do this after defining methods
  end

  r = Rectangle.new(3,4)
  r.area = 48

  # Output:
  # 3 * 4 = 12
  # 6.0 * 8.0 = 48.0

end

module SingletonObserveeExample

  x = Object.new

  class << x
    observable :y
  end

  x.when_y(CHANGES) {|value| puts "y changed to #{value.inspect} in x"}

  x.y = 3

  # Output:
  # y changed to nil in x
  # y changed to 3 in x 
end

module MatchProcExample
  class A
    observable :x
  end

  class B
    include Match
    def initialize(a)
      a.when_x EQUAL[3] do
        puts "x is 3"
      end
    end
  end

  a = A.new
  b = B.new(a)

  a.x = 2
  a.x = 3
  
  # Output:
  # x is 3
end
