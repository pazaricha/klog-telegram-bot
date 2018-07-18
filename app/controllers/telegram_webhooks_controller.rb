class TelegramWebhooksController < Telegram::Bot::UpdatesController
  def start!(*)
    respond_with :message, text: t('.hi')
  end

  def help!(*)
    respond_with :message, text: "yo"
  end
end
