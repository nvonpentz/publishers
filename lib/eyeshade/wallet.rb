require "eyeshade/balance"

module Eyeshade
  class Wallet
    attr_reader :action,
                :address,
                :provider,
                :scope,
                :default_currency,
                :available_currencies,
                :possible_currencies,
                :contribution_balance,
                :referral_balance,
                :total_balance,
                :account_balances,
                :rates,
                :last_settlement_balance,
                :last_settlement_date

    def initialize(wallet_hash:, accounts_hash:, contributions_hash:, referrals_hash:)
      details_json = wallet_hash["wallet"] || {}
      @authorized = details_json["authorized"]
      @provider = details_json["provider"]
      @scope = details_json["scope"]
      @default_currency = details_json["defaultCurrency"]
      @available_currencies = details_json["availableCurrencies"] || []
      @possible_currencies = details_json["possibleCurrencies"] || []
      @address = details_json["address"] || ""

      status_json = wallet_hash["status"] || {}
      @action = status_json["action"]
      @rates = accounts_hash["rates"] || {}

      @account_balances = {}
      accounts_hash.each do |identifier, json|
        @account_balances[identifier] = Eyeshade::Balance.new(balance_json: json)
      end

      @contribution_balance = Eyeshade::Balance.new(balance_json: contributions_hash)
      @referral_balance = Eyeshade::Balance.new(balance_json: referrals_hash, apply_fee: false)
      @total_balance = Eyeshade::Balance.new(balance_json: total_balance_json, apply_fee: false)

      if wallet_hash["lastSettlement"]
        @last_settlement_balance = Eyeshade::Balance.new(balance_json: wallet_hash["lastSettlement"].merge({'rates' => @rates}), apply_fee: false)
        @last_settlement_date = Time.at(wallet_hash["lastSettlement"]["timestamp"]/1000).to_datetime
      end
    end

    def authorized?
      @authorized == true
    end

    def currency_is_possible_but_not_available?(currency)
      @available_currencies.exclude?(currency) && @possible_currencies.include?(currency)
    end

    def total_balance_json
      # Sum the contribution balance (with fees) with the referral balance (without fees)
      total_balance_amount = @contribution_balance.probi + @referral_balance.probi
      {
        "rates" => @rates,
        "altcurrency" => "BAT",
        "probi" => total_balance_amount * BigDecimal.new('1.0e18'),
        "amount" => total_balance_amount,
        "currency" => @default_currency
      }
    end
  end
end
