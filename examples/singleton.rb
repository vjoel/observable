require 'observable'

include Observable
include Observable::Match

object = Object.new
class << object
  observable :x
end

object.when_x CHANGES do |x|
  puts "object.x = #{x.inspect}"
end

object.x = 3
object.x = "foo"

