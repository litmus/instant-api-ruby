#
# Things this demo doesn't currently demonstrate:
# - rate limiting, client restrictions
# - automatically re-authenticating on Instant errors prompting re-auth
#

require "bundler"
Bundler.require

abort("Error starting server - OAUTH2_CLIENT_ID required") unless ENV["OAUTH2_CLIENT_ID"]
abort("Error starting server - OAUTH2_CLIENT_SECRET required") unless ENV["OAUTH2_CLIENT_SECRET"]

Litmus::Instant.base_uri "http://0.0.0.0:3000/v1"
Litmus::Instant.debug_output $stdout

enable :sessions

helpers do
  def client(token_method = :post)
    OAuth2::Client.new(
      ENV['OAUTH2_CLIENT_ID'],
      ENV['OAUTH2_CLIENT_SECRET'],
      site: "http://litmus.dev",
      token_method: token_method
    )
  end

  def user_authorize!
    session[:return_to] = request.url unless request.url =~ /connect/
    redirect client.auth_code.authorize_url(redirect_uri: redirect_uri) # optionally specify scope: "full"
  end

  def connected?
    !session[:access_token].nil?
  end

  def refresh_available?
    !session[:refresh_token].nil?
  end

  def refresh_token!
    # makes a server to server request for a token
    new_token = OAuth2::AccessToken.new(
      client, session[:access_token], refresh_token: session[:refresh_token]
    ).refresh!
    store_token(new_token)
  end

  def store_token(token)
    # Note: you'd usually persist this information, we only keep it on the
    # session to keep this demo simple
    session[:access_token]  = token.token
    session[:refresh_token] = token.refresh_token
    session[:expires_at]    = token.expires_at
  end

  def redirect_uri
    request.base_url + "/callback" # eg http://0.0.0.0:4567/callback
  end

  def token_expired?
    session[:expires_at] && (Time.at(session[:expires_at]) < Time.now)
  end

  # Ensure we have a valid OAuth token before making API calls
  def oauthorize!
    # Arguably we should be hitting an endpoint to check the token hasn't been
    # invalidated since we received it, rather than relying on what we knew when
    # we received it.
    return if connected? && !token_expired?

    if refresh_available?
      refresh_token!
    else
      # If the user's already authorized the app and they're logged in to
      # litmus, this
      # will be invisible to the user (just some redirects while we receive a
      # new token)
      user_authorize!
    end
  end
end

get '/' do
  erb :home
end

get '/example' do
  oauthorize!

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

# for Oauth:

get '/connect' do
  user_authorize! unless connected?
end

get '/sign_out' do
  # This clears our local session, but the OAuth Provider will still remember
  # that the user granted access to this application next time they connect
  session.clear
  redirect '/'
end

get '/callback' do
  new_token = client.auth_code.get_token(params[:code], redirect_uri: redirect_uri)
  store_token(new_token)
  redirect(session[:return_to] || "/")
end

get '/refresh' do
  refresh_token!
  redirect '/'
end

error Litmus::Instant::InvalidOAuthToken do
  # perhaps access has been revoked since we received the last token
  user_authorize!
end

__END__

@@home
<h1>Example Partner App</h1>
<% if connected? %>
  <p>Your are connected with Litmus OAuth</p>
  <a href="/example">Open Instant example</a>
  <a href="/sign_out">Disconnect</a>
<% else %>
  You are signed out, please <a href="/connect">Connect with Litmus</a> or
  <a href="https://litmus.com#cobranded-landing">Learn more</a>
<% end %>

@@example
<h1>Example Partner App</h1>
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
