class Api::V1::MarketsController < Api::V1::BaseController
  def index
    authorize Market
    markets = Market.includes(:books).order(:id)
    render json: markets, **json_options, status: :ok
  end

  def show
    authorize Market
    market = Market.find_by(id: params[:id])

    if market.present?
      render json: market, **json_options, status: :ok
    else
      render json: { error: "Market not found" }, status: :not_found
    end
  end

  def create
    authorize Market
    market = Market.new(market_params)

    if market.save
      render json: market, **json_options, status: :created
    else
      render json: { errors: market.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize Market
    market = Market.find_by(id: params[:id])
    return render json: { error: "Market not found" }, status: :not_found if market.nil?

    if market.update(market_params)
      render json: market, **json_options, status: :ok
    else
      render json: { errors: market.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize Market
    market = Market.find_by(id: params[:id])
    return render json: { error: "Market not found" }, status: :not_found if market.nil?

    if market.destroy
      render json: { message: "Market deleted" }, status: :ok
    else
      render json: { errors: market.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def json_options
    { only: [ :id, :name ], include: { books: { only: [ :id, :title ] } } }
  end

  def market_params
    params.expect(market: [ :name, book_ids: [] ])
  end
end
