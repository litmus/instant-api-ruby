require "bundler"
Bundler.require

Litmus::Instant.api_key = ENV["API_KEY"] or abort("Error starting server - API_KEY required")

get '/' do
  '<a href="/example">Open example</a>'
end

get '/example' do
  result = Litmus::Instant.create_email(
    'html_text' => File.read('email/test-email.html').gsub(
      "Crafting your perfect subject line",
      "#{params[:message] || Time.now}"
    )
  )

  email_guid = JSON.parse(result.body)['email_guid']

  all_clients = Litmus::Instant.clients
  # Server-side ask the API to prefetch all clients (non-blocking)
  capture_configurations = all_clients.map do |client|
    { client: client, orientation: "vertical", images: "allowed" }
  end
  Litmus::Instant.prefetch_previews(email_guid, capture_configurations)

  # Provide the user's browser the preview URLs, by the time it comes to request
  # them capture will already be in progress, so wait time should be minimised.
  previews = all_clients.map do |client|
    [
      client,
      Litmus::Instant.preview_image_url(email_guid, client, capture_size: 'thumb'),
      Litmus::Instant.preview_image_url(email_guid, client, capture_size: 'full')
    ]
  end
  erb :example, locals: { previews: previews }
end

__END__

@@example
<p>
  Add your custom message as a parameter,
  <a href="?message=I like marmots">eg like this</a>.
<p>
<% previews.each do |client, thumb_url, full_url| %>
  <a href="<%= full_url %>">
    <img src="<%= thumb_url %>" title="<%= client %>" width="119" height="84">
  </a>
<% end %>
