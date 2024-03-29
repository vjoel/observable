# module Observable #

## Synopsis ##

```ruby
    require "observable"
    class Observed
      extend Observable
      observable :var
    end

    observed = Observed.new
    pattern = Object
    observed.when_var pattern do puts "changed" end   # ==> changed
    observed.var = 1                                  # ==> changed
```

### private instance methods ###

```ruby
    Module#observable <var>, ...
    Module#observable_state <var>, ...
```
   
Defines methods to expose state changes to observers. Each argument
`variable` is a name (string, symbol, etc.). Typically, the name
will correspond to an instance variable `variable`, as with
`attr_accessor`.

Adding an observable variable `var` to a class
`MyClass` (or to a module) is easy:

```ruby
    class MyClass
      extend Observable
      observable :var
    end
```

Four methods are defined for each argument: a reader, a writer, and methods 
for observers to register and unregister their interest in `var`.
Calling the writer method notifies observers of the new value, if it has
changed. Observers register their interest by using the `when_var`
method, and de-register using `cancel_when_var`.

The observable module method can be safely called more than once, so
subclasses don't need to know whether the superclass has called it.

```ruby
    Module#signal <var>, ...
    Module#observable_signal <var>, ...
```
   
Defines methods to expose signals to observers. Signals are general
transient events (or "impulses"), rather than transitions from one state to
another. The signal has a value only during notification.

The semantics of observable signals is the same as that of observable states
except:

* The signal variable is nil except while `when_` clauses are being
  handled as a result of assigning to the variable using its writer.

* Setting the variable to nil never has any effect, and no action is taken 
  when a `when_` clause is defined.

* There is no `old_value` available to `when_` clauses.

One advantage of signals over methods is that it is easy to use closures
`Proc`s) as the handlers. More importantly, signals decouple caller
and callee. The "caller" or sender of the signal doesn't need to know
who is observing.

### generated instance methods ###

```ruby
    MyClass#var
```
   
The reader method returns the value of the variable. Not generated for
signals, because signals have value only during the assignment operation
and the propagation of that event to observers.

Normally, the reader is the same as the method generated by 
`attr_reader`. If a method already exists with the name `var`, the
`observable` declaration uses the existing method. See the
`ObservableMethodExample`  in examples/examples.rb. Note that the
`observable` declaration must come after the definition of the reader
for it to be used in this way.

```ruby
    MyClass#var= value
```
   
The writer method, as with `attr_writer`, assigns `value` to the
instance variable. If there is a change, the writer checks if the change is
of interest to each observer and, if so, calls the observer's registered
code.

If a method already exists with the name `var`, the `observable`
declaration uses the existing method. See the `ObservableMethodExample`
in examples/examples.rb. Note that the `observable` declaration
must come after the definition of the writer for it to be used in this way.

By default, the writer is public, but it can of course be made private as
with any other method:

```ruby
    private :var=
```

Note that changing the instance variable directly, as in

```ruby
    @var = ...
```

does not cause notification.

```ruby
    MyClass#when_var pattern=Object do |value| ... end
    MyClass#when_var pattern=Object do |value, old_value| ... end
    MyClass#when_var pattern=Object do |value, old_value, obj| ... end
    MyClass#when_var pattern=Object do |value, old_value, obj, attr| ... end
```
   
