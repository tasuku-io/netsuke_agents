ExUnit.start()

# Load all fixture files
for file <- Path.wildcard("#{__DIR__}/support/fixtures/*.exs") do
  Code.require_file(file)
end
