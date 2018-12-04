require "eyeshade/wallet"

# Query wallet balance from Eyeshade
class PublisherWalletGetter < BaseApiClient
  attr_reader :publisher

  def initialize(publisher:)
    @publisher = publisher
  end

  def perform
    return perform_offline if Rails.application.secrets[:api_eyeshade_offline]

    # Eyeshade only creates an account for an owner when they connect to Uphold.
    # Until then, the request to get the wallet information for the owner will 404.
    # In that case we use an empty wallet, but still use balances from the balance getter.
    begin
      wallet_response = connection.get do |request|
        request.headers["Authorization"] = api_authorization_header
        request.url("/v1/owners/#{URI.escape(publisher.owner_identifier)}/wallet")
      end

      # Save wallet infornation but ignore all balance values from wallet endpoint
      wallet_hash = JSON.parse(wallet_response.body).slice("status", "rates", "wallet")
    rescue Faraday::ResourceNotFound
      wallet_hash = {}
    end

    # Use balance endpoint to get account balances
    if publisher.channels.verified.any?
      accounts = PublisherBalanceGetter.new(publisher: publisher).perform
      return if accounts == :unavailable

      # Convert accounts into Eyeshade::Wallet format
      rates = wallet_hash["rates"]

      accounts_hash = balance_hash(accounts, rates)

      channel_accounts = accounts.reject { |account| account["account_id"].starts_with?(Publisher::OWNER_PREFIX)}
      contributions_hash = balance_hash(channel_accounts, rates)

      referrals_account = accounts.select { |account| account["account_id"].starts_with?(Publisher::OWNER_PREFIX)}
      referrals_hash = balance_hash(referrals_account, rates)
    else
      accounts_hash = {}
      contributions_hash = {}
      referrals_hash = {}
    end

    Eyeshade::Wallet.new(wallet_hash: wallet_hash,
                         accounts_hash: accounts_hash,
                         contributions_hash: contributions_hash,
                         referrals_hash: referrals_hash)

  rescue Faraday::Error => e
    Rails.logger.warn("PublisherWalletGetter #perform error: #{e}")
    nil
  end

  def perform_offline
    Rails.logger.info("PublisherWalletGetter returning offline stub balance.")

    wallet_hash = {
        "status" => {
            "provider" => "uphold",
            # "action" => "re-authorize"
            # "action" => "authorize"
        },
        "contributions" => {
          "amount" => "9001.00",
          "currency" => "USD",
          "altcurrency" => "BAT",
          "probi" => "38077497398351695427000"
        },
        "rates" => {
          "BTC" => 0.00005418424016883016,
          "ETH" => 0.000795331082073117,
          "USD" => 0.2363863335301452,
          "EUR" => 0.20187818378874756,
          "GBP" => 0.1799810085548496
        },
        "lastSettlement"=>
          {"altcurrency"=>"BAT",
           "currency"=>"USD",
           "probi"=>"405520562799219044167",
           "amount"=>"69.78",
           "timestamp"=>1536361540000},
        "wallet" => {
            "provider" => "uphold",
            "authorized" => true,
            "defaultCurrency" => "USD",
            "availableCurrencies" => [ "USD", "EUR", "BTC", "ETH", "BAT" ],
            "possibleCurrencies"=> ["AED", "ARS", "AUD", "BRL", "CAD", "CHF", "CNY", "DKK", "EUR", "GBP", "HKD", "ILS", "INR", "JPY", "KES", "MXN", "NOK", "NZD", "PHP", "PLN", "SEK", "SGD", "USD", "XAG", "XAU", "XPD", "XPT"],
            "scope"=> "cards:read user:read"
        },

      }

    if publisher.channels.verified.any?
      accounts = PublisherBalanceGetter.new(publisher: publisher).perform
      return if accounts == :unavailable

      # Convert accounts into Eyeshade::Wallet format
      rates = wallet_hash["rates"]

      accounts_hash = balance_hash(accounts, rates)

      channel_accounts = accounts.reject { |account| account.starts_with?(Publisher::OWNER_PREFIX)}
      contributions_hash = balance_hash(channel_accounts, rates)

      referrals_account = accounts.select { |account| account.starts_with?(Publisher::OWNER_PREFIX)}
      referrals_hash = balance_hash(referrals_account, rates)
    else
      accounts_hash = {}
      contributions_hash = {}
      referrals_hash = {}
    end

    Eyeshade::Wallet.new(wallet_hash: wallet_hash,
                         accounts_hash: accounts_hash,
                         contributions_hash: contributions_hash,
                         referrals_hash: referrals_hash)
  end

  private

  # Converts the accounts returned in the PublisherBalanceGetter
  # into a format suitable for the Eyeshade::Wallet / Eyeshade::Balance
  def balance_hash(accounts, rates)
    currency = publisher.default_currency
    accounts_hash = {}

    accounts.each do |account|
      account_identifier = account["account_id"]
      account_balance = account["balance"]

      accounts_hash[account_identifier] = {
        "rates" => rates,
        "altcurrency" => "BAT",
        "probi" => account_balance.to_d * BigDecimal.new('1.0e18'),
        "amount" => account_balance,
        "currency" => currency
      }
    end

    accounts_hash
  end

  def api_base_uri
    Rails.application.secrets[:api_eyeshade_base_uri]
  end

  def api_authorization_header
    "Bearer #{Rails.application.secrets[:api_eyeshade_key]}"
  end
end
