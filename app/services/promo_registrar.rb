# Registers each verified channel for a publisher
class PromoRegistrar < BaseApiClient
  include PromosHelper

  def initialize(publisher:, promo_id: active_promo_id)
    @publisher = publisher
    @promo_id = promo_id
  end

  def perform
    channels = @publisher.channels.where(verified: true)
    channels.each do |channel|
      if should_register_channel?(channel)
        result = register_channel(channel)
        referral_code = result[:referral_code]
        should_update_promo_server = result[:should_update_promo_server]
        if referral_code.present?
          promo_registration = PromoRegistration.new(channel_id: channel.id, promo_id: @promo_id, kind: "channel", referral_code: referral_code)
          success = promo_registration.save!
          if success && should_update_promo_server
            PromoChannelOwnerUpdater.new(publisher_id: @publisher.id, referral_code: referral_code).perform
          end
        end
      end
    end
  end

  def register_channel(channel)
    return register_channel_offline if perform_promo_offline?
    response = connection.put do |request|
      request.headers["Authorization"] = api_authorization_header
      request.headers["Content-Type"] = "application/json"
      request.body = request_body(channel)
      request.url("/api/1/promo/publishers")
    end

    {
      referral_code: JSON.parse(response.body)["referral_code"],
      should_update_promo_server: false
    }
  rescue Faraday::Error => e
    if e.response[:status] == 409
      Rails.logger.warn("PromoRegistrar #register_channel returned 409, channel already registered.  Using PromoRegistrationGetter to get the referral_code.")
      
      # Get the referral code
      registration = PromoRegistrationGetter.new(publisher: @publisher, channel: channel).perform

      {
        referral_code: registration["referral_code"],
        should_update_promo_server: registration["owner_id"] != @publisher.id ? true : false
      }
    else
      require "sentry-raven"
      Rails.logger.error("PromoRegistrar #register_channel error: #{e}")
      Raven.capture_exception("PromoRegistrar #register_channel error: #{e}")
      nil
    end
  end

  def register_channel_offline
    Rails.logger.info("PromoRegistrar #register_channel offline.")
    {
      referral_code: offline_referral_code,
      should_update_promo_server: false
    }
  end

  private

  def api_base_uri
    Rails.application.secrets[:api_promo_base_uri]
  end

  def api_authorization_header
    "Bearer #{Rails.application.secrets[:api_promo_key]}"
  end

  def request_body(channel)
    case channel.details_type
    when "YoutubeChannelDetails"
      return youtube_request_body(channel)
    when "TwitchChannelDetails"
      return twitch_request_body(channel)
    when "TwitterChannelDetails"
      return twitter_request_body(channel)
    when "SiteChannelDetails"
      return site_request_body(channel)
    else
      raise
    end
  end

  def youtube_request_body(channel)
    {
      "owner_id": @publisher.id,
      "promo": @promo_id,
      "channel": channel.channel_id, 
      "title": channel.publication_title,
      "channel_type": "youtube",
      "thumbnail_url": channel.details.thumbnail_url,
      "description": channel.details.description.presence
    }.to_json
  end

  def twitch_request_body(channel)
    {
      "owner_id": @publisher.id,
      "promo": @promo_id,
      "channel": channel.channel_id, 
      "title": channel.publication_title,
      "channel_type": "twitch",
      "thumbnail_url": channel.details.thumbnail_url,
      "description": nil
    }.to_json
  end

  def twitter_request_body(channel)
    {
      "owner_id": @publisher.id,
      "promo": @promo_id,
      "channel": channel.channel_id, 
      "title": channel.publication_title,
      "channel_type": "twitter",
      "thumbnail_url": channel.details.thumbnail_url,
      "description": nil # TODO: Should we store the twitter bio when channel is added to display here?
    }.to_json
  end

  def site_request_body(channel)
    {
      "owner_id": @publisher.id,
      "promo": @promo_id,
      "channel": channel.channel_id, 
      "title": channel.publication_title,
      "channel_type": "website",
    }.to_json
  end

  def should_register_channel?(channel)
    channel.promo_registration.blank?
  end
end