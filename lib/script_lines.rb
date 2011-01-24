# Compatibility with MRI 1.8 and 1.9 SCRIPT_LINES__ 
def script_lines__(path)
  if defined?(SCRIPT_LINES__) && SCRIPT_LINES__.is_a?(Hash)
    begin
      code_loader = Rubinius::CodeLoader.new(path)
      begin 
        code_loader.resolve_load_path
        load_path = code_loader.instance_variable_get('@load_path') || 
          File.expand_path(path)
      rescue LoadError
        load_path = path.dup
      end
      load_path = path[0...-'.rbc'.size] if path.end_with?('.rbc')
      load_path += '.rb' unless File.exist?(load_path)
      if File.readable?(load_path)
        SCRIPT_LINES__[path] = File.open(load_path).readlines 
        puts "#{path} added to SCRIPT_LINES__" if $DEBUG
      end
    rescue 
    end
  end
end

Rubinius::CodeLoader.loaded_hook.add(method(:script_lines__))

if __FILE__ == $0
  SCRIPT_LINES__ = {}
  dir = File.dirname(__FILE__)
  file = File.join(dir, 'set_trace.rb')
  load File.join(file)
  puts SCRIPT_LINES__[file][0...10]
end
