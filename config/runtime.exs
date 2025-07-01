import Config
import Dotenvy

source!(".env")

api_key = case System.get_env("OPENAI_API_KEY") do
  nil ->
    env!("OPENAI_API_KEY")
  key when is_binary(key) ->
    key
end

config :instructor,
  adapter: Instructor.Adapters.OpenAI,
  openai: [api_key: api_key]
