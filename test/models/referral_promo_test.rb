require "test_helper"

class ReferralPromoDetailsTest < ActiveSupport::TestCase
  PROMO_ID = "2018q1"
  REFERRAL_CODE = "BATS-123"

  test "referral promo must have an associated channel" do
    channel = channels(:verified)
    referral_promo = ReferralPromo.new(channel_id: nil, promo_id: PROMO_ID, referral_code: REFERRAL_CODE)

    # verify validation fails if no associated channel
    assert !referral_promo.valid?

    # verify validation passes with associated channel
    referral_promo.channel_id = channel.id
    assert referral_promo.valid?
  end

  test "referral promo must have a promo id" do
    channel = channels(:verified)
    referral_promo = ReferralPromo.new(channel_id: channel.id, promo_id: "", referral_code: REFERRAL_CODE)

    # verify validation fails if no associated promo_id
    assert !referral_promo.valid?

    # verify validation passses with associated promo_id
    referral_promo.promo_id = PROMO_ID
    assert referral_promo.valid?
  end

  test "referral promo must have a referral code" do
    channel = channels(:verified)
    referral_promo = ReferralPromo.new(channel_id: channel.id, promo_id: PROMO_ID, referral_code: nil)

    # verify validation fails is no associated referral code
    assert !referral_promo.valid?

    # verify validation passes with assoicated referral code
    referral_promo.referral_code = REFERRAL_CODE
    assert referral_promo.valid?
  end

  test "referral promo must have a unique referral code " do
    channel_verified = channels(:verified)
    channel_completed = channels(:completed)
    referral_promo = ReferralPromo.new(channel_id: channel_verified.id, promo_id: PROMO_ID, referral_code: REFERRAL_CODE)
    referral_promo.save!

    # verify validation fails with non unique referall code
    referral_promo_invalid = ReferralPromo.new(channel_id: channel_completed.id, promo_id: PROMO_ID, referral_code: REFERRAL_CODE)
    assert !referral_promo_invalid.valid?

    # verify validation passes with unique referral code
    referral_promo_invalid.referral_code = "BATS-321"
    assert referral_promo_invalid.valid?
  end

  # This might be better suited for ChannelTest
  test "channel can only have one referral promo" do
    channel = channels(:verified)
    referral_promo = ReferralPromo.new(channel_id: channel.id, promo_id: PROMO_ID, referral_code: REFERRAL_CODE)
    referral_promo.save!
    referral_promo_invalid = ReferralPromo.new(channel_id: channel.id, promo_id: PROMO_ID, referral_code: "BATS-321")
    referral_promo.save!

    # verify channel has only the first promo detail
    assert_equal channel.referral_promo, referral_promo
    assert_not_equal channel.referral_promo, referral_promo_invalid
  end

  test "if referral promo deleted, associated channel shouldn't be deleted" do
    channel = channels(:verified)
    referral_promo = ReferralPromo.new(channel_id: channel.id, promo_id: PROMO_ID, referral_code: REFERRAL_CODE)
    referral_promo.save!

    assert_equal channel.referral_promo, referral_promo

    referral_promo.delete
    assert Channel.exists?(channel.id)
  end

  test "if referral promo deleted, associated publisher shouldn't be deleted" do
    # TO DO
  end
end