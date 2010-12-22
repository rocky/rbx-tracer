class Rubinius::SetTrace
  class Frame
    def initialize(debugger, number, runtime_context)
      @debugger = debugger
      @number = number
      @runtime_context = runtime_context
    end

    attr_reader :number, :runtime_context

    def run(code)
      eval(code, binding)
    end

    def binding
      @binding ||= Binding.setup(
                     @runtime_context.variables,
                     @runtime_context.method,
                     @runtime_context.static_scope)
    end

    def method
      @runtime_context.method
    end

    def line
      @runtime_context.line
    end

    def file
      @runtime_context.file
    end

    def ip
      @runtime_context.ip
    end

    def variables
      @runtime_context.variables
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

      context = @runtime_context

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
