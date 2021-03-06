require 'sinatra'
require 'httparty'
require 'json'
require 'rspotify'
# uncomment the line below for running on local machines, where secret.rb contains API keys
# require_relative 'secret'

# get config vars (API keys) from Heroku
Y_API_KEY   = ENV['Y_API_KEY']
S_API_KEY   = ENV['S_API_KEY']
S_SECRET    = ENV['S_SECRET']
LF_API_KEY  = ENV['LF_API_KEY']

error 400..510 do
  redirect to('/error')
end


# home
get '/' do
  erb :index
end


# when a user searches for an artist, redirect them to that artist's page
post '/' do
  @artistNameEscaped = params[:artist].gsub(' ', '%20')
  redirect to("/artist/#{@artistNameEscaped}")
end


post '/artist/*' do
  @artistNameEscaped = params[:artist].gsub(' ', '%20')
  redirect to("/artist/#{@artistNameEscaped}")
end


get '/error' do
  erb :error
end


post '/error' do
  @artistNameEscaped = params[:artist].gsub(' ', '%20')
  redirect to("/artist/#{@artistNameEscaped}")
end


get '/artist/:artist' do
  artistName = params[:artist]
  
  # get name, photo, and genres
  artistRequest = HTTParty.get("https://ws.audioscrobbler.com/2.0/", :query => {
    :method => "artist.getinfo",
    :artist => artistName,
    :api_key => LF_API_KEY,
    :format => "json"
  })

  artistResponse = JSON.parse(artistRequest.body)
  artist = artistResponse["artist"]

  @artistName = artist["name"]

  @biography = artist["bio"]["content"]

  # get genres
  genres = []
  for genre in artist["tags"]["tag"]
    genres.push(genre["name"])
  end
  @genres = genres.join(", ")

  # get related artists
  @relatedArtists = []
  for band in artist["similar"]["artist"]
    @relatedArtists.push(band["name"])
  end

  # get photo from spotify
  RSpotify.authenticate(S_API_KEY, S_SECRET)
  spotify_artist = RSpotify::Artist.search(artistName).first
  @photoURL = spotify_artist.images[0]["url"]

  # get top tracks
  topTracksRequest = HTTParty.get("https://ws.audioscrobbler.com/2.0/", :query => {
    :method => "artist.gettoptracks",
    :api_key => LF_API_KEY,
    :artist => @artistName,
    :limit => 5,
    :format => "json"
  })

  topTracksResponse = JSON.parse(topTracksRequest.body)
  
  @topTracks = []
  @youTubeURLs = []

  for i in 0..4 do
    # song titles from last.fm
    title = topTracksResponse["toptracks"]["track"][i]["name"]
    @topTracks.push(title)
  end

  erb :artist

end
