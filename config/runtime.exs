import Config
import Dotenvy

source!(".env")

config :instructor,
  adapter: Instructor.Adapters.OpenAI,
  openai: [api_key: env!("OPENAI_API_KEY")]
