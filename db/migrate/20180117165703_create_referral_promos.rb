class CreateReferralPromos < ActiveRecord::Migration[5.0]
  def change
    create_table :referral_promos, id: :uuid do |t|
      t.references :channel, type: :uuid, index: true, null: false
      t.string :promo_id
      t.string :referral_code

      t.timestamps
    end
  end
end
