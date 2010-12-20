class Rubinius::SetTrace
  class BreakPoint

    def self.for_ip(exec, ip, name=:anon)
      line = exec.line_from_ip(ip)

      BreakPoint.new(name, exec, ip, line)
    end

    def initialize(descriptor, method, ip, line)
      @descriptor = descriptor
      @method = method
      @ip = ip
      @line = line
      @for_step = false
      @paired_bp = nil
      @temp = false

      @set = false
    end

    attr_reader :method, :ip, :line, :paired_bp, :descriptor

    def location
      "#{@method.active_path}:#{@line} (+#{ip})"
    end

    def describe
      "#{descriptor} - #{location}"
    end

    def for_step!(scope)
      @temp = true
      @for_step = scope
    end

    def set_temp!
      @temp = true
    end

    def for_step?
      @for_step
    end

    def paired_with(bp)
      @paired_bp = bp
    end

    def activate
      @set = true
      @method.set_breakpoint @ip, self
    end

    def remove!
      return unless @set

      @set = false
      @method.clear_breakpoint(@ip)
    end

    def hit!(loc)
      return true unless @temp

      if @for_step
        return false unless loc.variables == @for_step
      end

      remove!

      @paired_bp.remove! if @paired_bp

      return true
    end

    def delete!
      remove!
    end
  end

end

if __FILE__ == $0
  method = Rubinius::CompiledMethod.of_sender
  bp = Rubinius::SetTrace::BreakPoint.new '<start>', method, 1, 2
  %w(describe location).each do |field|
    puts "#{field}: #{bp.send(field.to_sym)}"
  end
end
