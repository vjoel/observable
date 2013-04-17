require 'observable'

include Observable
include Observable::Match

class Stock
  extend Observable
  
  observable :price
  
  def initialize price
    @price = price
  end
  
  def sell
    puts "selling at #{price}"
  end
end

class StockWatcher
  GREATER_THAN = proc do |price|
    MatchProc.new { |test_price| test_price > price }
  end
  
  def initialize(stock)
    stock.when_price CHANGES do |price, old_price|
      puts "price = #{price}  (was #{old_price.inspect})"
    end
    
    stock.when_price GREATER_THAN[20] do
      stock.sell
    end
  end
end

acme = Stock.new(10)
watcher = StockWatcher.new(acme)

10.step(30, 5) do |n|
  acme.price = n
  puts "---"
end
