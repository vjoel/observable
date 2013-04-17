require 'observable'

# Using one proc per attr reduces memory cost. This uses the third argument
# of the proc in the when clause to abstract the proc from the object being
# observed.

class Observed
  extend Observable

  30.times do |i|
    attr_accessor "attr_#{i}"
  end

  attr_reader :name

  def initialize name
    @name = name
  end
end

puts `ps -p #{$$} -ovsz=`

class Observed
  # Now make them all observable
  30.times do |i|
    observable "attr_#{i}"
  end
end

procs = (0...30).map do |i|
  proc do |new_val, old_val, obj|
    "attr_#{i} in object #{obj.name} changed"
  end
end

ary = (0...10_000).map do |obj_idx|
  obj = Observed.new(obj_idx)
  30.times do |i|
    obj.send "when_attr_#{i}", &procs[i]
  end
end

puts `ps -p #{$$} -ovsz=`

__END__

result:

  3904
  5072
