class Admin::PayoutReportsController < AdminController
  attr_reader :payout_report

  def index
    @payout_reports = PayoutReport.all.order(created_at: :desc).paginate(page: params[:page])
  end

  def show
    @payout_report = PayoutReport.find(params[:id])
    render(json: @payout_report.contents, status: 200)
  end

  def download    
    @payout_report = PayoutReport.find(params[:id])

    contents = assign_authority(payout_report.contents)

    send_data contents,
      filename: "payout-#{payout_report.created_at.strftime("%FT%H-%M-%S")}",
      type: :json
  end

  def create
    GeneratePayoutReportJob.perform_later(final: params[:final].present?,
                                          should_send_notifications: params[:should_send_notifications].present?)

    redirect_to admin_payout_reports_path, flash: { notice: "Your payout report is being generated, check back soon." }
  end

  private

  def assign_authority(report_contents)
    report_contents = JSON.parse(report_contents)
    
    report_contents.each do |channel|
      channel["authority"] = current_publisher.email # Assigns authority to admin email
    end

    report_contents.to_json
  end
end
