namespace :active_admin do
  tailwind_command = -> {
    [ Tailwindcss::Ruby.executable, "-i", "app/assets/stylesheets/active_admin.css", "-o", "app/assets/builds/active_admin.css" ]
  }

  desc "Build the ActiveAdmin stylesheet with the Tailwind standalone binary"
  task build_css: :environment do
    system(*tailwind_command.call, "--minify", exception: true)
  end

  desc "Watch the ActiveAdmin stylesheet and rebuild it with the Tailwind standalone binary"
  task watch_css: :environment do
    system(*tailwind_command.call, "--watch", exception: true)
  end
end

Rake::Task["tailwindcss:build"].enhance { Rake::Task["active_admin:build_css"].invoke }
