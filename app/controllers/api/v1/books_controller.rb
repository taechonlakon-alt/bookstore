class Api::V1::BooksController < Api::V1::BaseController
  def index
    authorize Book
    books = Book.includes(:category, :markets).order(:id)
    render json: books, **json_options, status: :ok
  end

  def show
    authorize Book
    book = Book.find_by(id: params[:id])

    if book.present?
      render json: book, **json_options, status: :ok
    else
      render json: { error: "Book not found" }, status: :not_found
    end
  end

  def create
    authorize Book
    book = Book.new(book_params)

    if book.save
      render json: book, **json_options, status: :created
    else
      render json: { errors: book.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize Book
    book = Book.find_by(id: params[:id])
    return render json: { error: "Book not found" }, status: :not_found if book.nil?

    if book.update(book_params)
      render json: book, **json_options, status: :ok
    else
      render json: { errors: book.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize Book
    book = Book.find_by(id: params[:id])
    return render json: { error: "Book not found" }, status: :not_found if book.nil?

    if book.destroy
      render json: { message: "Book deleted" }, status: :ok
    else
      render json: { errors: book.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def json_options
    { only: [ :id, :title, :author, :description ],
      include: { category: { only: [ :id, :name ] }, markets: { only: [ :id, :name ] } } }
  end

  def book_params
    params.expect(book: [ :title, :author, :description, :category_id ])
  end
end
