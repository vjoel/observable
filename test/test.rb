#!/usr/bin/env ruby

require 'test/unit'
require 'observable'

include Observable
include Observable::Match

class Test_Observable < Test::Unit::TestCase

  class Observee
    observable :clicks

    def initialize
      @clicks = "0"
    end

    def run n
      n.times do
        self.clicks = clicks.succ    # invoke the writer method
      end
    end
  end

  class Observer
    attr_reader :first_observed_count
    def initialize observee, target_clicks
      observee.when_clicks target_clicks do |n|
        @first_observed_count ||= n
      end
    end
  end

  def test_observable
    observee = Observee.new
    literal_observer = Observer.new(observee, "7")
    regex_observer   = Observer.new(observee, /\d\d/)

    observee.run 20
    
    assert_equal("7", literal_observer.first_observed_count)
    assert_equal("10", regex_observer.first_observed_count)
  end
  
  def test_redefine
    worked = false
    
    observee = Observee.new
    observer = Observer.new(observee, "7")
    observer.instance_eval do
      observee.when_clicks "7" do
        worked = true
      end
    end
    
    observee.run 20
    
    # First when_clicks "7" clause is removed:
    assert_equal(nil, observer.first_observed_count)
    
    # Second when_clicks "7" clause works.
    assert_equal(true, worked)
  end
  
  def test_arity
    clicks, old_clicks, observed, attribute = nil
    
    observee = Observee.new
    observee.when_clicks "7" do |value, old_value|
      clicks, old_clicks = value, old_value
    end
    observee.when_clicks "8" do |value, old_value, obs|
      observed = obs
    end
    observee.when_clicks "9" do |value, old_value, obs, attr|
      attribute = attr
    end
    
    observee.run 20
    
    assert_equal("6", old_clicks)
    assert_equal("7", clicks)
    assert_equal(observee, observed)
    assert_equal("clicks", attribute.to_s)
  end
  
  def test_cancel
    observee = Observee.new
    observer = Observer.new(observee, "7")
    observee.cancel_when_clicks "7", observer

    observee.run 20
    
    assert_equal(nil, observer.first_observed_count)
  end

  def test_remove_observer
    observee = Observee.new
    observer = Observer.new(observee, "7")
    observee.remove_observer_clicks observer

    observee.run 20
    
    assert_equal(nil, observer.first_observed_count)
  end
  
  def test_marshal
    failed = false
    observee = Observee.new
    observee.when_clicks "7" do
      failed = true
    end
    
    begin
      observee2 = Marshal.load(Marshal.dump(observee))
    rescue Exception => e
      flunk(e.to_s)
    end
    
    observee2.run 20
    assert_equal(false, failed)
  end
  
  if true
    warn "YAML serialization not supported--use Marshal instead"
  else
    def test_yaml
      require 'yaml'

      failed = false
      observee = Observee.new
      observee.when_clicks "7" do
        failed = true
      end

      begin
        observee2 = YAML.load(YAML.dump(observee))
      rescue Exception => e
        flunk(e.to_s)
        ### this fails because self is a key in the observer hash and self
        ### has a bunch of procs in it
      end

      observee2.run 20
      assert_equal(false, failed)
    end
  end

end

## need more tests
