class Admin::MarketsController < Admin::BaseController
  before_action :set_market, only: %i[edit update destroy]

  def index
    @markets = Market.includes(:books).order(:name)
  end

  def new
    @market = Market.new
  end

  def create
    @market = Market.new(market_params)
    if @market.save
      redirect_to admin_markets_path, notice: "Market was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @market.update(market_params)
      redirect_to admin_markets_path, notice: "Market was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @market.destroy
    redirect_to admin_markets_path, notice: "Market was deleted."
  end

  private

  def set_market
    @market = Market.find(params[:id])
  end

  def market_params
    params.expect(market: [ :name, book_ids: [] ])
  end
end
