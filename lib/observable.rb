class Object
  def handle_observer_exception exception, var, pattern
    insp = inspect rescue self.class.name
    exception.message << \
      "\n    " +
      "In observer #{insp} when value of variable `#{var}' " +
      "matched pattern #{pattern.inspect}\n"
    raise
  end
end

module Observable ## Maybe this should be ObservableAttribute
private

  class ObserverMap < Hash
    def marshal_dump
      {}
    end
    
    def marshal_load(obj)
    end
    
    def to_yaml( opts = {} )
      if empty?
        super
      else
        ObserverMap.new.to_yaml
      end
    end
  end

  def each_variable_in(vars)
    for var in vars
      unless instance_methods(true).include? "when_#{var}"
        unless instance_methods(true).include?(var.to_s)
          class_eval %{attr_reader :#{var}}
        end

        writer = "#{var}="
        if instance_methods(false).include?(writer)
          real_writer = "___#{var}___writer___"
          alias_method real_writer.intern, writer.intern
        elsif instance_methods(true).include?(writer)
          real_writer = "super"
        else
          real_writer = "@#{var}="
        end
        
        yield var, writer, real_writer

      end
    end
  end

  def observable_state(*vars)
    each_variable_in(vars) do |var, writer, real_writer|
      add_observable_state_methods var, writer, real_writer
      add_observer_methods var
    end
  end
  alias :observable :observable_state
  
  def observable_signal(*vars)
    each_variable_in(vars) do |var, writer, real_writer|
      add_observable_signal_methods var, writer, real_writer
      add_observer_methods var
    end
  end
  alias :signal :observable_signal

  def add_observable_state_methods var, writer, real_writer
    class_eval %{
      def #{writer} value
        old_value = #{var}
        unless value == old_value
          #{real_writer} value
          if defined?(@#{var}__observer_map) and @#{var}__observer_map
            observer_map = @#{var}__observer_map
            for (observer, pattern), block in observer_map
              if pattern === value
                begin
                  case block.arity
                  when 1,-1
                    block[value]
                  when 2
                    block[value, old_value]
                  when 3
                    block[value, old_value, self]
                  when 4
                    block[value, old_value, self, :#{var}]
                  else
                    block[value, old_value, self, :#{var}]
                  end
                rescue Exception => e
                  ok = observer.handle_observer_exception(e, '#{var}', pattern)
                  observer_map.delete([observer, pattern]) unless ok
                end
              end
            end
          end
        end
      end

      def when_#{var} pattern=Object, &block
        observer_map = @#{var}__observer_map ||= ObserverMap.new
        if block
          observer = eval "self", block.binding
          observer_map[[observer, pattern]] = block

          value = #{var}

          if pattern === value # is there already a match?
            begin
              case block.arity
              when 1,-1
                block[value]
              when 2
                block[value, nil]
              when 3
                block[value, nil, self]
              when 4
                block[value, nil, self, :#{var}]
              else
                block[value, nil, self, :#{var}]
              end
            rescue Exception => e
              ok = observer.handle_observer_exception(e, '#{var}', pattern)
              observer_map.delete([observer, pattern]) unless ok
            end
          end
        else
          $stderr.puts "Observable: warning: no block given for:\n" +
                       "when_#{var} \#\{pattern.inspect\}"
        end
      end
    }
  end
  
  class SignalReentrancyError < StandardError; end
  
  def add_observable_signal_methods var, writer, real_writer
    class_eval %{
      def #{writer} value
        if value
          if #{var}
            raise SignalReentrancyError, "signal is not reentrant."
          end
          #{real_writer} value
          observer_map = @#{var}__observer_map
          if observer_map
            for (observer, pattern), block in observer_map
              if pattern === value
                begin
                  block[value]
                rescue Exception => e
                  ok = observer.handle_observer_exception(e, '#{var}', pattern)
                  observer_map.delete([observer, pattern]) unless ok
                end
              end
            end
          end
          #{real_writer} nil
        end
      end

      def when_#{var} pattern=Object, &block
        observer_map = @#{var}__observer_map ||= {}
        if block
          observer = eval "self", block.binding
          observer_map[[observer, pattern]] = block
        else
          $stderr.puts "Observable: warning: no block given for:\n" +
                       "when_#{var} \#\{pattern.inspect\}"
        end
      end
    }
  end

  def add_observer_methods var
    ## These methods do not work over a drb connection because the
    ## stored observer is obtained from 'eval "self", block', which
    ## will not match the observer argument to cancel_when_ or
    ## remove_observer_
    class_eval %{
      def cancel_when_#{var} pattern, observer
        observer_map = @#{var}__observer_map
        observer_map.delete [observer, pattern] if observer_map
      end
      def remove_observer_#{var} observer
        observer_map = @#{var}__observer_map
        if observer_map
          observer_map.delete_if {|(obs, pat), action| obs == observer}
        end
      end
    }
  end
  
  module Match
    # Some constants, classes, and functions for matching

    BOOLEAN = Object.new
    def BOOLEAN.===(value)
      value == true || value == false
    end

    class MatchProc < Proc
      def ===(arg)
        call(arg)
      end
    end
    
    EQUAL = proc { |value|
      MatchProc.new { |test_value| test_value == value }
    }

    NOT_EQUAL = proc { |value|
      MatchProc.new { |test_value| test_value != value }
    }

    NOT_MATCH = proc { |value|
      MatchProc.new { |test_value| !(value === test_value) }
    }

#    def EQUAL value
#      MatchProc.new { |test_value| test_value == value }
#    end
#
#    def NOT_EQUAL value
#      MatchProc.new { |test_value| test_value != value }
#    end
#
#    def NOT_MATCH value
#      MatchProc.new { |test_value| !(value === test_value) }
#    end

#    CHANGES = MatchProc.new {true}
    CHANGES = Object   # simpler!
    EXISTS = MatchProc.new {|v| v}

  end
end
