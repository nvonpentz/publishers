class ReferralPromo < ApplicationRecord
  belongs_to :channel, validate: true, autosave: true
  # belongs_to :publisher, polymorphic: true, validate: true, autosave: true

  validates :channel_id, presence: true

  validates :promo_id, presence: true

  validates :referral_code, uniqueness: true
  validates :referral_code, presence: true
end
 