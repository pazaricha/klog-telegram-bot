class TelegramWebhooksController < Telegram::Bot::UpdatesController
  def start!(*)
    respond_with :message, text: t('.hi')
  end

  def message(params)
    author_id = params['from']['id']
    post_to_klog_server(author_id, params['text'])
    respond_with :message, text: "I have forwarded you complaint to a CM and you will recieve a response shortly."
    respond_with :message, text: "Cheer up :)"
    respond_with :photo, photo: File.open("#{Rails.root}/#{[1,2,3].sample}.jpg")
  end

  private

  def post_to_klog_server(author_id, text)
    RestClient.post('https://klog-staging.herokuapp.com/api/v1/complaint', { session_id: author_id, text: text }.to_json)
  end

end
