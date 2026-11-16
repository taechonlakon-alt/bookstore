# Idempotent: safe to run `bin/rails db:seed` more than once.
# Development only. Credentials come from the environment (see .env.example).
return unless Rails.env.development?

[
  { email: ENV.fetch("ADMIN_EMAIL"), password: ENV.fetch("ADMIN_PASSWORD"), role: "admin" },
  { email: ENV.fetch("USER_EMAIL"), password: ENV.fetch("USER_PASSWORD"), role: "user" }
].each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.password = attrs[:password] if user.new_record?
  user.role = attrs[:role]
  user.save!
end

books = {
  "Fiction" => [
    { title: "Dune", author: "Frank Herbert", description: "A noble family fights for control of the desert planet Arrakis." },
    { title: "Pride and Prejudice", author: "Jane Austen", description: "Elizabeth Bennet and Mr. Darcy overcome first impressions." }
  ],
  "Science" => [
    { title: "Cosmos", author: "Carl Sagan", description: "A tour of the universe and our place in it." },
    { title: "A Brief History of Time", author: "Stephen Hawking", description: "Black holes, the Big Bang and the nature of time." }
  ],
  "History" => [
    { title: "Sapiens", author: "Yuval Noah Harari", description: "A short history of humankind." },
    { title: "Guns, Germs, and Steel", author: "Jared Diamond", description: "Why some societies came to dominate others." }
  ]
}

books.each do |category_name, category_books|
  category = Category.find_or_create_by!(name: category_name)
  category_books.each do |attrs|
    Book.find_or_create_by!(title: attrs[:title]) do |book|
      book.author = attrs[:author]
      book.description = attrs[:description]
      book.category = category
    end
  end
end

markets = {
  "Central Market" => [ "Dune", "Cosmos", "Sapiens" ],
  "Online Store" => Book.pluck(:title)
}

markets.each do |name, titles|
  Market.find_or_create_by!(name: name) do |market|
    market.books = Book.where(title: titles)
  end
end
