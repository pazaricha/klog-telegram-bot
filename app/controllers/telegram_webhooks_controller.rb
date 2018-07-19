class TelegramWebhooksController < Telegram::Bot::UpdatesController
  def start!(*)
    respond_with :message, text: t('.hi')
  end

  def message(params)
    respond_with :message, text: "Processing your complaint..."

    author_name = "#{params['from']['first_name']} #{params['from']['last_name']}"
    author_id = params['from']['id']

    real_type = message_type(params)

    case real_type
    when 'text'
      post_to_klog_server(author_id: author_id, author_name: author_name, text: params['text'])
    else
      file_id = get_file_id(params)

      temp_file_object = RestClient.get("https://api.telegram.org/bot#{bot.token}/getFile?file_id=#{file_id}")

      file_name = get_file_name(temp_file_object)
      file_type = get_file_type(temp_file_object)
      final_file_name = "telegram-bot-#{file_name}.#{file_type}"

      raw = RestClient::Request.execute(
           method: :get,
           url: "https://api.telegram.org/file/bot#{bot.token}/#{JSON.parse(temp_file_object.body)['result']['file_path']}",
           raw_response: true)

      aws_client = Aws::S3::Client.new(
       access_key_id: ENV['AWS_ACCESS_KEY_ID'],
       secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
       region: ENV['AWS_REGION']
     )

      s3 = Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
        region: ENV['AWS_REGION']
      )

      bucket = s3.bucket('klog-complaint-images')

      obj = bucket.object(final_file_name)
      obj.upload_file(raw.file.path, { acl: 'public-read' })
      asset_url = obj.public_url

      caption = params['caption']

      post_to_klog_server(author_id: author_id, author_name: author_name, asset_url: asset_url, text: caption)
    end

    respond_with :message, text: "I have forwarded your complaint to a CM and you will recieve a response shortly."
    sleep(1)
    respond_with :message, text: "Cheer up :)"
    sleep(1)
    respond_with :photo, photo: File.open("#{Rails.root}/#{[1,2,3].sample}.jpg")
  end

  private

  def message_type(params)
    return 'text' if params['text'].present?
    return 'photo' if params['photo'].present?
    return 'voice' if params['voice'].present?
  end

  def get_file_id(params)
    return params['photo'].last['file_id'] if message_type(params) == 'photo'
    return params['voice']['file_id'] if message_type(params) == 'voice'
    return params['document']['file_id'] if message_type(params) == 'document'
  end

  def get_file_name(temp_file_object)
    JSON.parse(temp_file_object.body)['result']['file_path'].split('/').last.match(/(.+)\.(.+)$/)[1]
  end

  def get_file_type(temp_file_object)
    JSON.parse(temp_file_object.body)['result']['file_path'].split('/').last.match(/(.+)\.(.+)$/)[2]
  end

  def post_to_klog_server(options)
    RestClient.post('https://klog-staging.herokuapp.com/api/v1/complaint', { session_id: options[:author_id], name: options[:author_name], text: options[:text], asset_url: options[:asset_url] })
  end

end
