require "eyeshade/balance"

# Retrieves a list of transactions for an owner account
class PublisherTransactionsGetter < BaseApiClient
  attr_reader :publisher


  def initialize(publisher:)
    @publisher = publisher 
  end

  def perform
    return perform_offline if Rails.application.secrets[:api_eyeshade_offline]
    response = connection.get do |request|
      request.headers["Authorization"] = api_authorization_header
      request.url("v1/accounts/#{URI.escape(publisher.owner_identifier)}/transactions")
    end
    # last_settlement_balance(JSON.parse(response.body))
    response
    # Example eyeshade response
    # [
    #   {
    #     "created_at": "2018-04-08T00:23:09.000Z",
    #     "description": "contributions in March",
    #     "channel": "diracdeltas.github.io",
    #     "amount": "294.617182149806375904",
    #     "type": "contribution"
    #   },
    #   {
    #     "created_at": "2018-04-08T00:23:10.000Z",
    #     "description": "settlement fees for contributions",
    #     "channel": "diracdeltas.github.io",
    #     "amount": "-14.730859107490318795",
    #     "type": "fee"
    #   },
    #   {
    #     "created_at": "2018-04-08T00:33:09.000Z",
    #     "description": "payout for referrals",
    #     "channel": "diracdeltas.github.io",
    #     "amount": "-94.617182149806375904",
    #     "settlement_currency": "USD",
    #     "settlement_amount": "18.81",
    #     "type": "referral_settlement"
    #   }
    # ]
  end

  def perform_offline
    transactions = []
    i = 0
    8.times do 
      publisher.channels.verified.each do |channel|
        # Contributions
        transactions.push({
          "created_at" => i.month.ago.at_beginning_of_month + 6.days + rand(0..30).minutes,
          "channel" => "#{channel.details.channel_identifier}",
          "amount" => "#{rand(0..1000)}",
          "settlement_currency" => publisher.default_currency,
          "type" => "contribution_settlement"
        })

        # Referrals
        transactions.push({
          "created_at" => i.month.ago.at_beginning_of_month + 6.days + rand(0..30).minutes,
          "channel" => "#{channel.details.channel_identifier}",
          "amount" => "#{rand(0..1000)}",
          "settlement_currency" => publisher.default_currency,
          "type" => "referral_settlement"
        })
      end
      i += 1
    end    
    sort_transactions_into_monthly_settlements(transactions).to_json
  end

  private

  def sort_transactions_into_monthly_settlements(transactions)
    transactions.group_by { |transaction|
      transaction["created_at"].to_time.at_beginning_of_month
    }.map { |transactions_in_month|
      transactions_in_month.second.reduce({"date" => "#{Time.new(0)}"}) { |transactions_settled, transaction|
        if transaction["created_at"] > transactions_settled["date"]
          transactions_settled["date"] = transaction["created_at"]
        end
        if transactions_settled[transaction["channel"]].present?
          transactions_settled[transaction["channel"]] += transaction["amount"].to_d
        else
          transactions_settled[transaction["channel"]] = transaction["amount"].to_d
        end
        transactions_settled
      }
    }.map { |settlement_for_month|
      settlement_for_month["date"] = settlement_for_month["date"].strftime("%d/%m")
      settlement_for_month 
    }
    # Example return value
    #  {
    #    date: '7/30',
    #    'youtube#channel:UCtsfHRe2WQnkNH5WYJWL-Yw': 63,
    #    'amazingblog.com': 200,
    #    'Amazon.com': 50
    #  },
    #  {
    #    date: '8/30',
    #    'youtube#channel:UCtsfHRe2WQnkNH5WYJWL-Yw': 150,
    #    'amazingblog.com': 100,
    #    'Amazon.com': 350
    #  }
    # ]
  end

  def last_settlement_balance(transactions)
    return Eyeshade::Balance.new(balance_json: {}) if transactions.empty?

    last_settlement_date = last_settlement_date(transactions)
    settlement_date_cutoff = last_settlement_date.at_beginning_of_month
    settlement_transactions = settlement_transactions(transactions, settlement_date_cutoff)

    last_settlement_bat = last_settlement_bat(settlement_transactions)
    last_settlement_currency = settlement_transactions.first["settlement_currency"]

    Eyeshade::Balance.new(balance_json:{
      "altcurrency"=>"BAT",
      "currency"=> "#{last_settlement_currency}",
      "probi"=> last_settlement_bat * BigDecimal.new('1.0e18'),
      "amount"=> last_settlement_bat,
      "timestamp"=> last_settlement_date.to_i
    })
  end

  def last_settlement_date(transactions)
    transactions.map { |transaction|
      transaction["created_at"].to_time
    }.reduce(Time.new(0)) { |most_recent_date, date|
      (most_recent_date > date) ? most_recent_date : date
    }
  end

  def settlement_transactions(transactions, settlement_date_cutoff)
    transactions.select { |transaction|
        transaction["created_at"] > settlement_date_cutoff &&
        (transaction["type"] == "referral_settlement") || (transaction["type"] == "contribution_settlement")
      }
  end

  def last_settlement_bat(settlement_transactions)
    settlement_transactions.reduce(BigDecimal.new('0.0e18')) { |sum, transaction| sum + transaction["amount"].to_d.abs }
  end

  def api_base_uri
    Rails.application.secrets[:api_eyeshade_base_uri]
  end

  def api_authorization_header
    "Bearer #{Rails.application.secrets[:api_eyeshade_key]}"
  end
end
