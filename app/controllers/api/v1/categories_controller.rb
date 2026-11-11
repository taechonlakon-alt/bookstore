class Api::V1::CategoriesController < Api::V1::BaseController
  before_action :require_admin, only: %i[create update destroy]

  def index
    categories = Category.includes(:books).order(:id)
    render json: categories, **json_options, status: :ok
  end

  def show
    category = Category.find_by(id: params[:id])

    if category.present?
      render json: category, **json_options, status: :ok
    else
      render json: { error: "Category not found" }, status: :not_found
    end
  end

  def create
    category = Category.new(category_params)

    if category.save
      render json: category, **json_options, status: :created
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    category = Category.find_by(id: params[:id])
    return render json: { error: "Category not found" }, status: :not_found if category.nil?

    if category.update(category_params)
      render json: category, **json_options, status: :ok
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    category = Category.find_by(id: params[:id])
    return render json: { error: "Category not found" }, status: :not_found if category.nil?

    if category.destroy
      render json: { message: "Category deleted" }, status: :ok
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def category_params
    params.expect(category: [ :name ])
  end

  def json_options
    { only: [ :id, :name ], include: { books: { only: [ :id, :title ] } } }
  end
end
