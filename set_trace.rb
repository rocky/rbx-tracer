require 'rubygems'; require 'require_relative'
require_relative './frame'
require_relative './commands'
require_relative './breakpoint'
require 'compiler/iseq'

#
# A Rubinius implementation of set_trace_func.
#
# This debugger is wired into the debugging APIs provided by Rubinius.
# It serves as a simple, builtin debugger that others can use as
# an example for how to build a better debugger.
#

class Rubinius::SetTrace

  # Used to try and show the source for the kernel. Should
  # mostly work, but it's a hack.
  ROOT_DIR = File.expand_path(File.dirname(__FILE__) + "/..")

  # Create a new debugger object. The debugger starts up a thread
  # which is where the command line interface executes from. Other
  # threads that you wish to debug are told that their debugging
  # thread is the debugger thread. This is how the debugger is handed
  # control of execution.
  #
  def initialize(meth=nil)
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

    @meth = meth
    @thread = nil
    @frames = []
    @user_variables = 0
    @breakpoints = []
    @root_dir = ROOT_DIR
  end

  attr_reader :variables, :current_frame, :breakpoints, :user_variables
  attr_reader :locations

  def self.global(callback_method)
    # FIXME: if @global is set, we need to *change* method.
    @global ||= new(callback_method)
  end

  def self.start(callback_method)
    global(callback_method).start(1)
  end

  # Startup the debugger, skipping back +offset+ frames. This lets you start
  # the debugger straight into callers method.
  #
  def start(callback_method, offset=0)
    spinup_thread

    # Feed info to the debugger thread!
    locs = Rubinius::VM.backtrace(offset + 1, true)

    method = Rubinius::CompiledMethod.of_sender

    bp = BreakPoint.new "<start>", method, 0, 0
    channel = Rubinius::Channel.new

    @local_channel.send Rubinius::Tuple[bp, Thread.current, channel, locs]

    # wait for the debugger to release us
    channel.receive

    Thread.current.set_debugger_thread @thread
    self
  end

  # Stop and wait for a debuggee thread to send us info about
  # stoping at a breakpoint.
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
      bp, thr, chan, locs = @local_channel.receive

      # Uncache all frames since we stopped at a new place
      @frames = []

      @locations = locs
      @breakpoint = bp
      @debuggee_thread = thr
      @channel = chan

      @current_frame = frame(0)

      if bp
        # Only break out if the hit was valid
        break if bp.hit!(locs.first)
      else
        break
      end
    end

    puts
    puts "Breakpoint: #{@current_frame.describe}"
    show_code

  end

  # call callback
  def call_callback
    runner = Command.commands.find { |k| k.match?('step') }
    puts "should do a @method.call(@locs) here"
    if runner
      runner.new(self).run ['1']
    end
  end

  def frame(num)
    @frames[num] ||= Frame.new(self, num, @locations[num])
  end

  def set_frame(num)
    @current_frame = frame(num)
  end

  def each_frame(start=0)
    start = start.number if start.kind_of?(Frame)

    start.upto(@locations.size-1) do |idx|
      yield frame(idx)
    end
  end

  def set_breakpoint_method(descriptor, method, line=nil)
    exec = method.executable

    unless exec.kind_of?(Rubinius::CompiledMethod)
      STDERR.puts "Unsupported method type: #{exec.class}"
      return
    end

    if line
      ip = exec.first_ip_on_line(line)

      if ip == -1
        STDERR.puts "Unknown line '#{line}' in method '#{method.name}'"
        return
      end
    else
      line = exec.first_line
      ip = 0
    end

    bp = BreakPoint.new(descriptor, exec, ip, line)
    bp.activate

    @breakpoints << bp

    puts "Set breakpoint #{@breakpoints.size}: #{bp.location}"

    return bp
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
    ss   = Rubinius::InstructionSet.opcodes_map[:send_stack]
    sm   = Rubinius::InstructionSet.opcodes_map[:send_method]
    sb   = Rubinius::InstructionSet.opcodes_map[:send_stack_with_block]

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
  def set_trace_func(callback_method)
    Rubinius::SetTrace.start(callback_method)
  end
end

if __FILE__ == $0
  puts "Hi rocky"
  meth = lambda { puts "trace func called" }
  set_trace_func  meth
end
