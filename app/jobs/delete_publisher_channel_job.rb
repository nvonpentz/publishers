class DeletePublisherChannelJob < ApplicationJob
  queue_as :default

  def perform(publisher_id:, channel_identifier:, should_update_promo_server:, referral_code:)
    publisher = Publisher.find(publisher_id)

    PublisherEyeshadeChannelDeleter.new(publisher: publisher, channel_identifier: channel_identifier).perform

    if should_update_promo_server
      PromoChannelOwnerUpdater.new(referral_code: referral_code).perform
    end
  end
end
