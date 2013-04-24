require 'fiber_pool'

module Rack
  class FiberPool
    VERSION = '0.9.4'
    SIZE = 100

    # The size of the pool is configurable:
    #
    #   use Rack::FiberPool, :size => 25
    def initialize(app, options={})
      @app = app
      @fiber_pool = ::FiberPool.new(options[:size] || SIZE)
      @rescue_exception = options[:rescue_exception] || Proc.new { |env, e| [500, {}, ["#{e.class.name}: #{e.message.to_s}"]] }
      yield @fiber_pool if block_given?
    end

    def call(parent_env)
      env = parent_env.dup
      call_app = lambda do
        env['async.orig_callback'] = env.delete('async.callback')
        begin
          result = @app.call(env)
          env['async.orig_callback'].call result
        rescue ::Exception => e
          env['async.orig_callback'].call @rescue_exception.call(env, e)
        end
      end

      @fiber_pool.spawn(&call_app)
      throw :async
    end
  end
end
