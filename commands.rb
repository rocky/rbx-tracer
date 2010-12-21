require 'breakpoint'

class Rubinius::SetTrace
  class CommandDescription
    attr_accessor :klass, :patterns, :help, :ext_help

    def initialize(klass)
      @klass = klass
    end

    def name
      @klass.name
    end
  end

  class Command

    @commands = []

    def self.commands
      @commands
    end

    def self.descriptor
      @descriptor ||= CommandDescription.new(self)
    end

    def self.pattern(*strs)
      Command.commands << self
      descriptor.patterns = strs
    end

    def self.match?(cmd)
      descriptor.patterns.include?(cmd)
    end

    def initialize(debugger)
      @debugger = debugger
    end

    def current_method
      @debugger.current_frame.method
    end

    def current_frame
      @debugger.current_frame
    end

    def variables
      @debugger.variables
    end

    def listen(step=false)
      @debugger.listen(step)
    end

    class StepInto < Command
      pattern "s", "step"

      def goto_between(exec, start, fin)
        goto = Rubinius::InstructionSet.opcodes_map[:goto]
        git  = Rubinius::InstructionSet.opcodes_map[:goto_if_true]
        gif  = Rubinius::InstructionSet.opcodes_map[:goto_if_false]

        iseq = exec.iseq

        i = start
        while i < fin
          op = iseq[i]
          case op
          when goto
            return next_interesting(exec, iseq[i + 1]) # goto target
          when git, gif
            return [next_interesting(exec, iseq[i + 1]),
              next_interesting(exec, i + 2)] # target and next ip
          else
            op = Rubinius::InstructionSet[op]
            i += (op.arg_count + 1)
          end
        end

        return next_interesting(exec, fin)
      end

      def next_interesting(exec, ip)
        pop = Rubinius::InstructionSet.opcodes_map[:pop]

        if exec.iseq[ip] == pop
          return ip + 1
        end

        return ip
      end

      def set_breakpoints_between(exec, start_ip, fin_ip)
        ips = goto_between(exec, start_ip, fin_ip)
        if ips.kind_of? Fixnum
          ip = ips
        else
          one, two = ips
          bp1 = BreakPoint.for_ip(exec, one)
          bp2 = BreakPoint.for_ip(exec, two)

          bp1.paired_with(bp2)
          bp2.paired_with(bp1)

          bp1.for_step!(current_frame.variables)
          bp2.for_step!(current_frame.variables)

          bp1.activate
          bp2.activate

          return bp1
        end

        if ip == -1
          STDERR.puts "No place to step to"
          return nil
        end

        bp = BreakPoint.for_ip(exec, ip)
        bp.for_step!(current_frame.variables)
        bp.activate

        return bp
      end

      def step_over_by(step)
        f = current_frame

        ip = -1

        exec = f.method
        possible_line = f.line + step
        fin_ip = exec.first_ip_on_line possible_line, f.ip

        if fin_ip == -1
          return step_to_parent
        end

        set_breakpoints_between(exec, f.ip, fin_ip)
      end

      def step_to_parent
        f = @debugger.frame(current_frame.number + 1)
        unless f
          STDERR.puts "Unable to find frame to step to next"
          return
        end

        exec = f.method
        ip = f.ip

        bp = BreakPoint.for_ip(exec, ip, :anon, 'return')
        bp.for_step!(f.variables)
        bp.activate

        return bp
      end

      def run(args)
        max = step_over_by(1)

        listen(true)

        # We remove the max position breakpoint no matter what
        max.remove! if max

      end
    end
  end
end
