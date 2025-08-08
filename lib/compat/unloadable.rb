# frozen_string_literal: true
# Rails 7 shim for legacy `unloadable`

# 1) Método global (el que realmente necesitamos)
module Kernel
  def unloadable(*); end
end

# 2) Compat por si en algún lado hicieron `include Compat::Unloadable`
module Compat
  module Unloadable
    # no-op
  end
end
