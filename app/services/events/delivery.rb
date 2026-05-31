module Events
  class Delivery
    ConfigurationError = Class.new(StandardError)

    def self.deliver!(event)
      case adapter_name
      when "log"
        deliver_to_log!(event)
      else
        raise ConfigurationError, "Unsupported outbound event delivery adapter #{adapter_name.inspect}."
      end
    end

    def self.adapter_name
      ENV.fetch("OUTBOUND_EVENT_DELIVERY_ADAPTER", "log").to_s
    end

    def self.deliver_to_log!(event)
      Rails.logger.info(
        message: "outbound_event_delivered_to_log_sink",
        event_id: event.id,
        event_type: event.event_type,
        organization_id: event.organization_id,
        correlation_id: event.correlation_id
      )

      true
    end

    private_class_method :adapter_name, :deliver_to_log!
  end
end
