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
    session[:return_to] = request.url unless request.url =~ /sign_in/
    redirect client.auth_code.authorize_url(redirect_uri: redirect_uri) # optionally specify scope: "full"
  end

  def signed_in?
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
    return if signed_in? && !token_expired?

    if refresh_available?
      refresh_token!
    else
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

get '/sign_in' do
  user_authorize! unless signed_in?
end

get '/sign_out' do
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

__END__

@@home
<% if signed_in? %>
  <p>Your are signed in with OAuth</p>
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
