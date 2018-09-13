require "test_helper"
require "eyeshade/balance"

class PublisherBalanceGetterTest < ActiveJob::TestCase

  before(:example) do
    @prev_offline = Rails.application.secrets[:api_eyeshade_offline]
  end

  after(:example) do
    Rails.application.secrets[:api_eyeshade_offline] = @prev_offline
  end

  TRANSACTIONS_RESPONSE = [
    {
      "created_at" => "2018-04-03T00:23:09.000Z",
      "description" => "referrals in March",
      "channel" => "diracdeltas.github.io",
      "amount" => "94.617182149806375904",
      "type" => "referral"
    },
    {
      "created_at" => "2018-04-08T00:23:09.000Z",
      "description" => "contributions in March",
      "channel" => "diracdeltas.github.io",
      "amount" => "294.617182149806375904",
      "type" => "contribution"
    },
    {
      "created_at" => "2018-04-08T00:23:10.000Z",
      "description" => "settlement fees for contributions",
      "channel" => "diracdeltas.github.io",
      "amount" => "-14.730859107490318795",
      "type" => "fee"
    },
    {
      "created_at" => "2018-04-08T00:23:11.000Z",
      "description" => "payout for contributions",
      "channel" => "diracdeltas.github.io",
      "amount" => "-279.886323042316057109",
      "settlement_currency"=> "USD",
      "settlement_amount"=> "56.81",
      "type" => "contribution_settlement"
    },
    {
      "created_at" => "2018-04-08T00:33:09.000Z",
      "description" => "payout for referrals",
      "channel" => "diracdeltas.github.io",
      "amount" => "-94.617182149806375904",
      "settlement_currency" => "USD",
      "settlement_amount" => "18.81",
      "type" => "referral_settlement"
    }
  ]

  # test "returns an empty Eyeshade::Balance if there are no transactions" do
  #   Rails.application.secrets[:api_eyeshade_offline] = false
  #   publisher = publishers(:completed)

  #   stub_request(:get, %r{v1/accounts/#{URI.escape(publisher.owner_identifier)}/transactions}).
  #     to_return(status: 200, body: [].to_json)

  #   result = PublisherTransactionsGetter.new(publisher: publisher).perform
  #   assert result.is_a?(Eyeshade::Balance)
  #   assert_equal result.probi, 0
  # end

  # test "discards transactions from previous settlements" do
  #   Rails.application.secrets[:api_eyeshade_offline] = false
  #   publisher = publishers(:completed)
  #   stub_request(:get, %r{v1/accounts/#{URI.escape(publisher.owner_identifier)}/transactions}).
  #     to_return(status: 200, body: TRANSACTIONS_RESPONSE.to_json )
  #   result = PublisherTransactionsGetter.new(publisher: publisher).perform
  # end

  test "" do
    Rails.application.secrets[:api_eyeshade_offline] = false
    publisher = publishers(:uphold_connected)
    result = PublisherTransactionsGetter.new(publisher: publisher).perform_offline
    debugger
  end
end
