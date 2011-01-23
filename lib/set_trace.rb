# -*- coding: utf-8 -*-
# Copyright (C) 2011 Rocky Bernstein <rockyb@rubyforge.net>
require 'rubygems'; require 'require_relative'
require_relative '../app/frame'
require_relative '../app/stepping'
require_relative '../app/breakpoint'
require 'compiler/iseq'

#
# A Rubinius implementation of set_trace_func.
#
# This code is wired into the debugging APIs provided by Rubinius.
# It tries to isolate the complicated stepping logic as well as simulate
# Ruby's set_trace_func.
#

class Rubinius::SetTrace
  VERSION = '0.0.4.dev'

  DEFAULT_SET_TRACE_FUNC_OPTS = {
    :callback_style => :classic,
    :step_to_parent => :true
  }

  # Create a new object. Stepping starts up a thread which is where
  # the callback executes from. Other threads are told that their
  # debugging thread is the stepping thread, and this control of execution
  # is handled.
  #
  def initialize()
    @file_lines = Hash.new do |hash, path|
      if File.exists? path
        hash[path] = File.readlines(path)
      else
        ab_path = File.join(@root_dir, path)
        if File.exists? ab_path
          hash[path] = File.readlines(ab_path)
        else
          hash[path] = []
        end
      end
    end

    @thread = nil
    @frames = []
    @user_variables = 0
    @breakpoints = []
  end

  attr_reader :variables, :current_frame, :breakpoints, :user_variables
  attr_reader :vm_locations

  def self.global(opts={})
    @global ||= new
  end

  def self.set_trace_func(callback_method, opts={})
    opts = Rubinius::SetTrace::DEFAULT_SET_TRACE_FUNC_OPTS.merge(opts)
    opts[:call_offset] ||= 1
    global.set_trace_func(callback_method, opts)
  end

  # Startup the stepping, skipping back +opts[:call_offset]+
  # frames. This lets you start stepping straight into caller's
  # method.
  #
  def set_trace_func(callback_method, opts={})
    if callback_method
      @opts = opts
      call_offset = @opts[:call_offset] || 0
      @callback_method = callback_method
      @tracing  = true
      spinup_thread
      
      # Feed info to the stepping call-back thread!
      @vm_locations = Rubinius::VM.backtrace(call_offset + 1, true)
      
      method = Rubinius::CompiledMethod.of_sender
      
      bp = BreakPoint.new "<start>", method, 0, 0
      channel = Rubinius::Channel.new
      
      @local_channel.send Rubinius::Tuple[bp, Thread.current, channel, 
                                          @vm_locations]
      
      # wait for the callback to release us
      channel.receive
      
      Thread.current.set_debugger_thread @thread
      self
    else
      @tracing = false
    end
  end

  # Stop and wait for a debuggee thread to send us info about
  # stopping at a breakpoint.
  #
  def listen(step_into=false)
    while true
      if @channel
        if step_into
          @channel << :step
        else
          @channel << true
        end
      end

      # Wait for someone to stop
      @breakpoint, @debugee_thread, @channel, @vm_locations = 
        @local_channel.receive

      # Uncache all frames since we stopped at a new place
      @frames = []

      @current_frame = frame(0)

      if @breakpoint
        @event = @breakpoint.event
        # Only break out if the hit was valid
        break if @breakpoint.hit!(@vm_locations.first)
      else
        @event = 'call'
        break
      end
    end

    # puts
    # puts "Breakpoint: #{@current_frame.describe}"
    # show_code

  end

  # call callback
  def call_callback
    case @opts[:callback_style]
    when :classic
      line = @current_frame.line
      file = @current_frame.file
      meth = @current_frame.method
      binding = @current_frame.binding
      id = nil
      classname = nil
      @callback_method.call(@event, file, line, id, binding, classname)
    else
      @callback_method.call(@event, @vm_locations)
    end
    if @tracing
      if @opts[:step_to_parent] 
        @opts[:step_to_parent] = false
        step_to_parent 
      else 
        step_over_by(1)
      end
    end
    listen
  end

  def frame(num)
    @frames[num] ||= Frame.new(self, num, @vm_locations[num])
  end

  def delete_breakpoint(i)
    bp = @breakpoints[i-1]

    unless bp
      STDERR.puts "Unknown breakpoint '#{i}'"
      return
    end

    bp.delete!

    @breakpoints[i-1] = nil
  end

  def send_between(exec, start, fin)
    ss = Rubinius::InstructionSet.opcodes_map[:send_stack]
    sm = Rubinius::InstructionSet.opcodes_map[:send_method]
    sb = Rubinius::InstructionSet.opcodes_map[:send_stack_with_block]

    iseq = exec.iseq

    fin = iseq.size if fin < 0

    i = start
    while i < fin
      op = iseq[i]
      case op
      when ss, sm, sb
        return exec.literals[iseq[i + 1]]
      else
        op = Rubinius::InstructionSet[op]
        i += (op.arg_count + 1)
      end
    end

    return nil
  end

  def show_code(line=@current_frame.line)
    path = @current_frame.method.active_path

    if str = @file_lines[path][line - 1]
      puts "#{line}: #{str}"
    else
      show_bytecode(line)
    end
  end

  def decode_one
    ip = @current_frame.ip

    meth = @current_frame.method
    decoder = Rubinius::InstructionDecoder.new(meth.iseq)
    partial = decoder.decode_between(ip, ip+1)

    partial.each do |ins|
      op = ins.shift

      ins.each_index do |i|
        case op.args[i]
        when :literal
          ins[i] = meth.literals[ins[i]].inspect
        when :local
          if meth.local_names
            ins[i] = meth.local_names[ins[i]]
          end
        end
      end

      display "ip #{ip} = #{op.opcode} #{ins.join(', ')}"
    end
  end

  def show_bytecode(line=@current_frame.line)
    meth = @current_frame.method
    start = meth.first_ip_on_line(line)
    fin = meth.first_ip_on_line(line+1)

    if fin == -1
      fin = meth.iseq.size
    end

    puts "Bytecode between #{start} and #{fin-1} for line #{line}"

    decoder = Rubinius::InstructionDecoder.new(meth.iseq)
    partial = decoder.decode_between(start, fin)

    ip = start

    partial.each do |ins|
      op = ins.shift

      ins.each_index do |i|
        case op.args[i]
        when :literal
          ins[i] = meth.literals[ins[i]].inspect
        when :local
          if meth.local_names
            ins[i] = meth.local_names[ins[i]]
          end
        end
      end

      puts " %4d: #{op.opcode} #{ins.join(', ')}" % ip

      ip += (ins.size + 1)
    end
  end

  def spinup_thread
    return if @thread

    @local_channel = Rubinius::Channel.new

    @thread = Thread.new do
      begin
        listen
      rescue Exception => e
        e.render("Listening")
        break
      end

      while true
        begin
          call_callback
        rescue Exception => e
          begin
            e.render "Error in debugger"
          rescue Exception => e2
            STDERR.puts "Error rendering backtrace in debugger!"
          end
        end
      end
    end

    @thread.setup_control!(@local_channel)
  end

  private :spinup_thread

end

module Kernel
  def set_trace_func(callback_method, opts={})
    opts = Rubinius::SetTrace::DEFAULT_SET_TRACE_FUNC_OPTS.merge(opts)
    Rubinius::SetTrace.set_trace_func(callback_method, opts)
  end
end

if __FILE__ == $0
  if ARGV[0] == 'classic'
    meth = lambda { |event, file, line, id, binding, classname|
      puts "tracer: #{event} #{file}:#{line}"
    }
    set_trace_func meth
  else
    meth = lambda { |event, vm_locs|
      puts "tracer: #{event} #{vm_locs[0].file}:#{vm_locs[0].line}"
    }
    set_trace_func(meth, {:callback_style => :new})
  end
  x = 1
  y = 2
  set_trace_func nil
end
