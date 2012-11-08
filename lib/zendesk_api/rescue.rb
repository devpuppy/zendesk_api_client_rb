module ZendeskAPI
  # @private
  module Rescue
    def self.included(klass)
      klass.extend(Methods)
      klass.send(:include, Methods)
    end

    # @private
    module Methods
      def log_error(e, method = false)
        if logger = (@client ? @client.config.logger : Kernel)
          logger.warn "#{self} - #{method}" if method
          logger.warn e.message
          logger.warn e.backtrace.join("\n")
          logger.warn "\t#{e.response[:body].inspect}" if e.response
        end
      end

      def attach_error(e)
        return false unless e.response && body = e.response[:body]
        begin
          self.error_name = body['error']
          self.error_description = body['description']
          self.error_details = body['details']
          true
        rescue NoMethodError
          false
        end
      end

      def rescue_client_error(*args)
        opts = args.last.is_a?(Hash) ? args.pop : {}

        if args.any?
          args.each do |method|
            class_eval("alias :orig_#{method} :#{method}")
            define_method method do |*args|
              begin
                send("orig_#{method}", *args)
              rescue Faraday::Error::ClientError => e
                log_error(e, method)
                attach_error(e)
                opts[:with].respond_to?(:call) ? opts[:with].call : opts[:with]
              end
            end
          end
        elsif block_given?
          begin
            yield
          rescue Faraday::Error::ClientError => e
            log_error(e)
            attach_error(e)
            opts[:with].respond_to?(:call) ? opts[:with].call : opts[:with]
          end
        end
      end
    end
  end
end
