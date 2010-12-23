class Rubinius::SetTrace
  class Frame
    def initialize(debugger, number, vm_location)
      @debugger = debugger
      @number = number
      @vm_location = vm_location
    end

    attr_reader :number, :vm_location

    def run(code)
      eval(code, binding)
    end

    def binding
      @binding ||= Binding.setup(
                     @vm_location.variables,
                     @vm_location.method,
                     @vm_location.static_scope)
    end

    def method
      @vm_location.method
    end

    def line
      @vm_location.line
    end

    def file
      @vm_location.file
    end

    def ip
      @vm_location.ip
    end

    def variables
      @vm_location.variables
    end

    def local_variables
      method.local_names
    end

    def describe
      if method.required_args > 0
        locals = []
        0.upto(method.required_args-1) do |arg|
          locals << method.local_names[arg].to_s
        end

        arg_str = locals.join(", ")
      else
        arg_str = ""
      end

      context = @vm_location

      if loc.is_block
        if arg_str.empty?
          recv = "{ } in #{context.describe_receiver}#{context.name}"
        else
          recv = "{|#{arg_str}| } in #{context.describe_receiver}#{context.name}"
        end
      else
        if arg_str.empty?
          recv = loc.describe
        else
          recv = "#{context.describe}(#{arg_str})"
        end
      end

      str = "#{recv} at #{context.method.active_path}:#{context.line} (@#{context.ip})"
    end
  end
end
