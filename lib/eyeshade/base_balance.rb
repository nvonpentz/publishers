module Eyeshade
  class BaseBalance
    attr_reader :rates,
                :default_currency,
                :amount_probi,
                :amount_bat,
                :amount_default_currency,
                :fees_probi,
                :fees_bat,
                :fees_default_currency

    # Account types
    CHANNEL = "channel".freeze
    OWNER = "owner".freeze

    def initialize(rates, default_currency)
      @rates = rates
      @default_currency = default_currency || "BAT"
    end

    private

    # Expects and returns a string
    def probi_to_bat(probi)
      "#{probi.to_i.to_d / 1E18}"
    end

    # Expects and returns a string
    def bat_to_probi(bat)
      "#{(bat.to_d * BigDecimal.new('1.0e18')).to_i}"
    end

    # Expects and returns values with probi unit
    def calc_fees(total_probi)
      total_probi = total_probi.to_i
      fees_probi = (total_probi * fee_rate).to_i
      amount_probi = total_probi - fees_probi
      {"amount" => "#{amount_probi}", "fees" => "#{fees_probi}"}
    end

    def convert(amount_bat, currency)
      return amount_bat if currency == "BAT"
      return if @rates[currency].nil?
      "#{'%.2f' % (amount_bat.to_d * @rates[currency])}"
    end

    def fee_rate
      Rails.application.secrets[:fee_rate].to_d
    end
  end

  class ChannelBalance < BaseBalance
    def initialize(rates, default_currency, account)
      super(rates, default_currency)
      total_probi = bat_to_probi(account["balance"])
      amount_and_fees = calc_fees(total_probi)
      @amount_probi = amount_and_fees["amount"]
      @fees_probi = amount_and_fees["fees"]

      @amount_bat = '%.2f' % probi_to_bat(@amount_probi)
      @fees_bat = '%.2f' % probi_to_bat(@fees_probi)
      @amount_default_currency = convert(@amount_bat, @default_currency)
      @fees_default_currency = convert(@fees_bat, @default_currency)
    end 
  end

  class OverallBalance < BaseBalance
    def initialize(rates, default_currency, accounts)
      super(rates, default_currency)

      @amount_probi = "0"
      @fees_probi = "0"

      accounts.each do |account|
        if account["account_type"] == CHANNEL
          channel_balance = Eyeshade::ChannelBalance.new(@rates, @default_currency, account)
          @amount_probi = (@amount_probi.to_i + channel_balance.amount_probi.to_i).to_s
          @fees_probi = (@fees_probi.to_i + channel_balance.fees_probi.to_i).to_s
        else
          referral_balance = Eyeshade::ReferralBalance.new(@rates, @default_currency, accounts)
          @amount_probi = (@amount_probi.to_i + referral_balance.amount_probi.to_i).to_s
        end
      end

      @amount_bat = '%.2f' % probi_to_bat(@amount_probi)
      @fees_bat = '%.2f' % probi_to_bat(@fees_probi)
      @amount_default_currency = convert(@amount_bat, @default_currency)
      @fees_default_currency = convert(@fees_bat, @default_currency)
    end
  end

  class ReferralBalance < BaseBalance
    def initialize(rates, default_currency, accounts)
      super(rates, default_currency)
      owner_account = accounts.select { |account| account["account_type"] == OWNER}.first || {}

      unless owner_account["balance"].nil?
        @amount_bat = owner_account["balance"]
      else
        @amount_bat = "0.00"
      end

      @fees_bat = "0.00"
      @amount_probi = bat_to_probi(@amount_bat)
      @fees_probi = "0"
      @amount_default_currency = convert(@amount_bat, @default_currency)
      @fees_default_currency = "0.00"
    end
  end

  class LastSettlementBalance < BaseBalance
    attr_reader :date, :amount_settlement_currency, :timestamp, :settlement_currency

    def initialize(rates, default_currency, transactions)
      super(rates, default_currency)

      last_settlement = calc_last_settlement(transactions)
      @amount_bat = last_settlement["amount_bat"]
      @timestamp = last_settlement["timestamp"]
      @settlement_currency = last_settlement["currency"]
      @amount_settlement_currency = convert(@amount_bat, @settlement_currency)
    end

    private

    def calc_last_settlement(transactions)
      return {} if transactions == []
       # Find most recent settlement transaction
      last_settlement_date = transactions.select { |transaction|
        transaction["settlement_amount"].present?
      }.last["created_at"].to_date # Eyeshade returns transactions ordered_by created_at

       # Find all settlement transactions that occur within the same month as the last settlement timestamp
      last_settlement_transactions = transactions.select { |transaction|
        transaction["created_at"].to_date.at_beginning_of_month == last_settlement_date.at_beginning_of_month &&
        transaction["settlement_amount"].present?
      }

      last_settlement_currency = last_settlement_transactions&.first["settlement_currency"] || nil
      last_settlement_bat = last_settlement_transactions.map { |transaction|
        transaction["settlement_amount"].to_d
      }.reduce(:+)

      {"amount_bat" => last_settlement_bat.to_s, "timestamp" => last_settlement_date.to_time.to_i, "currency" => last_settlement_currency}
    end
  end
end
