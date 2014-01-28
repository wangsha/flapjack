#!/usr/bin/env ruby

# A HTTP-based API server, which provides queries to determine the status of
# entities and the checks that are reported against them.
#
# There's a matching flapjack-diner gem at https://github.com/flpjck/flapjack-diner
# which consumes data from this API.

require 'time'

require 'sinatra/base'

require 'flapjack'

require 'flapjack/gateways/api/rack/json_params_parser'
require 'flapjack/gateways/api/contact_methods'
require 'flapjack/gateways/api/entity_methods'

module Flapjack

  module Gateways

    class API < Sinatra::Base

      include Flapjack::Utility

      set :raise_errors, true
      set :show_exceptions, false

      # set :dump_errors, false

      # rescue_error = Proc.new {|status, exception, *msg|
      #   if !msg || msg.empty?
      #     trace = exception.backtrace.join("\n")
      #     msg = "#{exception.class} - #{exception.message}"
      #     msg_str = "#{msg}\n#{trace}"
      #   else
      #     msg_str = msg.join(", ")
      #   end
      #   case
      #   when status < 500
      #     @logger.warn "Error: #{msg_str}"
      #   else
      #     @logger.error "Error: #{msg_str}"
      #   end
      #   [status, {}, {:errors => msg}.to_json]
      # }

      # rescue_exception = Proc.new {|env, e|
      #   case e
      #   when Flapjack::Gateways::API::ContactNotFound
      #     rescue_error.call(403, e, "could not find contact '#{e.contact_id}'")
      #   when Flapjack::Gateways::API::NotificationRuleNotFound
      #     rescue_error.call(403, e, "could not find notification rule '#{e.rule_id}'")
      #   when Flapjack::Gateways::API::EntityNotFound
      #     rescue_error.call(403, e, "could not find entity '#{e.entity}'")
      #   when Flapjack::Gateways::API::EntityCheckNotFound
      #     rescue_error.call(403, e, "could not find entity check '#{e.check}'")
      #   else
      #     rescue_error.call(500, e)
      #   end
      # }
      # use Rack::FiberPool, :size => 25, :rescue_exception => rescue_exception

      use Rack::MethodOverride
      use Rack::JsonParamsParser

      class << self
        def start
          @logger.info "starting api - class"

          if accesslog = (@config && @config['access_log'])
            if not File.directory?(File.dirname(accesslog))
              puts "Parent directory for log file #{accesslog} doesn't exist"
              puts "Exiting!"
              exit
            end

            use Rack::CommonLogger, ::Logger.new(@config['access_log'])
          end
        end
      end

      ['redis', 'logger', 'config'].each do |class_inst_var|
        define_method(class_inst_var.to_sym) do
          self.class.instance_variable_get("@#{class_inst_var}")
        end
      end

      before do
        input = nil
        if logger.debug?
          input = env['rack.input'].read
          logger.debug("#{request.request_method} #{request.path_info}#{request.query_string} #{input}")
        elsif logger.info?
          input = env['rack.input'].read
          input_short = input.gsub(/\n/, '').gsub(/\s+/, ' ')
          logger.info("#{request.request_method} #{request.path_info}#{request.query_string} #{input_short[0..80]}")
        end
        env['rack.input'].rewind unless input.nil?
      end

      after do
        logger.debug("Returning #{response.status} for #{request.request_method} #{request.path_info}#{request.query_string}")
      end

      register Flapjack::Gateways::API::EntityMethods

      register Flapjack::Gateways::API::ContactMethods

      not_found do
        err(404, "not routable")
      end

      error Flapjack::Gateways::API::ContactNotFound do
        e = env['sinatra.error']
        err(404, "could not find contact '#{e.contact_id}'")
      end

      error Flapjack::Gateways::API::NotificationRuleNotFound do
        e = env['sinatra.error']
        err(404, "could not find notification rule '#{e.rule_id}'")
      end

      error Flapjack::Gateways::API::EntityNotFound do
        e = env['sinatra.error']
        err(404, "could not find entity '#{e.entity}'")
      end

      error Flapjack::Gateways::API::EntityCheckNotFound do
        e = env['sinatra.error']
        err(404, "could not find entity check '#{e.check}'")
      end

      error do
        e = env['sinatra.error']
        err(response.status, "#{e.class} - #{e.message}")
      end

      private

      def err(status, *msg)
        msg_str = msg.join(", ")
        logger.info "Error: #{msg_str}"
        [status, {}, {:errors => msg}.to_json]
      end
    end

  end

end
