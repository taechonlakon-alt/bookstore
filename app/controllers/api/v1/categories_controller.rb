class Api::V1::CategoriesController < Api::V1::BaseController
  def index
    authorize Category
    categories = Category.includes(:books).order(:id)
    render json: categories, **json_options, status: :ok
  end

  def show
    authorize Category
    category = Category.find_by(id: params[:id])

    if category.present?
      render json: category, **json_options, status: :ok
    else
      render json: { error: "Category not found" }, status: :not_found
    end
  end

  def create
    authorize Category
    category = Category.new(category_params)

    if category.save
      render json: category, **json_options, status: :created
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize Category
    category = Category.find_by(id: params[:id])
    return render json: { error: "Category not found" }, status: :not_found if category.nil?

    if category.update(category_params)
      render json: category, **json_options, status: :ok
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize Category
    category = Category.find_by(id: params[:id])
    return render json: { error: "Category not found" }, status: :not_found if category.nil?

    if category.destroy
      render json: { message: "Category deleted" }, status: :ok
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def json_options
    { only: [ :id, :name ], include: { books: { only: [ :id, :title ] } } }
  end

  def category_params
    params.expect(category: [ :name ])
  end
end
