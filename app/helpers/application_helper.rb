module ApplicationHelper
  def status_badge_class(status)
    case status.to_s
    when "issued", "cancelled", "succeeded", "active", "dispatched"
      "badge-success"
    when "rejected", "cancellation_failed", "failed", "suspended"
      "badge-danger"
    when /\Apending/, "processing"
      "badge-warning"
    else
      "badge-neutral"
    end
  end

  def money_from_cents(cents)
    number_to_currency(cents.to_i / 100.0, unit: "R$ ", separator: ",", delimiter: ".")
  end

  def local_time(value)
    return "-" if value.blank?

    value.in_time_zone.strftime("%Y-%m-%d %H:%M")
  end
end
