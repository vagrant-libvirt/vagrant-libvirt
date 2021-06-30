# frozen_string_literal: true

##
# A simple extension of the Proc class that supports setting a custom binding
# and evaluates everything in the Proc using the new binding.

class ProcWithBinding < Proc
  ##
  # Set the binding for this instance

  def apply_binding(bind, *args)
    @binding = bind
    instance_exec(*args, &self)
  end

  def method_missing(method, *args)
    begin
      method_from_binding = eval("method(#{method.inspect})", @binding)
      return method_from_binding.call(*args)
    rescue NameError
      # fall through on purpose
    end

    super
  end
end
