require 'observable'

# Using one proc per object, per attr can be costly.

class Observed
  extend Observable

  30.times do |i|
    attr_accessor "attr_#{i}"
  end
end

puts `ps -p #{$$} -ovsz=`

class Observed
  # Now make them all observable
  30.times do |i|
    observable "attr_#{i}"
  end
end

ary = (0...10_000).map do |obj_idx|
  obj = Observed.new
  30.times do |i|
    obj.send "when_attr_#{i}", Object do
      # don't do anything, just construct a string
      "attr_#{i} in object #{obj_idx} changed"
    end
  end
end

puts `ps -p #{$$} -ovsz=`

__END__

result:

  3908
  6176
