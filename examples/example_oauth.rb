require "bundler"
Bundler.require

abort("Error starting server - OAUTH2_CLIENT_ID required") unless ENV["OAUTH2_CLIENT_ID"]
abort("Error starting server - OAUTH2_CLIENT_SECRET required") unless ENV["OAUTH2_CLIENT_SECRET"]

Litmus::Instant.base_uri "http://0.0.0.0:3000/v1"

enable :sessions

helpers do
  def signed_in?
    !session[:access_token].nil?
  end
end

get '/' do
  erb :home
end

get '/ping' do
  res = HTTParty.get("http://api.litmus.dev/v2",
    headers: { "Authorization" => "Bearer #{session[:access_token]}" }
  )
  if res.success?
    res.body
  else
    res.inspect
  end
end

get '/example' do
  redirect '/sign-in' unless session[:access_token]

  message = params[:message] || 'Aloha world!'

  result = Litmus::Instant.create_email(
    { 'plain_text' => message },
    token: session[:access_token]
  )
  email_guid = JSON.parse(result.body)['email_guid']
  clients = %w(OL2000 GMAILNEW IPHONE6 THUNDERBIRDLATEST)
  previews = clients.map do |client|
    [client, Litmus::Instant.preview_image_url(email_guid, client, capture_size: 'thumb450')]
  end
  erb :example, locals: { previews: previews }
end

####### OAuth handling

def client(token_method = :post)
  OAuth2::Client.new(
    ENV['OAUTH2_CLIENT_ID'],
    ENV['OAUTH2_CLIENT_SECRET'],
    site: "http://litmus.dev",
    token_method: token_method
  )
end

def access_token
  # makes a server to server request for a token
  OAuth2::AccessToken.new(client, session[:access_token], refresh_token: session[:refresh_token])
end

def redirect_uri
  ENV['OAUTH2_CLIENT_REDIRECT_URI']
end

get '/sign_in' do
  redirect client.auth_code.authorize_url(redirect_uri: redirect_uri) # optional scope: "full"
end

get '/sign_out' do
  session[:access_token] = nil
  redirect '/'
end

get '/callback' do
  new_token = client.auth_code.get_token(params[:code], redirect_uri: redirect_uri)
  session[:access_token]  = new_token.token
  session[:refresh_token] = new_token.refresh_token
  redirect '/'
end

get '/refresh' do
  new_token = access_token.refresh!
  session[:access_token]  = new_token.token
  session[:refresh_token] = new_token.refresh_token
  redirect '/'
end

__END__

@@home
<% if signed_in? %>
  <p>Your are signed in with OAuth</p>
  <a href="/ping">Ping Litmus Personal API</a>
  <a href="/example">Open Instant example</a>
<% else %>
  You are signed out, please <a href="/sign_in">sign in with OAuth</a>
<% end %>

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