The registration method takes a pattern (any object) and a block. When the
variable's value changes as a result of calling the writer, the pattern is
matched against the new value using `case` semantics (i.e., `===`.
If the match succeeds, the block is called with the new value as an
argument. If the block has a second argument, it is assigned the old value. 
The third argument is assigned the object being observed. This can be
useful to reduce the number of procs required to observe a large number
of objects. (See examples/mem-usage-*.rb.) The fourth argument is assigned
the name of the attr.

The match is also checked at the time of registration (that is, when
`when_var` is called). In this case, `old_value` is `nil`.

An observer's behavior can be changed simply by calling `when_var` again
with the same pattern and a different block. (The two blocks, the original
and the replacement, must have the same `self`, or else both blocks
apply.)

Observer blocks of an attribute are indexed by `[observer, pattern]`,
where  observer refers to the "self" of the block, and pattern is the
argument to `when_var(pattern)`. So as long as this pair differs, you can
register a different block.

So the following registers three blocks:

    a = AAA.new

    x = []
    x.instance_eval do
      a.when_name(/foo/) { } # pair is [x, /foo/]
      a.when_name(/bar/) { } # pair is [x, /bar/]
    end

    when_name(/foo/) {...}   # pair is [<toplevel object>, /bar/]

Note that `observable` can handle arbitrary cycles of observers. See the
`CycleExample` in `examples/examples.rb`.

The order in which action clauses happen is not specified.

Note that calling the writer with the current value has no effect--no
observers are notified. Notification happens only when there is a change in
the value. Hence the following code simply detects all changes:

```ruby
    observed.when_var Object do...end
```

This is in fact the default value for `pattern`.

`Warning`: the `when_` methods only detect changes resulting from
calling the writer method, as in `obj.var = ...`. Changes directly to
the instance variable do not trigger notification.

Also, changes to the internal state of the object do not trigger
notification. For instance,

```ruby
    observed.var = [1,2,3]    # triggers notification
    observed.var[1] = 0       # no notification
```

One way to force notification, is to assign nil to the variable and then
reassign the previous value.

```ruby
    observed.var = [1,2,3]    # triggers notification
    old_value = observed.var
    observed.var = nil        # notification of change to nil
    old_value[1] = 0          # no notification
    observed.var = old_value  # notification of change back to old_value
```

Of course, this will trigger two notifications. It would be possible to add
a method, perhaps called `var_changed`, which can be called after
changing an object's internal state, and which would notify observers just
once. But there is no way to tell the observer what the old value is, which
would break the semantics of any observer of the form 

```ruby
    observed.when_var ... do |value, old_value| ... end
```

It is therefore safer to use two notifications.

```ruby
    MyClass#cancel_when_var pattern, observer
```
   
An observer can be removed by calling `cancel_when_var` with
the same pattern and the observer. (The value of `observer` must be the
same as the `self` for the block in the original `when_var` call.)

```ruby
    MyClass#remove_observer_var observer
```
   
As above, but removes all actions for the specified observer, regardless of
pattern.

### Observable and Exceptions ###

An exception that occurs in an observer's action clause (the block of a
`when_var` would, if not handled, prevent other observers from being
notified of the change in value. One solution is to place rescue clauses in
every action clause that might generate an exception. Since this may be
impractical or (as in the DRb case discussed below) impossible, the
`Observable` library's call to the action clause is protected with a
`rescue` that catches all exceptions and passes them to the following
method of the observer:

```ruby
    Object#handle_observer_exception exception, var, pattern
```
   
The default behavior is to re-raise the exception with a more informative
message that mentions the +var+ and +pattern+.

Subclasses can of course redefine this method (see below for an example). If a
subclass implementation does not re-raise the exception, the return value
becomes significant. A return value of `true` instructs the
`Observable` library to ignore the exception and leave the observer
relationship intact. A return value of `false` breaks the observer
relationship, just as with `remove_observer_var`.

### Observable and DRb ###

As of version 0.3, observable can be used over a drb connection, allowing
distributed GUIs etc. This happens almost transparently. There are two points
to be aware of. First, `cancel_when_var` and `remove_observer_var` are
not currently supported over drb. This may be fixed in later versions. However,
returning `false` from a `handle_observer_exception` still can be used
to disconnect the observer, as discussed above.

Second, when a drb client observing some attribute disconnects, a dangling
reference will be left in the observable attribute's table of observers. When,
at some later time, some code writes a value to the attribute, the library will
attempt to propagate the value to the disconnected observer and receive a
`DRb::DRbConnError`. The server can use `handle_observer_exception` to
detect and resolve this situation. For instance, simply breaking the observer
relationship might be the right thing for the application to do. The following
server-side code will implement this response:

```ruby
    class DRb::DRbServer::InvokeMethod
      def handle_observer_exception(*args)
        @obj.handle_observer_exception(*args)
      end
    end

    class MyObservableClass
      extend Observable
      observable :var1, :var2, :var3

      def handle_observer_exception(exception, var, pattern)
        if DRb::DRbConnError === exception
          $stderr.puts "A client disconnected."
          false # let the observer be disconnected
        else
          $stderr.puts "A client had an unhandled exception in a when_ clause."
          # handle any app-specific exceptions
          true # Stay connected if handled. Otherwise, return false.
        end
      end
    end
```

A complete example, a simple GUI chat client/server, is in the FoxTails package, at http://redshift.sourceforge.net/foxtails.

### Comparison with `Observer` pattern ###

The `observable` declaration has some differences with the standard
`Observer` pattern in `observer.rb`:

* The observer is observing a variable in an object, rather than just an
  object.

* The observed object doesn't need to call `changed` or
  `notify_observers`. Using the writer method to assign a value to the
  variable causes the observers to be notified, if there is a new value.

* In fact, the observed object doesn't need to have any special code to be
  observed. Just declare the variable with `observable :var`. The
  declaration can even be done in the singleton class of an object.

* The observer can register interest in several possible states of the
  variable, and can use pattern matching to describe those states and
  provide different actions for each pattern.

* No `update` method is required in the observer. Instead, the action
  associated with a state change is a `proc`, which can access variables
  in the scope in which it was created, since it is a closure.
   
### Version ###

Observable 0.6

The current version of this software can be found at https://github.com/vjoel/observable.

### License ###

This software is distributed under the Ruby license.
See http://www.ruby-lang.org.

### Author ###

Copyright (C) 2002-2013, Joel VanderWerf, vjoel@users.sourceforge.net
