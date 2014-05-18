MyApp::Application.routes.draw do
  # Authorization flow.
  match "oauth/authorize" => "oauth#authorize", via: :all
  match "oauth/grant" => "oauth#grant", via: :all
  match "oauth/deny" => "oauth#deny", via: :all

  # Resources we want to protect
  match ":action"=>"api", via: :all

  mount Rack::OAuth2::Server::Admin, :at=>"oauth/admin"

end
