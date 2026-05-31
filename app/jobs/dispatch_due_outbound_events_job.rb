class DispatchDueOutboundEventsJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  def perform(batch_size: BATCH_SIZE)
    OutboundEvent.due_for_dispatch.limit(batch_size).each do |event|
      OutboundEventDispatchJob.perform_later(event.id)
    end
  end
end
