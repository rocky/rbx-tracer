require 'rubygems'; require 'require_relative'
require_relative './breakpoint'
require_relative './iseq'


class Rubinius::SetTrace

  include ISeq

  def stepping_initialize
    @step_brkpts  = []
  end
  
  def stepping_breakpoint_finalize
    @step_brkpts.each do |bp| 
      bp.remove!
    end
  end
  
  def remove_step_brkpt
    return unless @step_bp
    @step_brkpts = @step_brkpts.select do |bp| 
      (bp != @step_bp) && bp.active?
    end
    @step_bp.remove!
  end
  
  def set_breakpoints_between(meth, start_ip, fin_ip)
    opts = {:event => 'line', :temp  => true}
    ips = goto_between(meth, start_ip, fin_ip)
    bps = []

    if ips.kind_of? Fixnum
      if ips == -1
        STDERR.puts "No place to step to"
        return nil
      elsif ips == -2
        bps << step_to_parent(event='line')
        ips = []
      else
        ips = [ips]
      end
    end
    
    
    # puts "temp ips: #{ips.inspect}" 
    frame = current_frame
    ips.each do |ip|
      bp = Breakpoint.for_ip(meth, ip, opts)
      bp.scoped!(frame.scope)
      bp.activate
      bps << bp
    end
    @step_brkpts ||= []
    @step_brkpts += bps
    first_bp = bps[0]
    bps[1..-1].each do |bp| 
      first_bp.related_with(bp) 
    end
    return first_bp
  end
  
  def step_over_by(step)
    f = current_frame
    
    ip = -1
    
    meth = f.method
    possible_line = f.line + step
    fin_ip = meth.first_ip_on_line possible_line, f.ip
    
    return step_to_parent('line') unless fin_ip
    
    set_breakpoints_between(meth, f.ip, fin_ip)
  end
  
  def step_to_return_or_yield()
    f = current_frame
    unless f
      msg 'Unable to find frame to finish'
      return
    end
      
    meth = f.method
    fin_ip = meth.lines.last
    
    set_breakpoints_on_return_between(meth, f.next_ip, fin_ip)
  end

  def step_to_parent(event='return')
    f = frame(current_frame.number + 1)
    unless f
      errmsg "Unable to find parent frame to step to next"
      return nil 
    end
    meth = f.method
    ip   = f.ip
    
    bp = Breakpoint.for_ip(meth, ip, {:event => event, :temp => true})
    bp.scoped!(f.scope)
    bp.activate
      
    return bp
  end
end

if __FILE__ == $0
  method = Rubinius::CompiledMethod.of_sender
  
  bp = Rubinius::SetTrace::Breakpoint::for_ip(method, 0)
end
