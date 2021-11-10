require "bundler"
Bundler.require

Litmus::Instant.api_key = ENV["API_KEY"] or abort("Error starting server - API_KEY required")

get '/' do
  '<a href="/example">Open example</a>'
end

get '/example' do
  message = params[:message] || 'Aloha world!'

  result = Litmus::Instant.create_email('plain_text' => message)

  email_guid = JSON.parse(result.body)['email_guid']
  clients = %w(OL2019 GMAILNEW IPHONE13 THUNDERBIRDLATEST)
  previews = clients.map do |client|
    [client, Litmus::Instant.preview_image_url(email_guid, client, capture_size: 'thumb450')]
  end
  erb :example, locals: { previews: previews }
end

__END__

@@example
<p>
  Add your custom message as a parameter,
  <a href="?message=I like marmots">eg like this</a>.
<p>
<% previews.each do |client, url| %>
  <figure>
    <figcaption><%= client %></figcaption>
    <img src="<%= url %>">
  </figure>
<% end %>
