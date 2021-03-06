# -*- coding: utf-8 -*-
# Copyright (C) 2013 Rocky Bernstein <rockyb@rubyforge.net>

class Rubinius::SetTrace

  # Breakpoint objects
  class Breakpoint

    attr_accessor :condition # If non-nil, this is a String to be eval'd
                             # which must be true to enter the debugger
    attr_reader   :event     # Symbol. Optional type of event associated with
                             # breakpoint.
    attr_accessor :hits      # Fixnum. The number of times a breakpoint
                             # has been hit (with a true condition). Do
                             # we want to (also) record hits independent
                             # of the condition?
    attr_reader   :id        # Fixnum. Name of breakpoint
    attr_reader   :ignore    # Fixnum. How many more times do we have
                             # to encounter the breakpoint before we stop?
    attr_reader   :line   
    attr_reader   :method
    attr_reader   :negate    # Boolean. Negate sense of condition. Used in 
                             # break if .. and break unless ..
                             # breakpoint
    @@next_id = 1

    BRKPT_DEFAULT_SETTINGS = {
      :condition => 'true',
      :enabled   => 'true',
      :ignore    =>  0,
      :negate    =>  false,
      :temp      =>  false,
      :event     =>  :Unknown,
    } unless defined?(BRKPT_DEFAULT_SETTINGS)

    def initialize(name, method, ip, line, id=nil, opts = {})
      @descriptor = name
      @id = id
      @method = method
      @ip = ip
      @line = line

      # If not nil, is a Rubinius::VariableScope. This is what we 
      # check to have call-frame-specific breakpoints.
      @scope = nil

      @related_bp = []

      opts = BRKPT_DEFAULT_SETTINGS.merge(opts)
      opts.keys.each do |key|
        self.instance_variable_set('@'+key.to_s, opts[key])
      end

      @hits = 0

      # unless @id
      #   @id = @@next_id 
      #   @@next_id += 1
      # end

      @activated = false
    end

    attr_reader :method, :ip, :line, :descriptor
    attr_accessor :related_bp

    def scoped!(scope, temp = true)
      @temp = temp
      @scope = scope
    end

    def set_temp!
      @temp = true
    end

    def scoped?
      !!@scope
    end

    def related_with(bp)
      @related_bp += [bp] + bp.related_bp
      @related_bp.uniq!
      # List of related breakpoints should be shared.
      bp.related_bp = @related_bp
    end

    def activate
      @activated = true
      @method.set_breakpoint @ip, self
    end

    def active?
      @activated
    end

    # FIXME: give this a better name.
    # Return true if the breakpoint is a temporary breakpoint and is
    # relevant. By releveant we mean that, the breakpoint is either
    # not a scoped breakpoint or it is scoped and test_scope matches
    # the desired scope. We also remove the breakpoint and any related
    # breakpoints if it was hit and temporary.  
    # 
    # If the breakpoint is not a temporary breakpoint, return nil.
    # 
    # See also "condition' below which is run to determine whether or 
    # not to stop. 
    def hit!(test_scope)
      return nil unless @temp
      return false if @scope && test_scope != @scope

      @related_bp.each { |bp| bp.remove! }
      remove!
      return true
    end

    def condition?(bind)
      if @negate != eval(@condition, bind)
        if @ignore > 0
          @ignore -= 1
          return false
        else
          @hits += 1
          return true
        end
      else
        return false
      end
    end

    def delete!
      remove!
    end

    def describe
      "#{@descriptor} - #{location}"
    end

    def disable
      @enabled = false
    end

    def enabled
      @enabled = true
    end

    def enabled=(bool)
      @enabled = bool
    end

    def enabled?
      @enabled
    end

    # Return a one-character "icon" giving the state of the breakpoint
    # 't': temporary breakpoint
    # 'B': enabled breakpoint
    # 'b': disabled breakpoint
    def icon_char
      temp? ? 't' : (enabled? ? 'B' : 'b')
    end

    def location
      "#{@method.active_path}:#{@line} (@#{ip})"
    end

    def remove!
      return unless @activated
      @activated = false
      @method.clear_breakpoint(@ip)
    end

    def temp?
      @temp
    end

    class << self
      def for_ip(exec, ip, opts={})
        name = opts[:name] || :anon
        line = exec.line_from_ip(ip)
        self.new(name, exec, ip, line, nil, opts)
      end
    end
  end
end

if __FILE__ == $0
  method = Rubinius::CompiledMethod.of_sender
  bp = Rubinius::SetTrace::Breakpoint.new '<start>', method, 0, 2, 0
  %w(describe location icon_char hits temp? enabled? condition).each do |field|
    puts "#{field}: #{bp.send(field.to_sym)}"
  end
  bp.activate
  bp.remove!
end
